#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/run.sh"
export HC_HOME="$(mktemp -d)" HC_NO_COLOR=1

step_ok()   { return 0; }
step_bad()  { return 1; }

t_step_ok()   { local out; out="$(HC_HOME="$HC_HOME" hc_run_step 1 8 step_ok "확인" 2>&1)"; assert_contains "$out" "✓ 확인" "성공 라벨"; }
t_step_hard() { HC_HOME="$HC_HOME" hc_run_step 2 8 step_bad "실패단계" >/dev/null 2>&1; assert_status 1 $? "실패하면 1"; }
t_step_soft() { HC_HOME="$HC_HOME" hc_run_step 2 8 step_bad "무른단계" soft >/dev/null 2>&1; assert_status 0 $? "soft 는 0"; }
t_unknown()   { hc_dispatch "존재하지않음" >/dev/null 2>&1; assert_status 2 $? "알 수 없는 명령은 2"; }
t_steps_list(){ assert_contains "$(hc_install_steps)" "preflight" "단계 목록에 preflight"; }
t_install_propagates_failure() {
  step_preflight() { return 1; }
  cmd_install >/dev/null 2>&1
  assert_status 1 $? "단계 실패가 설치 실패로 전파된다"
}
run_tests t_step_ok t_step_hard t_step_soft t_unknown t_steps_list t_install_propagates_failure
