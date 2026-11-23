#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"

t_smoke_exists()   { assert_status 0 "$([ -x "$HERE/../tests/smoke.sh" ]; echo $?)" "smoke.sh 실행 가능"; }
t_smoke_fakehome() { assert_contains "$(cat "$HERE/../tests/smoke.sh" 2>/dev/null)" "HC_HOME=" "가짜 HOME 을 쓴다"; }
t_smoke_never_real_home() {
  if grep -qE 'rm -rf "?\$HOME"?' "$HERE/../tests/smoke.sh" 2>/dev/null; then
    assert_eq "unsafe" "found" "실제 HOME 을 지우면 안 된다"
  else
    assert_eq "ok" "ok" "실제 HOME 삭제 없음"
  fi
}
run_tests t_smoke_exists t_smoke_fakehome t_smoke_never_real_home
