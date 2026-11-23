# Windows 플랫폼 함수(감지·경로·브라우저·로그).
#
# 이 환경(로컬)은 macOS + pwsh 7 이라 Windows 전용 분기는 프록시로만 확인된다.
# 실제 PowerShell 5.1 동작은 windows CI 가 검증한다.
. "$PSScriptRoot\Assert.ps1"
. "$PSScriptRoot\..\..\win\platform.ps1"

# $env:TEMP 는 Windows 에만 있다. macOS 에서도 같은 테스트를 돌리기 위해
# GetTempPath() 로 폴백한다(셸 구현의 크로스플랫폼 테스트와 같은 판단).
function New-HcTempDir {
    $base = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
    $d = Join-Path $base ("hc-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    return $d
}

# 사용자 PATH 영속화는 Windows 전용 부작용이라 macOS 에서는 실제 저장소를 쓸 수 없다.
# Add-HcToUserPath 가 이 두 함수를 통해서만 환경을 읽고 쓰므로, 테스트는 메모리
# 저장소로 갈아끼워 중복 방지·보존 규칙을 실제로 검증한다(의존성 주입).
$script:HcTestUserPath = $null
function Get-HcUserPath { return $script:HcTestUserPath }
function Set-HcUserPath { param([string]$Value) $script:HcTestUserPath = $Value }

$script:Tests = @(
    @{ Name = "경로는 LOCALAPPDATA 아래다"; Body = {
        Remove-Item Env:\HC_HOME -ErrorAction SilentlyContinue
        Assert-Equal "$env:LOCALAPPDATA\hermes-paperclip-native" (Get-HcAppDir) "app dir"
        Assert-Equal "$env:USERPROFILE\.paperclip" (Get-HcDataDir) "data dir"
        Assert-Equal "$(Get-HcAppDir)\bin" (Get-HcBinDir) "bin dir"
        Assert-Equal "$(Get-HcAppDir)\node" (Get-HcNodeDir) "node dir"
    } },
    @{ Name = "한글·공백 경로에서도 로그를 쓴다"; Body = {
        $d = Join-Path (New-HcTempDir) "김 철수 테스트"
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        $env:HC_HOME = $d
        Write-HcLog "테스트"
        $log = Join-Path $d "logs\install.log"
        Assert-True (Test-Path -LiteralPath $log) "로그 파일"
        Assert-Contains (Get-Content -LiteralPath $log -Raw) "테스트" "로그 내용"
    } },
    @{ Name = "Node URL"; Body = {
        Assert-Equal "https://nodejs.org/dist/v24.20.0/node-v24.20.0-win-x64.zip" (Get-HcNodeArchiveUrl "24.20.0") "url"
    } },
    @{ Name = "Get-HcPlatform 은 windows 와 아키텍처를 보고한다"; Body = {
        $env:PROCESSOR_ARCHITECTURE = "AMD64"
        $p = Get-HcPlatform
        Assert-Equal "windows" $p.OS "OS"
        Assert-Equal "x64" $p.Arch "Arch"
    } },
    @{ Name = "서버 주소 기본값"; Body = {
        Remove-Item Env:\HC_HOME -ErrorAction SilentlyContinue
        Assert-Equal "http://127.0.0.1:3100" (Get-HcServerUrl) "기본 포트"
    } },
    @{ Name = "서버 주소는 설정에서 포트를 읽는다"; Body = {
        $up = New-HcTempDir
        $env:USERPROFILE = $up
        $inst = Join-Path $up ".paperclip\instances\default"
        New-Item -ItemType Directory -Force -Path $inst | Out-Null
        Set-Content -LiteralPath (Join-Path $inst "config.json") -Value '{ "port": 4321 }'
        Assert-Equal "http://127.0.0.1:4321" (Get-HcServerUrl) "읽은 포트"
    } },
    @{ Name = "Get-HcTailLog 는 최신 로그의 끝을 돌려준다"; Body = {
        $up = New-HcTempDir
        $env:USERPROFILE = $up
        $logdir = Join-Path $up ".paperclip\instances\default\logs"
        New-Item -ItemType Directory -Force -Path $logdir | Out-Null
        Set-Content -LiteralPath (Join-Path $logdir "server.log") -Value @("l1", "l2", "l3", "l4")
        Assert-Equal "l3`nl4" (Get-HcTailLog 2) "마지막 2줄"
    } },
    @{ Name = "PATH 뒤에 덧붙이고 기존 값을 보존한다"; Body = {
        Remove-Item Env:\HC_HOME -ErrorAction SilentlyContinue
        $script:HcTestUserPath = "C:\Windows;C:\Tools"
        $before = $script:HcTestUserPath
        Add-HcToUserPath
        $after = Get-HcUserPath
        $bin = Get-HcBinDir
        Assert-True ($after -like "*$bin*") "bin 이 추가됨"
        Assert-True ($after.Contains("C:\Tools")) "기존 PATH 가 보존됨"
        Assert-True ($after.Split(';').Count -le ($before.Split(';').Count + 1)) "중복 추가 없음"
    } },
    @{ Name = "두 번 실행해도 한 번만 추가한다"; Body = {
        Remove-Item Env:\HC_HOME -ErrorAction SilentlyContinue
        $script:HcTestUserPath = ""
        Add-HcToUserPath; Add-HcToUserPath
        $bin = Get-HcBinDir
        $n = ($script:HcTestUserPath.Split(';') | Where-Object { $_.Trim() -ieq $bin }).Count
        Assert-Equal 1 $n "중복 없음"
    } },
    @{ Name = "schtasks 를 쓸 수 없으면 false 를 돌려준다(예외 아님)"; Body = {
        function global:schtasks { throw "unavailable" }
        try {
            $r = Install-HcAutostart
            Assert-Equal $false $r "폴백 신호"
        } finally {
            Remove-Item function:global:schtasks -ErrorAction SilentlyContinue
        }
    } },
    @{ Name = "백그라운드 pidfile 수명주기"; Body = {
        $env:HC_HOME = New-HcTempDir
        Assert-Equal $false (Test-HcServerRunning) "처음엔 아님"
        Set-Content -LiteralPath (Get-HcServerPidFile) -Value "999999" -Encoding ascii
        Assert-Equal $false (Test-HcServerRunning) "죽은 pid 는 아님"
        Set-Content -LiteralPath (Get-HcServerPidFile) -Value "$PID" -Encoding ascii
        Assert-Equal $true (Test-HcServerRunning) "살아 있는 pid 는 켜짐"
        Set-Content -LiteralPath (Get-HcServerPidFile) -Value "999999" -Encoding ascii
        Stop-HcServerBackground | Out-Null
        Assert-True (-not (Test-Path -LiteralPath (Get-HcServerPidFile))) "pidfile 삭제"
    } },
    @{ Name = "자동 시작 상태는 등록이 없으면 absent 다"; Body = {
        $env:HC_HOME = New-HcTempDir
        Assert-Equal "absent" (Get-HcAutostartStatus) "등록 없음"
    } }
)
