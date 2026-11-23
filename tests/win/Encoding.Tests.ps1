# 한국어와 인코딩. BOM 없는 .ps1 은 PowerShell 5.1 에서 한국어를 코드페이지로
# 읽어 문구가 깨진다(설치 안내가 외계어가 된다).
. "$PSScriptRoot\Assert.ps1"

$script:Tests = @(
    @{ Name = "한국어 문자열이 왕복한다"; Body = {
        $s = "저장 공간이 부족합니다"
        Assert-Equal "저장 공간이 부족합니다" $s "한국어 왕복"
    } },
    @{ Name = "이 파일에 UTF-8 BOM 이 있다"; Body = {
        $bytes = [IO.File]::ReadAllBytes($PSCommandPath)
        Assert-True ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) "BOM 존재"
    } },
    @{ Name = "콘솔 출력 인코딩이 UTF-8"; Body = {
        Assert-Equal "utf-8" ([Console]::OutputEncoding.WebName) "OutputEncoding"
    } }
)
