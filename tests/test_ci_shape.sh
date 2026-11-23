#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
CI="$HERE/../.github/workflows/ci.yml"

t_ci_exists()  { assert_status 0 "$([ -f "$CI" ]; echo $?)" "워크플로 존재"; }
t_ci_macos()   { assert_contains "$(cat "$CI" 2>/dev/null)" "macos-latest" "macOS 러너"; }
t_ci_test()    { assert_contains "$(cat "$CI" 2>/dev/null)" "make test" "단위 테스트 실행"; }
t_ci_smoke()   { assert_contains "$(cat "$CI" 2>/dev/null)" "tests/smoke.sh" "스모크 실행"; }
t_ci_nostart() { assert_contains "$(cat "$CI" 2>/dev/null)" "HC_SKIP_AUTOSTART" "CI 에서 자동 시작을 끈다"; }
t_ci_ubuntu()      { assert_contains "$(cat "$CI" 2>/dev/null)" "ubuntu-latest" "ubuntu 러너"; }
t_ci_linux_smoke() { assert_contains "$(cat "$CI" 2>/dev/null)" "test-linux" "리눅스 잡 존재"; }
t_ci_real_linux() { assert_contains "$(cat "$CI" 2>/dev/null)" "smoke-real-linux" "리눅스 실설치 잡"; }
t_ci_windows()  { assert_contains "$(cat "$CI" 2>/dev/null)" "windows-latest" "windows 러너"; }
t_ci_win_run()  { assert_contains "$(cat "$CI" 2>/dev/null)" "tests/win/run.ps1" "PowerShell 테스트 실행"; }
run_tests t_ci_windows t_ci_win_run t_ci_real_linux t_ci_exists t_ci_macos t_ci_test t_ci_smoke t_ci_nostart t_ci_ubuntu t_ci_linux_smoke
