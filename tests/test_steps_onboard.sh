#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
. "$HERE/../core/fetch.sh"
. "$HERE/../platform/common.sh"
. "$HERE/../platform/macos.sh"
. "$HERE/../core/steps/50-onboard.sh"
export HC_NO_COLOR=1

t_onboard_skip() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  mkdir -p "$HOME/.paperclip/instances/default"; printf '{}' > "$HOME/.paperclip/instances/default/config.json"
  local out; out="$(step_onboard 2>&1)"
  assert_contains "$out" "건너뜀" "설정이 있으면 건너뛴다"
}
t_onboard_command() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  local out; out="$(HC_DRY_RUN=1 step_onboard 2>&1)"
  assert_contains "$out" "onboard --yes --no-install-service" "온보딩 명령"
  assert_contains "$out" "$HOME/.paperclip" "데이터 위치 고정"
}
run_tests t_onboard_skip t_onboard_command
