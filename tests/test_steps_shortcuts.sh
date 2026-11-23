#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
# 현재 플랫폼을 로드한다(OS 하드코딩 금지).
. "$HERE/../core/lib.sh"
hc_load_platform
. "$HERE/../core/steps/75-shortcuts.sh"
export HC_NO_COLOR=1

t_render_selflocating() {
  local out; out="$(shortcut_render status "상태 확인")"
  assert_contains "$out" 'HC_HOME="${HC_HOME:-$HOME/.hermes-paperclip-native}"' "홈 경로"
  assert_contains "$out" 'manifest.env' "매니페스트에서 버전을 읽는다"
  assert_contains "$out" 'run.sh" status' "명령 전달"
}
t_step_creates_files() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"
  mf_set INSTALLER_VERSION 0.1.0
  step_shortcuts
  assert_status 0 "$([ -x "$HOME/HermesPaperclip/상태.command" ]; echo $?)" "실행 권한 있는 파일 생성"
  assert_eq "6" "$(ls -1 "$HOME/HermesPaperclip"/*.command 2>/dev/null | wc -l | tr -d ' ')" "명령 파일 6개"
}
run_tests t_render_selflocating t_step_creates_files
