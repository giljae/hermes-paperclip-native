# 가짜 홈에서 설치 → (REAL 이면) 멱등 확인 → 업데이트 → 제거까지 수행한다.
#
# 기본은 DRY_RUN(네트워크/디스크를 쓰지 않음)이다. 실제 설치를 검증하려면:
#   HC_SMOKE_REAL=1 pwsh -File tests/win/smoke.ps1
#
# 실패하면 가짜 홈을 지우지 않고 경로를 출력한다(셸 smoke.sh 와 같은 동작).
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
# 가짜 홈은 C: 에 둔다. 실제 사용자 홈도 C: 이고, embedded Postgres 의 initdb 는
# "미리 존재하는 데이터 디렉터리"가 D:(GitHub 러너의 RUNNER_TEMP)에 있으면 chmod 가
# EACCES(Permission denied)로 실패한다(실측). D: 는 러너 특성이므로 실제 설치
# 조건과 맞춘다.
$Base = if ($env:HC_SMOKE_BASE) { $env:HC_SMOKE_BASE }
        elseif ($env:LOCALAPPDATA) { $env:LOCALAPPDATA }
        else { [IO.Path]::GetTempPath() }
$Fake = Join-Path $Base ("hc-smoke-" + [guid]::NewGuid().ToString("N"))
$FakeHome = Join-Path $Fake "home"
New-Item -ItemType Directory -Force -Path $FakeHome | Out-Null

$env:HC_HOME = Join-Path $FakeHome ".hermes-paperclip-native"
$env:USERPROFILE = $FakeHome
$env:HOME = $FakeHome
$env:HC_SOURCE_DIR = $Root
$env:HC_SKIP_AUTOSTART = "1"
$env:HC_SKIP_OPEN = "1"
$env:PAPERCLIP_HOME = Join-Path $FakeHome ".paperclip"
if (-not $env:npm_config_cache) {
    # npm 캐시를 새 홈마다 두면 Paperclip 페이로드를 매번 다시 받아 20분이 넘는다(실측).
    $env:npm_config_cache = Join-Path $Base "hermes-paperclip-smoke-npm-cache"
}
New-Item -ItemType Directory -Force -Path $env:npm_config_cache | Out-Null

$Real = -not [string]::IsNullOrEmpty($env:HC_SMOKE_REAL)
if (-not $Real) { $env:HC_DRY_RUN = "1"; $Mode = "DRY_RUN" } else { $Mode = "REAL" }

$script:Keep = $false
function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "SMOKE FAIL: $Message" -ForegroundColor Red
    # 실패 원인을 CI 로그에서 바로 볼 수 있게 로그 꼬리를 출력한다(아티팩트는
    # 숨김 파일 제외 등으로 누락될 수 있다).
    foreach ($name in @("install.log", "onboard.log", "onboard.log.err", "seed.log", "server.log", "server.err.log", "paperclip.log")) {
        $p = Join-Path $env:HC_HOME "logs\$name"
        if (Test-Path -LiteralPath $p) {
            Write-Host "--- $name (tail) ---" -ForegroundColor Yellow
            Get-Content -LiteralPath $p -Tail 50 | ForEach-Object { Write-Host $_ }
        }
    }
    Write-Host "가짜 홈을 보존했습니다: $FakeHome"
    # 아티팩트 업로드용. 가짜 홈은 C: 에 있어 워크플로의 ${{ runner.temp }} 글롭과
    # 맞지 않으므로, 필요한 로그만 RUNNER_TEMP(D:)로 모아 둔다.
    if ($env:RUNNER_TEMP) {
        $drop = Join-Path $env:RUNNER_TEMP "win-smoke-logs"
        New-Item -ItemType Directory -Force -Path $drop | Out-Null
        $logsDir = Join-Path $env:HC_HOME "logs"
        if (Test-Path -LiteralPath $logsDir) { Copy-Item -LiteralPath $logsDir -Destination $drop -Recurse -Force -ErrorAction SilentlyContinue }
    }
    if ($script:InstallOut) {
        Write-Host "--- 설치 출력 (tail) ---" -ForegroundColor Yellow
        ($script:InstallOut -split "`n" | Select-Object -Last 60) | ForEach-Object { Write-Host $_ }
    }
    $script:Keep = $true
    throw "SMOKE FAIL"
}
function Step { param([string]$Name) Write-Host ""; Write-Host "=== $Name" }

# 현재 PowerShell 호스트와 같은 실행 파일을 쓴다(pwsh/powershell 혼동 방지).
$psExe = "pwsh"
try { $p = Get-Process -Id $PID; if ($p.Path) { $psExe = $p.Path } } catch { }

function Invoke-Bootstrap {
    param([string[]]$CommandArgs)
    # 파이프(& ... | Out-String)로 받으면 안 된다: 설치가 띄운 백그라운드 서버가
    # 부모의 stdout 핸들을 물고 있어 파이프가 닫히지 않고 스모크가 영원히 멈춘다
    # (실측: 설치 9단계가 끝난 뒤 진행 없음). Start-Process 의 파일 리다이렉트는
    # 파이프를 쓰지 않으므로 이 문제가 없다.
    $dir = [IO.Path]::GetTempPath()
    $tag = [guid]::NewGuid().ToString("N")
    $o = Join-Path $dir "hc-boot-$tag.out"
    $e = Join-Path $dir "hc-boot-$tag.err"
    $bootstrap = Join-Path $Root "win\bootstrap.ps1"
    $procArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $bootstrap) + $CommandArgs
    $sp = @{
        FilePath = $psExe; ArgumentList = $procArgs
        RedirectStandardOutput = $o; RedirectStandardError = $e
        Wait = $true; PassThru = $true
    }
    if ($env:OS -eq "Windows_NT") { $sp["WindowStyle"] = "Hidden" }
    $p = Start-Process @sp
    $out = ""
    if (Test-Path -LiteralPath $o) { $out += (Get-Content -LiteralPath $o -Raw) }
    if (Test-Path -LiteralPath $e) { $out += (Get-Content -LiteralPath $e -Raw) }
    Remove-Item -LiteralPath $o, $e -Force -ErrorAction SilentlyContinue
    return @{ Out = $out; Code = $p.ExitCode }
}

$failed = $false
try {
    Write-Host "SMOKE ($Mode) — 가짜 홈: $FakeHome"

    Step "1) 설치"
    $r = Invoke-Bootstrap @("install")
    $script:InstallOut = $r.Out
    if ($r.Code -ne 0) { Fail "설치가 실패했다 (exit $($r.Code))`n$($r.Out)" }

    if (-not $Real) {
        Write-Host ""
        Write-Host "SMOKE OK (DRY_RUN — 실제 설치 경로는 검증되지 않았다)"
        return
    }

    Step "1b) 시드가 실제로 동작했는가"
    $seedLog = Join-Path $env:HC_HOME "logs\seed.log"
    if (Test-Path -LiteralPath $seedLog) {
        if ((Get-Content -LiteralPath $seedLog -Raw) -match "Could not reach the Paperclip API") {
            Fail "시드가 Paperclip 서버에 닿지 못했다 (서버가 뜨지 않음)"
        }
    }
    $cli = Join-Path $env:HC_HOME "bin\paperclipai.cmd"
    if (-not (Test-Path -LiteralPath $cli)) { Fail "paperclipai 를 찾지 못했다: $cli" }
    $companies = (& $cli company list --json 2>$null | Out-String)
    $cm = [regex]::Match($companies, '"id"\s*:\s*"([^"]*)"')
    if (-not $cm.Success) { Fail "회사를 찾지 못했다" }
    $agents = (& $cli agent list -C $cm.Groups[1].Value --json 2>$null | Out-String)
    if ($agents -notmatch "hermes_local") { Fail "hermes_local 에이전트를 찾지 못했다" }

    Step "2) 두 번째 설치가 멱등한가"
    $r = Invoke-Bootstrap @("install")
    if ($r.Code -ne 0) { Fail "두 번째 설치가 실패했다`n$($r.Out)" }
    if ($r.Out -notmatch "건너뜀") { Fail "두 번째 설치가 단계를 건너뛰지 않았다" }

    Step "3) 업데이트"
    $env:HC_LATEST_VERSION = "0.0.1"
    $r = Invoke-Bootstrap @("update")
    Remove-Item Env:\HC_LATEST_VERSION -ErrorAction SilentlyContinue
    if ($r.Code -ne 0) { Fail "업데이트가 실패했다`n$($r.Out)" }

    Step "4) 제거"
    $r = Invoke-Bootstrap @("uninstall", "--yes")
    if ($r.Code -ne 0) { Fail "제거가 실패했다`n$($r.Out)" }
    if (Test-Path -LiteralPath $env:PAPERCLIP_HOME) { Fail "제거 후에도 Paperclip 데이터가 남아 있다" }
    if (Test-Path -LiteralPath $env:HC_HOME) { Fail "제거 후에도 설치 상태가 남아 있다" }

    Write-Host ""
    Write-Host "SMOKE OK"
} catch {
    Write-Host $_ -ForegroundColor Red
    $failed = $true
} finally {
    if (-not $script:Keep) { Remove-Item -LiteralPath $Fake -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($failed) { exit 1 }
exit 0
