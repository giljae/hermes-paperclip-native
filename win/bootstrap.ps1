# 한 줄 설치 진입점:
#   irm https://github.com/giljae/hermes-paperclip-native/releases/latest/download/bootstrap.ps1 | iex
#
# 세 경우를 처리한다(entry/bootstrap.sh 와 같은 순서).
#   1) HC_SOURCE_DIR 가 있으면 그 체크아웃의 win\commands.ps1 을 쓴다(개발·스모크).
#   2) 자기 옆에 win\commands.ps1 이 있으면 그것을 쓴다(배포 zip 을 푼 경우).
#   3) 아니면 릴리스에서 zip 을 받아 검증한 뒤 app\<ver> 에 풀고 실행한다.
#
# 관리자 권한을 요구하지 않는다 — 모두 사용자 범위(%LOCALAPPDATA%, %USERPROFILE%) 안이다.

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$HcSelfDir = $PSScriptRoot
$HcAppDir = if ($env:HC_HOME) { $env:HC_HOME } else { "$env:LOCALAPPDATA\hermes-paperclip-native" }
$HcReleaseBase = if ($env:HC_RELEASE_BASE) { $env:HC_RELEASE_BASE } else { "https://github.com/giljae/hermes-paperclip-native/releases/latest/download" }

$Command = "install"
$CommandArgs = @()
if ($args.Count -gt 0 -and $args[0]) {
    $Command = $args[0]
    if ($args.Count -gt 1) { $CommandArgs = @($args[1..($args.Count - 1)]) }
}

function Get-HcBootstrapVersion {
    if ($env:HC_LATEST_VERSION) { return $env:HC_LATEST_VERSION }
    try { return (Invoke-WebRequest -Uri "$HcReleaseBase/VERSION" -UseBasicParsing).Content.Trim() }
    catch { return "" }
}

# commands.ps1 을 프로세스 안에서 실행하고 그 결과를 종료 코드로 옮긴다.
function Invoke-HcCommands {
    param([string]$CommandsFile, [string]$Cmd, [string[]]$Extra = @())
    . $CommandsFile
    $ok = Invoke-HcDispatch -Command $Cmd -Arg ($Extra -join " ")
    if ($ok -eq $false) { exit 1 }
    exit 0
}

# 릴리스 zip 을 app\<ver> 에 내려받아 검증하고 푼다.
function Install-HcRelease {
    param([string]$Version, [string]$AppVer)
    New-Item -ItemType Directory -Force -Path $AppVer | Out-Null
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("hc-boot-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $zip = Join-Path $tmp "app.zip"
        Write-Host "[설치] 내려받는 중... ($Version)"
        Invoke-WebRequest -Uri "$HcReleaseBase/hermes-paperclip-$Version.zip" -OutFile $zip -UseBasicParsing

        $wantHash = ""
        try {
            $sums = (Invoke-WebRequest -Uri "$HcReleaseBase/checksums.txt" -UseBasicParsing).Content
            $line = ($sums -split "`n" | Where-Object { $_ -match [regex]::Escape("hermes-paperclip-$Version.zip") } | Select-Object -First 1)
            if ($line) { $wantHash = ($line -split '\s+')[0].ToLower() }
        } catch { }
        if ($wantHash) {
            $gotHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
            if ($wantHash -ne $gotHash) { throw "내려받은 파일이 손상되었습니다(체크섬 불일치)." }
        }

        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
        $inner = Get-ChildItem -LiteralPath $tmp -Directory |
            Where-Object { $_.Name -ne "__MACOSX" } | Select-Object -First 1
        $from = $tmp
        if ($inner) { $from = $inner.FullName }
        Copy-Item -Path (Join-Path $from "*") -Destination $AppVer -Recurse -Force
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 1) HC_SOURCE_DIR (개발·스모크)
if ($env:HC_SOURCE_DIR) {
    $c = Join-Path $env:HC_SOURCE_DIR "win\commands.ps1"
    if (Test-Path -LiteralPath $c) { Invoke-HcCommands $c $Command $CommandArgs }
}

# 2) 자기 옆 (배포 zip 을 푼 경우)
if ($HcSelfDir) {
    $self = Join-Path $HcSelfDir "commands.ps1"
    if (Test-Path -LiteralPath $self) { Invoke-HcCommands $self $Command $CommandArgs }
}

# 3) 릴리스에서 내려받기
if ($env:HC_DRY_RUN) {
    $v = Get-HcBootstrapVersion
    if (-not $v) { $v = "unknown" }
    Write-Host "내려받을 파일: hermes-paperclip-$v.zip"
    Write-Host "검증: checksums.txt (sha256)"
    Write-Host "설치 위치: $HcAppDir\app\$v"
    Write-Host "실행: $HcAppDir\app\$v\win\commands.ps1 $Command"
    exit 0
}

$v = Get-HcBootstrapVersion
if (-not $v) { throw "최신 버전을 확인하지 못했습니다. 인터넷 연결을 확인해 주세요." }

$appVer = Join-Path $HcAppDir "app\$v"
$target = Join-Path $appVer "win\commands.ps1"
if (-not (Test-Path -LiteralPath $target)) { Install-HcRelease $v $appVer }

# Windows Defender 가 파일을 격리하면 원인을 알 수 없게 실패한다. 한국어로 안내한다.
if (-not (Test-Path -LiteralPath $target)) {
    Write-Host ""
    Write-Host "✗ 설치 파일을 찾을 수 없습니다: $target"
    Write-Host "  Windows Defender 가 파일을 격리했을 수 있습니다."
    Write-Host "  '바이러스 및 위협 방지 > 제외' 에 다음을 추가한 뒤 다시 실행해 주세요:"
    Write-Host "    $HcAppDir"
    exit 1
}

Invoke-HcCommands $target $Command $CommandArgs
