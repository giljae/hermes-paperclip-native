# 코어(매니페스트·단계 실행기·도구 설치). 셸 구현(core/)과 계약이 같아야 한다.
# 이 환경은 macOS + pwsh 7 이고, 실제 도구 설치(네트워크/Windows)는 windows CI 스모크가 맡는다.
. "$PSScriptRoot\Assert.ps1"
. "$PSScriptRoot\..\..\win\platform.ps1"
. "$PSScriptRoot\..\..\win\manifest.ps1"
. "$PSScriptRoot\..\..\win\core.ps1"

function New-HcTempDir {
    $base = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
    $d = Join-Path $base ("hc-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    return $d
}

$script:Tests = @(
    @{ Name = "매니페스트는 셸 구현과 같은 형식"; Body = {
        $env:HC_HOME = New-HcTempDir
        Set-HcManifest "NODE_VERSION" "24.20.0"
        Assert-Equal "24.20.0" (Get-HcManifest "NODE_VERSION") "저장 후 조회"
        Assert-Contains (Get-Content -LiteralPath (Get-HcManifestPath) -Raw) "NODE_VERSION=24.20.0" "key=value 형식"
    } },
    @{ Name = "매니페스트는 키를 갱신하고 다른 키를 보존한다"; Body = {
        $env:HC_HOME = New-HcTempDir
        Set-HcManifest "A" "1"
        Set-HcManifest "B" "2"
        Set-HcManifest "A" "3"
        Assert-Equal "3" (Get-HcManifest "A") "갱신"
        Assert-Equal "2" (Get-HcManifest "B") "다른 키 보존"
        Assert-Equal 2 (Read-HcManifest).Count "키 수"
    } },
    @{ Name = "단계 실패는 전체를 실패시킨다"; Body = {
        $ok = Invoke-HcStep 1 9 { return $false } "실패단계"
        Assert-True (-not $ok) "false 반환"
    } },
    @{ Name = "soft 단계는 실패해도 계속한다"; Body = {
        $ok = Invoke-HcStep 1 9 { return $false } "무른단계" $true
        Assert-True $ok "true 반환"
    } },
    @{ Name = "성공한 단계는 true 를 돌려준다"; Body = {
        $ok = Invoke-HcStep 1 9 { return $true } "성공단계"
        Assert-True $ok "true 반환"
    } },
    @{ Name = "단계 라벨이 셸 구현과 같다"; Body = {
        $labels = (Get-HcInstallSteps).Label
        Assert-Equal 9 $labels.Count "9 단계"
        Assert-Equal "이 컴퓨터를 확인하는 중..." $labels[0] "1단계 라벨"
        Assert-Equal "브라우저를 여는 중..." $labels[8] "9단계 라벨"
    } },
    @{ Name = "DRY_RUN 은 실행하지 않고 명령만 돌려준다"; Body = {
        $env:HC_DRY_RUN = "1"
        $r = Invoke-HcRun "node" @("--version")
        Remove-Item Env:\HC_DRY_RUN -ErrorAction SilentlyContinue
        Assert-Contains $r "node" "명령 문자열"
    } }
)
