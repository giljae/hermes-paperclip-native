# 명령 디스패처와 설치 오케스트레이션. 셸의 core/run.sh + core/steps/*.sh 에 대응한다.
#
# OS 전용 호출은 platform.ps1 의 함수만 쓴다. 단계 순서·라벨·보존 규칙은 셸
# 구현과 같아야 한다.
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

. "$PSScriptRoot\platform.ps1"
. "$PSScriptRoot\manifest.ps1"
. "$PSScriptRoot\core.ps1"

# --- 제어 파일 (홈의 관리용 .cmd) ------------------------------------------
# 각 파일은 매니페스트에서 설치된 버전을 읽어 앱 디렉터리를 찾는다. 그래서
# 업데이트 후에도(버전이 바뀌어도) 그대로 동작한다(self-locating).
#
# .ps1 이 아니라 .cmd 로 만든다: .ps1 은 더블클릭이 안 되고 실행 정책의 영향을 받는다.

function Get-HcShortcutDir { return (Join-Path $env:USERPROFILE "HermesPaperclip") }

function Get-HcControlFileContent {
    param([string]$Command)
    $lines = @(
        '@echo off'
        'chcp 65001 >nul'
        'if not defined HC_HOME set "HC_HOME=%LOCALAPPDATA%\hermes-paperclip-native"'
        'for /f "tokens=2 delims==" %%v in (''findstr /b "INSTALLER_VERSION=" "%HC_HOME%\manifest.env"'') do set "VER=%%v"'
        'powershell -NoProfile -ExecutionPolicy Bypass -File "%HC_HOME%\app\%VER%\win\commands.ps1" ' + $Command
        'pause'
    )
    return ($lines -join "`r`n")
}

function New-HcControlFiles {
    $dir = Get-HcShortcutDir
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $entries = @(
        @{ Name = "시작";    Cmd = "start" }
        @{ Name = "중지";    Cmd = "stop" }
        @{ Name = "상태";    Cmd = "status" }
        @{ Name = "AI연결";  Cmd = "connect" }
        @{ Name = "업데이트"; Cmd = "update" }
        @{ Name = "제거";    Cmd = "uninstall" }
    )
    foreach ($e in $entries) {
        $f = Join-Path $dir "$($e.Name).cmd"
        Set-Content -LiteralPath $f -Value (Get-HcControlFileContent $e.Cmd) -Encoding OEM
    }
    $html = Join-Path (Get-HcRoot) "win\사용방법.html"
    if (Test-Path -LiteralPath $html) {
        Copy-Item -LiteralPath $html -Destination (Join-Path $dir "사용방법.html") -Force
    }
    return $true
}

# --- 설치 단계 -------------------------------------------------------------

function Invoke-HcStepPreflight {
    Test-HcRequireSupported | Out-Null
    $plat = Get-HcPlatform
    Set-HcManifest "PLATFORM" "$($plat.OS)-$($plat.Arch)"
    Set-HcManifest "DATA_DIR" (Get-HcDataDir)
    Set-HcManifest "INSTALLED_AT" (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $hermesCfg = Join-Path $env:USERPROFILE ".hermes"
    if (Test-Path -LiteralPath $hermesCfg) { Set-HcManifest "HERMES_EXISTED" "true" }
    else { Set-HcManifest "HERMES_EXISTED" "false" }
    return $true
}

function Invoke-HcStepNode {
    $want = $env:NODE_VERSION
    if (-not $want) { $want = Get-HcPin "NODE_VERSION" }
    $env:NODE_VERSION = $want
    if (-not (Install-HcNode $want)) { return $false }
    Set-HcManifest "NODE_VERSION" $want
    return $true
}

function Invoke-HcStepPaperclip {
    $v = $env:PAPERCLIP_VERSION
    if (-not $v) { $v = Get-HcPin "PAPERCLIP_VERSION" }
    if (-not (Install-HcPaperclip $v)) { return $false }
    Set-HcManifest "PAPERCLIP_VERSION" $v
    return $true
}

function Invoke-HcStepHermes {
    $h = $env:HERMES_VERSION; if (-not $h) { $h = Get-HcPin "HERMES_VERSION" }
    $p = $env:PYTHON_VERSION; if (-not $p) { $p = Get-HcPin "PYTHON_VERSION" }
    if (-not (Install-HcUv)) { return $false }
    if (-not (Install-HcHermes $p $h)) { return $false }
    Set-HcManifest "HERMES_VERSION" $h
    Set-HcManifest "PYTHON_VERSION" $p
    return $true
}

function Invoke-HcStepOnboard {
    $cfg = Join-Path (Get-HcDataDir) "instances\default\config.json"
    if (Test-Path -LiteralPath $cfg) { Write-HcSkip "초기 설정이 이미 있습니다"; return $true }

    $env:PAPERCLIP_HOME = Get-HcDataDir
    $cli = Join-Path (Get-HcBinDir) "paperclipai.cmd"
    if (-not (Test-Path -LiteralPath $cli)) { $cli = "paperclipai" }

    if ($env:HC_DRY_RUN) {
        Write-Host "PAPERCLIP_HOME=$(Get-HcDataDir) $cli onboard --yes --no-install-service"
        return $true
    }

    New-Item -ItemType Directory -Force -Path (Get-HcLogDir) | Out-Null
    $log = Join-Path (Get-HcLogDir) "onboard.log"
    $env:PAPERCLIP_NO_BROWSER = "1"
    $proc = Start-HcPaperclipProcess -Arguments "onboard --yes --no-install-service" `
        -OutLog $log -ErrLog ($log + ".err")

    $i = 0
    while ($i -lt 300) {
        Start-Sleep -Seconds 2
        if (Test-Path -LiteralPath $cfg) { break }
        if ($proc.HasExited) { break }
        $i++
    }
    if (-not (Test-Path -LiteralPath $cfg)) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch { }
        throw "초기 설정을 만들지 못했습니다. 기록: $log"
    }

    # onboard --yes 는 서버를 함께 띄운다(콘솔에 "Starting Paperclip server...").
    # Windows 에서는 그 서버를 그대로 쓴다: 죽였다가 다시 띄우면 반쯤 초기화된
    # 내장 Postgres 폴더 때문에 다음 initdb 가 실패한다(실측: "data directory might
    # already exist"). PID 를 우리 pidfile 에 기록해 러너가 관리하게 한다.
    if (-not $proc.HasExited) {
        Set-Content -LiteralPath (Get-HcServerPidFile) -Value "$($proc.Id)" -Encoding ascii
    }
    return $true
}

# 서버가 응답할 때까지 기다린다. 첫 부팅은 임베디드 Postgres 초기화와 마이그레이션
# 때문에 오래 걸린다(셸 구현과 같은 이유·기본값).
function Wait-HcServerHealth {
    if ($env:HC_DRY_RUN) { return $true }
    $limit = 150
    if ($env:HC_HEALTH_WAIT_ITERATIONS) { $limit = [int]$env:HC_HEALTH_WAIT_ITERATIONS }
    $url = "$(Get-HcServerUrl)/api/health"
    $i = 0
    while ($i -lt $limit) {
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
            if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 300) { return $true }
        } catch { }
        Start-Sleep -Seconds 2
        $i++
    }
    Write-HcWarn "서버가 아직 응답하지 않습니다. 잠시 뒤 브라우저를 새로 고쳐 보세요."
    return $true
}

function Invoke-HcStepAutostart {
    $env:PAPERCLIP_HOME = Get-HcDataDir
    Add-HcPathEntry (Get-HcBinDir)

    if ($env:HC_SKIP_AUTOSTART) {
        Write-HcSkip "자동 시작"
    } elseif (-not (Install-HcAutostart)) {
        Write-HcWarn "자동 시작을 등록하지 못했습니다. 대신 백그라운드로 실행합니다."
    }

    # ONLOGON 작업은 로그온 때만 실행된다. 다음 단계(시드)가 API를 쓰므로
    # 지금 서버를 띄우고 응답할 때까지 기다린다.
    if (-not $env:HC_DRY_RUN) { Start-HcServerBackground | Out-Null }
    return (Wait-HcServerHealth)
}

function Get-HcFirstId {
    param([string]$Json)
    $m = [regex]::Match($Json, '"id"\s*:\s*"([^"]*)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return ""
}

function Get-HcSeedCompanyJson {
    return (@{ name = "내 AI 회사"; issuePrefix = "AI" } | ConvertTo-Json -Compress)
}

function Get-HcSeedAgentJson {
    $obj = @{
        name = "CEO"
        role = "ceo"
        adapterType = "hermes_local"
        adapterConfig = @{ persistSession = $true; timeoutSec = 1800; quiet = $true }
        runtimeConfig = @{ heartbeat = @{ enabled = $false } }
        instructionsBundle = @{ files = @{ "AGENTS.md" = "You are the CEO agent of this Paperclip company. Plan strategy, break it into tasks, and delegate. Keep reports short." } }
    }
    return ($obj | ConvertTo-Json -Depth 6 -Compress)
}

# Windows 네이티브 인자 인용(CommandLineToArgvW 규칙). 공백/따옴표가 있으면 큰따옴표로
# 감싸고, 내부 `"` 앞의 백슬래시를 규칙대로 늘린다(끝 백슬래시도 두 배). 실측으로
# 검증했다(프로브 워크플로).
function ConvertTo-HcWinArg {
    param([string]$Arg)
    if ($Arg -notmatch '[\s"]') { return $Arg }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    $backslashes = 0
    foreach ($ch in $Arg.ToCharArray()) {
        if ($ch -eq '\') { $backslashes++; continue }
        if ($ch -eq '"') {
            [void]$sb.Append('\' * (2 * $backslashes + 1))
            [void]$sb.Append('"')
            $backslashes = 0
            continue
        }
        if ($backslashes -gt 0) { [void]$sb.Append('\' * $backslashes); $backslashes = 0 }
        [void]$sb.Append($ch)
    }
    [void]$sb.Append('\' * (2 * $backslashes))
    [void]$sb.Append('"')
    return $sb.ToString()
}

# PowerShell 5.1 은 네이티브 실행 파일에 인자를 넘길 때 안쪽 `"` 를 제대로 다루지
# 못한다(실측, JSON 인자):
#   - 그대로     → 따옴표가 벗겨져 JSON 이 무효가 된다                 ("Expected property name")
#   - `"`→`\"`  → 공백에서 인자가 여러 개로 쪼개진다                   ("too many arguments")
# 그래서 우리가 Windows command line 을 직접 만들어 .NET Process 로 넘긴다(이 경로는
# PowerShell 의 인자 재조립을 거치지 않는다). stdout 을 돌려준다.
function Invoke-HcNative {
    param([string]$Exe, [string[]]$Arguments, [string]$Log)
    $argLine = ($Arguments | ForEach-Object { ConvertTo-HcWinArg $_ }) -join ' '
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    if ($Exe -match '\.(cmd|bat)$') {
        # .cmd 폴백(페이로드가 없을 때만 쓰인다).
        $psi.FileName = if ($env:ComSpec) { $env:ComSpec } else { "cmd.exe" }
        $psi.Arguments = "/d /s /c `"`"$Exe`" $argLine`""
    } else {
        $psi.FileName = $Exe
        $psi.Arguments = $argLine
    }
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    $out = $outTask.Result
    $err = $errTask.Result
    $p.WaitForExit()
    if ($Log) {
        if ($err) { Add-Content -LiteralPath $Log -Value $err -Encoding UTF8 }
        if ($out) { Add-Content -LiteralPath $Log -Value $out -Encoding UTF8 }
    }
    return $out
}

function Invoke-HcStepSeed {
    $env:PAPERCLIP_HOME = Get-HcDataDir
    $call = Get-HcPaperclipCommand

    if ($env:HC_DRY_RUN) {
        Write-Host "PAPERCLIP_HOME=$(Get-HcDataDir) $($call.Exe) company create --payload-json <회사>"
        Write-Host "PAPERCLIP_HOME=$(Get-HcDataDir) $($call.Exe) agent create -C <회사 id> --payload-json <CEO>"
        return $true
    }

    New-Item -ItemType Directory -Force -Path (Get-HcLogDir) | Out-Null
    $seedLog = Join-Path (Get-HcLogDir) "seed.log"
    $pre = @($call.Pre)

    $cid = Get-HcFirstId (Invoke-HcNative $call.Exe ($pre + @("company", "list", "--json")))
    if (-not $cid) {
        Invoke-HcNative $call.Exe ($pre + @("company", "create", "--payload-json", (Get-HcSeedCompanyJson))) $seedLog | Out-Null
        $cid = Get-HcFirstId (Invoke-HcNative $call.Exe ($pre + @("company", "list", "--json")))
    }
    if (-not $cid) { Write-HcWarn "회사 id 를 확인하지 못해 CEO 채용을 건너뜁니다."; return $true }

    $agents = Invoke-HcNative $call.Exe ($pre + @("agent", "list", "-C", $cid, "--json"))
    if ($agents -match "CEO") { Write-HcSkip "이미 CEO 가 있습니다"; return $true }

    Invoke-HcNative $call.Exe ($pre + @("agent", "create", "-C", $cid, "--payload-json", (Get-HcSeedAgentJson))) $seedLog | Out-Null
    return $true
}

function Invoke-HcStepShortcuts {
    New-HcControlFiles | Out-Null
    return $true
}

function Invoke-HcStepOpen {
    if ($env:HC_SKIP_OPEN) { Write-HcWarn "브라우저 열기"; return $true }
    $url = Get-HcServerUrl
    Write-Host "      $url"
    if (-not (Test-HcHasDisplay)) { return $true }
    try { Open-HcBrowser $url } catch { Write-HcWarn "브라우저를 자동으로 열지 못했습니다. 위 주소를 직접 열어 주세요." }
    return $true
}

function Get-HcStepBody {
    param([string]$Key)
    switch ($Key) {
        "preflight" { return { Invoke-HcStepPreflight } }
        "node"      { return { Invoke-HcStepNode } }
        "paperclip" { return { Invoke-HcStepPaperclip } }
        "hermes"    { return { Invoke-HcStepHermes } }
        "onboard"   { return { Invoke-HcStepOnboard } }
        "autostart" { return { Invoke-HcStepAutostart } }
        "seed"      { return { Invoke-HcStepSeed } }
        "shortcuts" { return { Invoke-HcStepShortcuts } }
        "open"      { return { Invoke-HcStepOpen } }
        default     { return { return $false } }
    }
}

function Invoke-HcInstall {
    Set-HcManifest "INSTALLER_VERSION" (Get-HcVersion)
    # 내장 Postgres 는 승격된 관리자 토큰에서 기동하지 않는다(실측). 그래서 서버는
    # 제한 토큰으로 띄운다(Start-HcProcessRestricted). 사용자에게만 알린다.
    if (Test-HcElevated) {
        Write-Host "      · 관리자 권한이 감지되어 Paperclip 서버를 제한 권한으로 실행합니다."
    }
    $steps = Get-HcInstallSteps
    $total = $steps.Count
    foreach ($s in $steps) {
        $body = Get-HcStepBody $s.Key
        if (-not (Invoke-HcStep $s.N $total $body $s.Label)) {
            Write-HcFail "설치를 중단합니다 (단계 $($s.N))"
            return $false
        }
    }
    Write-Host ""
    Write-Host "설치가 끝났습니다. 대시보드: $(Get-HcServerUrl)"
    return $true
}

function Get-HcVersion {
    $f = Join-Path (Get-HcRoot) "VERSION"
    if (Test-Path -LiteralPath $f) { return (Get-Content -LiteralPath $f -Raw).Trim() }
    return ""
}

# --- 상태·연결·제거 --------------------------------------------------------

function Invoke-HcStatus {
    $ver = Get-HcManifest "INSTALLER_VERSION"
    $running = Test-HcServerRunning
    $auto = Get-HcAutostartStatus
    $state = "중지됨"
    if ($running) { $state = "실행 중" }
    Write-Host "Hermes + Paperclip $ver"
    Write-Host "서버: $state      자동 시작: $auto"
    Write-Host "주소: $(Get-HcServerUrl)"
    return $true
}

function Invoke-HcConnect {
    $url = Get-HcHermesDashboardUrl
    if (Start-HcHermesDashboard) {
        Write-Host "AI 연결 화면: $url"
        if (-not $env:HC_SKIP_OPEN -and (Test-HcHasDisplay)) {
            try { Open-HcBrowser $url } catch { Write-HcWarn "브라우저를 자동으로 열지 못했습니다. 위 주소를 직접 열어 주세요." }
        }
        return $true
    }
    Write-HcWarn "AI 연결 화면을 열지 못했습니다. 터미널 설정으로 진행합니다."
    $hermes = Join-Path (Get-HcBinDir) "hermes.exe"
    if (-not (Test-Path -LiteralPath $hermes)) { $hermes = "hermes" }
    Invoke-HcRun $hermes @("setup") | Out-Null
    return $true
}

function Remove-HcPathEntry {
    param([string]$Dir)
    $target = $Dir.TrimEnd('\')
    $cur = Get-HcUserPath
    if ($null -eq $cur) { $cur = "" }
    $kept = @($cur.Split(';') | Where-Object { $_.Trim() -ne "" -and $_.Trim().TrimEnd('\') -ine $target })
    Set-HcUserPath ($kept -join ';')
}

function Remove-HcTree {
    param([string]$Path)
    if (-not $Path) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }
    # npm 이 만든 읽기 전용 디렉터리는 Remove-Item 만으로 지워지지 않는다.
    try {
        Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_.Attributes = 'Normal' } catch { }
        }
    } catch { }
    # 방금 죽은 서버가 파일 핸들을 놓는 데 잠깐 걸릴 수 있다(제거 시 잔존 방지).
    for ($i = 0; $i -lt 5; $i++) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $Path)) { return }
        Start-Sleep -Milliseconds 1000
    }
}

function Invoke-HcUninstall {
    param([switch]$Yes)
    # 삭제 전에 먼저 읽는다. 아래에서 앱 디렉터리를 지우면 매니페스트가 사라진다.
    $hermesExisted = Get-HcManifest "HERMES_EXISTED"
    $bin = Get-HcBinDir

    Write-Host "다음이 지워집니다:"
    Write-Host ""
    Write-Host "  - 자동 시작 등록"
    Write-Host "  - Paperclip 과 데이터 폴더 ($(Get-HcDataDir))"
    Write-Host "  - Hermes Agent, Node.js"
    Write-Host "  - 설치 상태와 로그 ($(Get-HcAppDir))"
    Write-Host "  - 관리용 파일 ($(Get-HcShortcutDir))"
    Write-Host ""

    if (-not $Yes) {
        $ans = Read-Host "정말 제거할까요? (y/N)"
        if ($ans -notin @("y", "Y", "yes", "YES")) { Write-Host "취소했습니다."; return $true }
    }

    Stop-HcServerBackground | Out-Null
    if (-not $env:HC_SKIP_AUTOSTART) { Remove-HcAutostart | Out-Null }

    $pc = Join-Path $bin "paperclipai.cmd"
    if (Test-Path -LiteralPath $pc) { try { & $pc uninstall 2>$null | Out-Null } catch { } }
    Remove-Item -LiteralPath $pc -Force -ErrorAction SilentlyContinue

    $uv = Join-Path $bin "uv.exe"
    if (Test-Path -LiteralPath $uv) { try { & $uv tool uninstall hermes-agent 2>$null | Out-Null } catch { } }
    Remove-Item -LiteralPath (Join-Path $bin "hermes.exe") -Force -ErrorAction SilentlyContinue

    Remove-HcPathEntry $bin
    Remove-HcPathEntry (Get-HcNodeDir)
    Remove-HcTree (Get-HcNodeDir)
    Remove-HcTree (Get-HcDataDir)
    Remove-HcTree (Get-HcAppDir)
    Remove-HcTree (Get-HcShortcutDir)

    if ($hermesExisted -eq "true") {
        Write-Host "원래 있던 Hermes 설정(~/.hermes)은 그대로 두었습니다."
    } else {
        Remove-HcTree (Join-Path $env:USERPROFILE ".hermes")
    }
    return $true
}

# --- 업데이트 --------------------------------------------------------------
# 설치기 자신 + Paperclip + Hermes. 같은 버전이면 건너뛰고, 실패하면 매니페스트
# 버전을 이전 값으로 되돌린다(셸 update.sh 의 롤백 규칙).

function Get-HcCurrentVersion { return (Get-HcManifest "INSTALLER_VERSION") }

function Get-HcLatestVersion {
    if ($env:HC_LATEST_VERSION) { return $env:HC_LATEST_VERSION }
    $base = $env:HC_RELEASE_BASE
    if (-not $base) { $base = "https://github.com/giljae/hermes-paperclip-native/releases/latest/download" }
    try { return (Invoke-WebRequest -Uri "$base/VERSION" -UseBasicParsing).Content.Trim() }
    catch { return "" }
}

function Test-HcUpdateNeeded {
    $cur = Get-HcCurrentVersion
    $lat = Get-HcLatestVersion
    if (-not $lat) { return $false }
    return ($lat -ne $cur)
}

function Install-HcAppVersion {
    param([string]$Version)
    $appVer = Join-Path (Get-HcAppDir) "app\$Version"
    New-Item -ItemType Directory -Force -Path $appVer | Out-Null

    # 개발·스모크: 릴리스 대신 현재 소스를 쓴다(셸 update.sh 가 root 를 복사하는 것과 같다).
    if ($env:HC_SOURCE_DIR -and (Test-Path -LiteralPath (Join-Path $env:HC_SOURCE_DIR "win\commands.ps1"))) {
        Copy-Item -Path (Join-Path $env:HC_SOURCE_DIR "*") -Destination $appVer -Recurse -Force
        if (-not (Test-Path -LiteralPath (Join-Path $appVer "win\commands.ps1"))) {
            throw "새 버전 파일을 찾을 수 없습니다: $appVer"
        }
        return $appVer
    }

    $base = $env:HC_RELEASE_BASE
    if (-not $base) { $base = "https://github.com/giljae/hermes-paperclip-native/releases/latest/download" }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("hc-upd-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $zip = Join-Path $tmp "app.zip"
        Invoke-WebRequest -Uri "$base/hermes-paperclip-$Version.zip" -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
        $inner = Get-ChildItem -LiteralPath $tmp -Directory |
            Where-Object { $_.Name -ne "__MACOSX" } | Select-Object -First 1
        $from = $tmp
        if ($inner) { $from = $inner.FullName }
        Copy-Item -Path (Join-Path $from "*") -Destination $appVer -Recurse -Force
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path -LiteralPath (Join-Path $appVer "win\commands.ps1"))) {
        throw "새 버전 파일을 찾을 수 없습니다(Windows Defender 격리 가능성): $appVer"
    }
    return $appVer
}

function Invoke-HcUpdate {
    $cur = Get-HcCurrentVersion
    $lat = Get-HcLatestVersion
    if (-not $lat) { Write-HcWarn "최신 버전을 확인하지 못했습니다"; return $true }
    if ($lat -eq $cur) { Write-HcSkip "이미 최신입니다 ($cur)"; return $true }

    Write-Host "업데이트합니다: $cur → $lat"
    if ($env:HC_DRY_RUN) {
        Write-Host "app/$lat 에 새 버전을 설치하고 다시 시작합니다"
        return $true
    }

    try {
        Install-HcAppVersion $lat | Out-Null
    } catch {
        Set-HcManifest "INSTALLER_VERSION" $cur
        Write-HcFail "업데이트에 실패해 이전 버전으로 되돌렸습니다 ($cur): $($_.Exception.Message)"
        return $false
    }

    $env:PAPERCLIP_HOME = Get-HcDataDir
    $pc = Join-Path (Get-HcBinDir) "paperclipai.cmd"
    if (Test-Path -LiteralPath $pc) { try { & $pc update 2>$null | Out-Null } catch { } }
    $hm = Join-Path (Get-HcBinDir) "hermes.exe"
    if (Test-Path -LiteralPath $hm) { try { & $hm update 2>$null | Out-Null } catch { } }

    Set-HcManifest "INSTALLER_VERSION" $lat
    # 새 버전으로 다시 시작한다(자동 시작 실패 시 백그라운드 폴백).
    if (-not (Install-HcAutostart)) { Start-HcServerBackground | Out-Null }
    Write-HcOk "업데이트 완료 ($lat)"
    return $true
}

function Invoke-HcVerify {
    $bin = Get-HcBinDir
    $ok = $true
    foreach ($tool in @("node.exe", "uv.exe", "hermes.exe", "paperclipai.cmd")) {
        if (Test-Path -LiteralPath (Join-Path $bin $tool)) { Write-HcOk $tool }
        else { Write-HcWarn "$tool 없음"; $ok = $false }
    }
    return $ok
}

# --- 디스패치 --------------------------------------------------------------

function Invoke-HcDispatch {
    param([string]$Command = "", [string]$Arg = "")
    switch ($Command) {
        "install"   { return (Invoke-HcInstall) }
        "update"    { return (Invoke-HcUpdate) }
        "start"     { return (Start-HcServerBackground) }
        "stop"      { return (Stop-HcServerBackground) }
        "status"    { return (Invoke-HcStatus) }
        "connect"   { return (Invoke-HcConnect) }
        "uninstall" { return (Invoke-HcUninstall -Yes:($Arg -eq "--yes")) }
        "verify"    { return (Invoke-HcVerify) }
        default {
            Write-Host "사용법: commands.ps1 <install|update|start|stop|status|connect|uninstall|verify>"
            return $false
        }
    }
}

# 직접 실행될 때만 디스패치한다(테스트에서 dot-source 할 때는 아무것도 하지 않는다).
if ($MyInvocation.InvocationName -ne ".") {
    Invoke-HcDispatch -Command $args[0] -Arg $args[1]
}
