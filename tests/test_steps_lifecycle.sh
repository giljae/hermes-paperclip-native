#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
. "$HERE/../platform/macos.sh"
. "$HERE/../core/steps/60-autostart.sh"
. "$HERE/../core/steps/80-open.sh"
. "$HERE/../core/steps/90-verify.sh"
export HC_NO_COLOR=1

t_autostart_skip() { export HC_HOME="$(mktemp -d)"; local out; out="$(HC_SKIP_AUTOSTART=1 step_autostart 2>&1)"; assert_contains "$out" "건너뜀" "자동 시작 건너뛰기"; }
t_open_skip()      { export HC_HOME="$(mktemp -d)"; local out; out="$(HC_SKIP_OPEN=1 step_open 2>&1)"; assert_contains "$out" "건너뜀" "브라우저 건너뛰기"; }
t_open_prints_url() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  p_open_browser() { printf 'OPEN %s\n' "$1"; }
  local out; out="$(step_open 2>&1)"; assert_contains "$out" "http://127.0.0.1:3100" "URL 출력"
}
t_status_cmd() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  local out; out="$(cmd_status 2>&1)"
  assert_contains "$out" "http://127.0.0.1:3100" "상태에 주소"
  assert_contains "$out" "Paperclip" "상태에 버전"
}
t_stop_cmd_skip() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  local out; out="$(HC_SKIP_AUTOSTART=1 cmd_stop 2>&1)"; assert_contains "$out" "미설치" "중지 시 상태 안내"
}
t_verify_soft() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  HC_DRY_RUN=1 step_verify >/dev/null 2>&1; assert_status 0 $? "verify 실패는 설치를 깨지 않는다"
}
run_tests t_autostart_skip t_open_skip t_open_prints_url t_status_cmd t_stop_cmd_skip t_verify_soft
