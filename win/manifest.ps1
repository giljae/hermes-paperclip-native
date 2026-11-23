# 설치 상태 매니페스트. key=value 형식이라 bash 와 PowerShell 양쪽에서
# 파서 의존성 없이 읽힌다(JSON 이었다면 jq 나 python3 가 필요하다).
#
# 키 이름은 셸 구현(core/manifest.sh + core/steps/*.sh)과 같다:
#   INSTALLER_VERSION, PLATFORM, NODE_VERSION, PAPERCLIP_VERSION, HERMES_VERSION,
#   PYTHON_VERSION, DATA_DIR, INSTALLED_AT, HERMES_EXISTED …

function Get-HcManifestPath { return (Join-Path (Get-HcAppDir) "manifest.env") }

function Read-HcManifest {
    $map = @{}
    $f = Get-HcManifestPath
    if (Test-Path -LiteralPath $f) {
        foreach ($line in (Get-Content -LiteralPath $f -Encoding UTF8)) {
            if ($line -match '^([^=]+)=(.*)$') { $map[$Matches[1]] = $Matches[2] }
        }
    }
    return $map
}

function Get-HcManifest {
    param([string]$Key)
    $map = Read-HcManifest
    if ($map.ContainsKey($Key)) { return $map[$Key] }
    return ""
}

# 기존 값을 지우고 key=value 를 다시 쓴다. 셸의 mf_set 과 같은 동작이다.
# BOM 없이 UTF-8 로 쓴다 — 셸 파서(sed/grep)가 첫 키 앞의 BOM 에 걸리지 않게 하기 위함.
function Set-HcManifest {
    param([string]$Key, [string]$Value)
    $f = Get-HcManifestPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $f) | Out-Null
    $lines = @()
    if (Test-Path -LiteralPath $f) {
        $lines = @(Get-Content -LiteralPath $f -Encoding UTF8 |
            Where-Object { $_ -notmatch "^$([regex]::Escape($Key))=" })
    }
    $lines += "$Key=$Value"
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllLines($f, [string[]]$lines, $enc)
}
