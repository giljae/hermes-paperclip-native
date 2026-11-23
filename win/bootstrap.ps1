# 한 줄 설치 진입점:
#   irm https://github.com/giljae/hermes-paperclip-native/releases/latest/download/bootstrap.ps1 | iex
#
# 릴리스 zip 을 받아 %LOCALAPPDATA%\hermes-paperclip-native\app\<ver> 에 풀고
# win\commands.ps1 install 을 실행한다. HC_SOURCE_DIR 가 있으면 그 디렉터리를
# 그대로 쓴다(개발·스모크용).
#
# 관리자 권한을 요구하지 않는다 — 모든 것을 사용자 범위(%LOCALAPPDATA%,
# %USERPROFILE%) 안에 설치한다.

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$HcAppDir = if ($env:HC_HOME) { $env:HC_HOME } else { "$env:LOCALAPPDATA\hermes-paperclip-native" }
$HcReleaseBase = if ($env:HC_RELEASE_BASE) { $env:HC_RELEASE_BASE } else { "https://github.com/giljae/hermes-paperclip-native/releases/latest/download" }

function Write-HcBootStep { param([string]$Message) Write-Host "[설치] $Message" }

$ver = ""
if ($env:HC_SOURCE_DIR) {
    $src = $env:HC_SOURCE_DIR
    $ver = (Get-Content -LiteralPath (Join-Path $src "VERSION") -Raw).Trim()
    $appVer = Join-Path $HcAppDir "app\$ver"
    New-Item -ItemType Directory -Force -Path $appVer | Out-Null
    Copy-Item -Path (Join-Path $src "*") -Destination $appVer -Recurse -Force
} else {
    Write-HcBootStep "최신 버전을 확인하는 중..."
    $ver = (Invoke-WebRequest -Uri "$HcReleaseBase/VERSION" -UseBasicParsing).Content.Trim()
    $appVer = Join-Path $HcAppDir "app\$ver"
    New-Item -ItemType Directory -Force -Path $appVer | Out-Null

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("hc-boot-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $zip = Join-Path $tmp "app.zip"
        Write-HcBootStep "내려받는 중... ($ver)"
        Invoke-WebRequest -Uri "$HcReleaseBase/hermes-paperclip-$ver.zip" -OutFile $zip -UseBasicParsing

        # checksums.txt 가 있으면 검증한다(없으면 건너뛴다).
        $wantHash = ""
        try {
            $sums = (Invoke-WebRequest -Uri "$HcReleaseBase/checksums.txt" -UseBasicParsing).Content
            $line = ($sums -split "`n" | Where-Object { $_ -match [regex]::Escape("hermes-paperclip-$ver.zip") } | Select-Object -First 1)
            if ($line) { $wantHash = ($line -split '\s+')[0].ToLower() }
        } catch { }
        if ($wantHash) {
            $gotHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
            if ($wantHash -ne $gotHash) { throw "다운로드한 파일의 체크섬이 다릅니다." }
        }

        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
        # zip 루트에 하위 폴더가 있으면 그 안을 복사한다.
        $inner = Get-ChildItem -LiteralPath $tmp -Directory |
            Where-Object { $_.Name -ne "__MACOSX" } | Select-Object -First 1
        $from = $tmp
        if ($inner) { $from = $inner.FullName }
        Copy-Item -Path (Join-Path $from "*") -Destination $appVer -Recurse -Force
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$commands = Join-Path $appVer "win\commands.ps1"

# Windows Defender 가 uv.exe 를 격리하면(문서화된 오탐) 설치 중 파일이 사라진다.
# 원인을 알 수 없게 실패하지 않도록, 풀린 직후 핵심 파일 존재를 확인한다.
if (-not (Test-Path -LiteralPath $commands)) {
    Write-Host ""
    Write-Host "✗ 설치 파일을 찾을 수 없습니다: $commands"
    Write-Host "  Windows Defender 가 파일을 격리했을 수 있습니다."
    Write-Host "  '바이러스 및 위협 방지 > 제외' 에 다음을 추가한 뒤 다시 실행해 주세요:"
    Write-Host "    $HcAppDir"
    return
}

Write-HcBootStep "설치를 시작합니다..."
& powershell -NoProfile -ExecutionPolicy Bypass -File $commands install
