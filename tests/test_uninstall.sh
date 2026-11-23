#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
. "$HERE/../platform/common.sh"
. "$HERE/../platform/macos.sh"
. "$HERE/../core/steps/75-shortcuts.sh"
. "$HERE/../core/steps/uninstall.sh"
export HC_NO_COLOR=1

t_plan_lists() {
  local out; out="$(uninstall_plan)"
  assert_contains "$out" "paperclip" "데이터 경로가 나열된다"
  assert_contains "$out" "Hermes" "Hermes 가 나열된다"
  assert_contains "$out" "로그" "로그가 나열된다"
}
t_preserves_hermes() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"
  p_detect
  assert_status 0 "$(type -t step_uninstall >/dev/null 2>&1; echo $?)" "step_uninstall 이 정의되어 있다"
  mkdir -p "$HOME/.hermes" "$HOME/.local/node" "$HOME/.paperclip"
  mf_set HERMES_EXISTED true
  local out; out="$(HC_SKIP_AUTOSTART=1 step_uninstall --yes 2>&1)"
  assert_status 0 "$([ -d "$HOME/.hermes" ]; echo $?)" "기존 Hermes 는 남는다"
  assert_contains "$out" "그대로 두었습니다" "보존 사실을 알린다"
}
t_removes_ours() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"
  p_detect
  mkdir -p "$HOME/.local/node" "$HOME/.paperclip" "$HC_HOME"
  mf_set HERMES_EXISTED false
  HC_SKIP_AUTOSTART=1 step_uninstall --yes >/dev/null 2>&1
  assert_status 1 "$([ -d "$HOME/.paperclip" ]; echo $?)" "우리 데이터는 지운다"
  assert_status 1 "$([ -d "$HC_HOME" ]; echo $?)" "설치 상태도 지운다"
}
t_removes_readonly_tree() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"
  p_detect
  mkdir -p "$HOME/.paperclip/ro" "$HC_HOME"
  printf 'x' > "$HOME/.paperclip/ro/f"
  chmod 500 "$HOME/.paperclip/ro"
  mf_set HERMES_EXISTED false
  HC_SKIP_AUTOSTART=1 step_uninstall --yes >/dev/null 2>&1
  chmod -R u+w "$HOME/.paperclip" 2>/dev/null
  assert_status 1 "$([ -d "$HOME/.paperclip" ]; echo $?)" "읽기 전용 하위 폴더도 지운다"
}
run_tests t_plan_lists t_preserves_hermes t_removes_ours t_removes_readonly_tree
