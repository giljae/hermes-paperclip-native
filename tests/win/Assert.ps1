# 테스트 단언. 카운터는 러너(run.ps1)의 스크립트 범위에 있다.
function Assert-Equal {
    param([string]$Expected, [string]$Actual, [string]$Label)
    $script:TestsRun++
    if ($Expected -ceq $Actual) { Write-Host "  ✓ $Label"; return }
    $script:TestsFailed++
    Write-Host "  ✗ $Label" -ForegroundColor Red
    Write-Host "      expected: $Expected"
    Write-Host "      actual:   $Actual"
}

function Assert-Contains {
    param([string]$Haystack, [string]$Needle, [string]$Label)
    $script:TestsRun++
    if ($Haystack -like "*$Needle*") { Write-Host "  ✓ $Label"; return }
    $script:TestsFailed++
    Write-Host "  ✗ $Label" -ForegroundColor Red
    Write-Host "      '$Needle' 를 포함하지 않음"
}

function Assert-True {
    param($Condition, [string]$Label)
    $script:TestsRun++
    if ($Condition) { Write-Host "  ✓ $Label"; return }
    $script:TestsFailed++
    Write-Host "  ✗ $Label" -ForegroundColor Red
}
