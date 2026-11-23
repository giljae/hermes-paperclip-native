# Windows 전용 플랫폼 함수. win/core.ps1 은 이 파일의 함수만 호출한다.
#
# PowerShell 5.1 호환: `??`, 삼항 연산자, `ForEach-Object -Parallel` 을 쓰지 않는다.
# Windows 10/11 에 기본 내장이라 사용자가 아무것도 설치하지 않아도 된다.
#
# 경로는 항상 큰따옴표/LiteralPath 로 다룬다. 한글 사용자명(`C:\Users\김철수`)과
# 공백을 전제로 한다.

function Get-HcAppDir {
    if ($env:HC_HOME) { return $env:HC_HOME }
    return "$env:LOCALAPPDATA\hermes-paperclip-native"
}

function Get-HcBinDir  { return "$(Get-HcAppDir)\bin" }
function Get-HcNodeDir { return "$(Get-HcAppDir)\node" }
function Get-HcDataDir { return "$env:USERPROFILE\.paperclip" }
function Get-HcLogDir  { return "$(Get-HcAppDir)\logs" }
function Get-HcLogFile { return "$(Get-HcLogDir)\install.log" }

# 감지 결과: @{ OS = 'windows'; Arch = 'x64'|'arm64'; Version = <string> }
# 셸 구현의 p_detect 가 채우는 P_OS/P_ARCH/P_OS_VERSION 에 대응한다.
function Get-HcPlatform {
    $arch = "x64"
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { $arch = "arm64" }
    elseif ($env:PROCESSOR_ARCHITEW6432 -eq "ARM64") { $arch = "arm64" }
    $ver = "unknown"
    try { $ver = [Environment]::OSVersion.Version.ToString() } catch { $ver = "unknown" }
    return @{ OS = "windows"; Arch = $arch; Version = $ver }
}

# Windows 데스크톱에는 항상 GUI 세션이 있다.
function Test-HcHasDisplay { return $true }

# Node 공식 win-x64/win-arm64 zip. 압축을 풀면 node-v<ver>-win-<arch>\ 아래에 들어 있다.
function Get-HcNodeArchiveUrl {
    param([string]$Version)
    $arch = (Get-HcPlatform).Arch
    return "https://nodejs.org/dist/v$Version/node-v$Version-win-$arch.zip"
}

# Paperclip 설정에서 실제 포트를 읽는다. 3100 이 점유되면 Paperclip 이 다른 포트를
# 고르므로, 여기서 3100 을 가정하면 사용자는 빈 화면을 본다(셸 구현과 같은 계약).
function Get-HcServerUrl {
    $cfg = Join-Path (Get-HcDataDir) "instances\default\config.json"
    $port = ""
    if (Test-Path -LiteralPath $cfg) {
        $txt = Get-Content -LiteralPath $cfg -Raw
        $m = [regex]::Match($txt, '"port"\s*:\s*(\d+)')
        if ($m.Success) { $port = $m.Groups[1].Value }
    }
    if (-not $port) { $port = "3100" }
    return "http://127.0.0.1:$port"
}

function Open-HcBrowser {
    param([string]$Url)
    Start-Process $Url
}

# 최신 로그 파일의 마지막 Lines 줄을 하나의 문자열로 돌려준다(셸의 p_tail_log 계약).
function Get-HcTailLog {
    param([int]$Lines = 5)
    $dir = Join-Path (Get-HcDataDir) "instances\default\logs"
    if (-not (Test-Path -LiteralPath $dir)) { return "" }
    $f = Get-ChildItem -LiteralPath $dir -Filter "*.log" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $f) { return "" }
    return ((Get-Content -LiteralPath $f.FullName -Tail $Lines) -join "`n")
}

# 설치 로그. 한글 경로에서도 안전하도록 UTF8 로 쓴다.
function Write-HcLog {
    param([string]$Message)
    New-Item -ItemType Directory -Force -Path (Get-HcLogDir) | Out-Null
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Add-Content -LiteralPath (Get-HcLogFile) -Value "[$ts] $Message" -Encoding UTF8
}

# 이 환경에서 설치가 가능한지 판정한다. 셸의 p_require_supported 에 대응한다.
#   - 64비트가 아니면 중단한다(32비트 Windows 는 지원하지 않는다).
#   - 관리자 권한이면 경고만 한다: 설치는 사용자 범위라 동작한다.
function Test-HcRequireSupported {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw "64비트 Windows가 필요합니다 (현재: 32비트)."
    }
    if ($env:OS -eq "Windows_NT") {
        try {
            $id = [Security.Principal.WindowsIdentity]::GetCurrent()
            $pr = New-Object Security.Principal.WindowsPrincipal($id)
            if ($pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                Write-Warning "관리자 권한으로 실행 중입니다. 설치는 사용자 범위에서 진행됩니다."
            }
        } catch { }
    }
    return $true
}
