#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
hc_load_platform
. "$HERE/../core/steps/70-seed.sh"
. "$HERE/../core/steps/connect.sh"
export HC_NO_COLOR=1

t_dashboard_url()    { assert_eq "http://127.0.0.1:9119" "$(p_hermes_dashboard_url)" "대시보드 URL"; }
t_dashboard_dryrun() { local out; out="$(HC_DRY_RUN=1 p_hermes_dashboard_start)"; assert_contains "$out" "hermes dashboard --no-open" "DRY_RUN 은 명령만 출력"; }
t_connect_opens()    { local out; out="$(HC_DRY_RUN=1 HC_SKIP_OPEN=1 cmd_connect 2>&1)"; assert_contains "$out" "9119" "AI연결이 대시보드 URL 을 안내"; }
t_connect_fallback() {
  p_hermes_dashboard_start() { return 1; }
  local out; out="$(HC_DRY_RUN=1 HC_SKIP_OPEN=1 cmd_connect 2>&1)"
  assert_contains "$out" "hermes setup" "대시보드 실패 시 위저드로 폴백"
}
t_connect_fallback_notty() {
  # 비TTY 면 대화형 위저드를 실행하지 않는다(입력을 기다리며 멈춤 방지).
  p_hermes_dashboard_start() { return 1; }
  connect_run() { echo "WIZARD-CALLED"; }
  local out; out="$(HC_SKIP_OPEN=1 cmd_connect < /dev/null 2>&1)"
  assert_contains "$out" "건너뜁니다" "비TTY 에서 건너뜀 안내"
  local wiz=0; case "$out" in *WIZARD-CALLED*) wiz=1 ;; esac
  assert_eq "0" "$wiz" "비TTY 에서 대화형 위저드를 호출하지 않는다"
}
run_tests t_dashboard_url t_dashboard_dryrun t_connect_opens t_connect_fallback t_connect_fallback_notty
