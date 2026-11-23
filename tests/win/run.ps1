# 테스트 러너. tests/win/*.Tests.ps1 을 이름순으로 실행한다.
#
# 실패를 놓치지 않는다: 테스트 본문이 예외로 죽으면 실패로 세고, 단언을 하나도
# 만들지 않은 테스트 파일도 실패로 센다. (초기 버전은 예외를 삼키고 pass=0 fail=0
# 으로 exit 0 했다 — 깨진 테스트가 통과로 보고되는 최악의 실패다.)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

$files = Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.Tests.ps1" | Sort-Object Name
$totalRun = 0
$totalFailed = 0
$totalTests = 0

foreach ($f in $files) {
    Write-Host ""
    Write-Host "=== $($f.Name)"
    $script:Tests = @()
    $script:TestsRun = 0
    $script:TestsFailed = 0
    try {
        . $f.FullName
    } catch {
        Write-Host "  ✗ 테스트 파일을 읽지 못했습니다: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestsRun = 0
        $script:TestsFailed = 1
    }
    foreach ($t in $script:Tests) {
        Write-Host " $($t.Name)"
        try {
            & $t.Body
        } catch {
            $script:TestsFailed++
            Write-Host "  ✗ 예외: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    if ($script:Tests -and $script:TestsRun -eq 0) {
        $script:TestsFailed++
        Write-Host "  ✗ 단언이 하나도 실행되지 않았다" -ForegroundColor Red
    }
    Write-Host "pass=$script:TestsRun fail=$script:TestsFailed"
    $totalRun += $script:TestsRun
    $totalFailed += $script:TestsFailed
    $totalTests += $script:Tests.Count
}

Write-Host ""
Write-Host "총계: tests=$totalTests pass=$totalRun fail=$totalFailed"
if ($totalFailed -gt 0) { exit 1 }
if ($totalRun -eq 0) { Write-Host "단언이 하나도 없다" -ForegroundColor Red; exit 1 }
exit 0
