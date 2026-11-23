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
run_tests t_ci_exists t_ci_macos t_ci_test t_ci_smoke t_ci_nostart
