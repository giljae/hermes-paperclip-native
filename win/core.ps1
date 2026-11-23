# 설치 단계 목록·실행기·도구 설치. core/ 와 계약을 맞춘다.
#
# OS 전용 호출은 platform.ps1 의 함수만 쓴다. 단계 순서·라벨·매니페스트 키는
# 셸 구현(core/run.sh, core/steps/*.sh)과 같아야 문서와 테스트가 함께 적용된다.
#
# 설치 순서(셸과 동일):
#   1 확인 → 2 Node → 3 Paperclip → 4 Hermes → 5 온보딩
#   → 6 자동 시작 → 7 시드 → 8 관리 파일 → 9 브라우저

# 이 파일이 로드될 때의 위치 = <root>\win. 루트는 그 부모다(pins.env 가 거기 있다).
$script:HcRoot = Split-Path -Parent $PSScriptRoot

function Get-HcRoot { return $script:HcRoot }

# 셸의 hc_pin 과 같은 계약: 루트의 pins.env 에서 KEY= 값을 읽는다.
function Get-HcPin {
    param([string]$Key)
    $f = Join-Path (Get-HcRoot) "pins.env"
    if (-not (Test-Path -LiteralPath $f)) { return "" }
    foreach ($line in (Get-Content -LiteralPath $f -Encoding UTF8)) {
        if ($line -like "$Key=*") { return $line.Substring($Key.Length + 1).Trim() }
    }
    return ""
}

# --- 한국어 출력 (셸의 ui_* 계약과 같은 형식) ------------------------------

function Write-HcStep { param([int]$N, [int]$Total, [string]$Label) Write-Host "[$N/$Total] $Label" }
function Write-HcOk   { param([string]$Label) Write-Host "      ✓ $Label" }
function Write-HcSkip { param([string]$Label) Write-Host "      · $Label (건너뜀)" }
function Write-HcFail { param([string]$Label) Write-Host "      ✗ $Label" -ForegroundColor Red }
function Write-HcWarn { param([string]$Label) Write-Host "      ! $Label" -ForegroundColor Yellow }

# --- 단계 목록 -------------------------------------------------------------
# 라벨은 core/run.sh 의 hc_install_steps 에서 그대로 옮긴 것이다. 여기서 문구를
# 바꾸면 셸 버전과 어긋난다.

function Get-HcInstallSteps {
    return @(
        @{ N = 1; Key = "preflight"; Label = "이 컴퓨터를 확인하는 중..." }
        @{ N = 2; Key = "node";      Label = "Node.js를 설치하는 중..." }
        @{ N = 3; Key = "paperclip"; Label = "Paperclip을 설치하는 중..." }
        @{ N = 4; Key = "hermes";    Label = "Hermes를 설치하는 중..." }
        @{ N = 5; Key = "onboard";   Label = "초기 설정을 만드는 중..." }
        @{ N = 6; Key = "autostart"; Label = "자동 시작을 등록하는 중..." }
        @{ N = 7; Key = "seed";      Label = "AI 팀을 만드는 중..." }
        @{ N = 8; Key = "shortcuts"; Label = "관리 파일을 만드는 중..." }
        @{ N = 9; Key = "open";      Label = "브라우저를 여는 중..." }
    )
}

# 단계 하나를 실행한다. scriptblock 이 $true 를 돌려주면 성공, 아니면 실패다.
# Soft 단계는 실패해도 전체를 멈추지 않는다(셸의 soft 플래그와 같은 뜻).
function Invoke-HcStep {
    param([int]$N, [int]$Total, [scriptblock]$Body, [string]$Label, [bool]$Soft = $false)
    Write-HcStep $N $Total $Label
    $ok = $false
    try { $ok = & $Body } catch {
        $ok = $false
        Write-HcWarn "예외: $($_.Exception.Message)"
    }
    if ($ok -eq $true) { Write-HcOk $Label; return $true }
    if ($Soft) { Write-HcWarn "$Label (계속 진행)"; return $true }
    Write-HcFail $Label
    return $false
}

# 외부 명령 실행. HC_DRY_RUN 이 있으면 실행하지 않고 명령 문자열만 돌려준다.
# 네이티브 도구(npm/uv 등)는 경고를 stderr 로 쓴다. PowerShell 5.1 에서
# $ErrorActionPreference=Stop 이면 그 경고가 종료 오류가 되어 설치가 중단된다
# (실측: npm deprecation 경고로 Paperclip 설치가 멈춤). 호출 동안 Continue 로 낮춘다.
function Invoke-HcRun {
    param([string]$Command, [string[]]$Arguments = @(), [string]$Log = "")
    $line = $Command
    if ($Arguments.Count -gt 0) { $line = "$Command " + ($Arguments -join " ") }
    if ($env:HC_DRY_RUN) { Write-Host $line; return $line }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($Log) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Log) | Out-Null
            & $Command @Arguments *>> $Log
        } else {
            & $Command @Arguments
        }
    } finally {
        $ErrorActionPreference = $prev
    }
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { return $false }
    return $true
}

# --- 도구 설치 -------------------------------------------------------------

function Install-HcUv {
    $bin = Get-HcBinDir
    $uv = Join-Path $bin "uv.exe"
    if (Test-Path -LiteralPath $uv) { return $true }
    if ($env:HC_DRY_RUN) { Write-Host "uv 설치 (astral.sh) → $bin"; return $true }
    New-Item -ItemType Directory -Force -Path $bin | Out-Null

    # uv 설치 스크립트가 우리 bin 에 설치하게 한다(시스템을 건드리지 않는다).
    $env:UV_INSTALL_DIR = $bin
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("hc-uv-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $script = Join-Path $tmp "uv-install.ps1"
        Invoke-WebRequest -Uri "https://astral.sh/uv/install.ps1" -OutFile $script -UseBasicParsing
        Invoke-HcRun "powershell" @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $script) | Out-Null
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    Add-HcPathEntry $bin
    return (Test-Path -LiteralPath $uv)
}

function Install-HcHermes {
    param([string]$PythonVersion, [string]$HermesVersion)
    if (-not $PythonVersion) { $PythonVersion = $env:PYTHON_VERSION }
    if (-not $PythonVersion) { $PythonVersion = Get-HcPin "PYTHON_VERSION" }
    if (-not $HermesVersion) { $HermesVersion = $env:HERMES_VERSION }
    if (-not $HermesVersion) { $HermesVersion = Get-HcPin "HERMES_VERSION" }

    $uv = Join-Path (Get-HcBinDir) "uv.exe"
    if ($env:HC_DRY_RUN) {
        Write-Host "$(Get-HcBinDir)\uv python install $PythonVersion"
        Write-Host "$(Get-HcBinDir)\uv tool install hermes-agent==$HermesVersion"
        return $true
    }
    # uv 의 기본 TLS 스택은 시스템 신뢰 저장소를 쓰지 않아 기업/백신 TLS 검사
    # 환경에서 실패한다(셸 구현과 같은 이유). 모든 것을 HC_HOME 아래에 둔다.
    $env:UV_NATIVE_TLS = "1"
    $env:UV_TOOL_BIN_DIR = Get-HcBinDir
    $env:UV_TOOL_DIR = "$(Get-HcAppDir)\uv-tools"
    $env:UV_PYTHON_INSTALL_DIR = "$(Get-HcAppDir)\python"

    if (-not (Invoke-HcRun $uv @("python", "install", $PythonVersion))) { return $false }
    if (-not (Invoke-HcRun $uv @("tool", "install", "hermes-agent==$HermesVersion"))) { return $false }
    Add-HcPathEntry (Get-HcBinDir)
    return $true
}

# paperclipai 의 `install` 은 Windows 를 지원하지 않는다(실측):
#   1) 내부에서 npm 을 execFile("npm") 로 부르는데 Windows 의 npm 은 npm.cmd 라
#      shell 없이는 실행되지 않는다 → `spawn npm ENOENT` 로 설치가 깨진다.
#   2) managed shim 을 `#!/bin/sh` 스크립트로 쓴다(POSIX 전용).
# 그래서 우리가 payload 를 직접 설치하고 Windows 용 .cmd 심을 만든다.
# npx 로 CLI 만 돌려도 명령은 동작하지만, 매번 내려받지 않도록 로컬에 설치한다.
function New-HcPaperclipShim {
    param([string]$Entry)
    $bin = Get-HcBinDir
    New-Item -ItemType Directory -Force -Path $bin | Out-Null
    $shim = Join-Path $bin "paperclipai.cmd"
    $node = Join-Path (Get-HcNodeDir) "node.exe"
    $content = "@echo off`r`n`"$node`" `"$Entry`" %*`r`n"
    Set-Content -LiteralPath $shim -Value $content -Encoding OEM
    return $shim
}

function Install-HcPaperclip {
    param([string]$Version)
    if (-not $Version) { $Version = $env:PAPERCLIP_VERSION }
    if (-not $Version) { $Version = Get-HcPin "PAPERCLIP_VERSION" }

    $bin = Get-HcBinDir
    $shim = Join-Path $bin "paperclipai.cmd"
    if (Test-Path -LiteralPath $shim) { return $true }

    $prefix = Join-Path (Get-HcAppDir) "paperclip"
    $entry = Join-Path $prefix "node_modules\paperclipai\dist\index.js"

    if ($env:HC_DRY_RUN) {
        Write-Host "npm install paperclipai@$Version → $prefix"
        Write-Host "paperclipai 심 → $shim"
        return $true
    }

    New-Item -ItemType Directory -Force -Path $prefix, $bin | Out-Null
    New-Item -ItemType Directory -Force -Path (Get-HcLogDir) | Out-Null
    $log = Join-Path (Get-HcLogDir) "paperclip.log"

    # PowerShell 의 `&` 는 .cmd 를 cmd.exe 를 통해 실행하므로 npm 이 정상 동작한다.
    $npm = Join-Path (Get-HcNodeDir) "npm.cmd"
    if (-not (Test-Path -LiteralPath $npm)) { $npm = "npm.cmd" }
    if (-not (Invoke-HcRun $npm @("install", "--prefix", $prefix, "--no-audit", "--no-fund", "--dangerously-allow-all-scripts", "paperclipai@$Version") $log)) { return $false }
    if (-not (Test-Path -LiteralPath $entry)) { return $false }

    New-HcPaperclipShim $entry | Out-Null
    Add-HcPathEntry $bin
    return (Test-Path -LiteralPath $shim)
}
