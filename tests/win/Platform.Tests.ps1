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
    } }
)
