#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
. "$HERE/../platform/macos.sh"
. "$HERE/../core/steps/10-preflight.sh"
. "$HERE/../core/steps/20-node.sh"
export HC_NO_COLOR=1

t_records_platform() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  HC_SKIP_NETWORK=1 step_preflight
  assert_eq "macos-$P_ARCH" "$(mf_get PLATFORM)" "플랫폼 기록"
  assert_contains "$(mf_get INSTALLED_AT)" "20" "설치 시각 기록"
}
t_records_existing_hermes() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; mkdir -p "$HOME/.hermes"; p_detect
  HC_SKIP_NETWORK=1 step_preflight
  assert_eq "true" "$(mf_get HERMES_EXISTED)" "기존 Hermes 감지"
}
t_records_no_hermes() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  HC_SKIP_NETWORK=1 step_preflight
  assert_eq "false" "$(mf_get HERMES_EXISTED)" "Hermes 없음"
}
t_node_dry() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  HC_DRY_RUN=1 step_node
  assert_eq "24.20.0" "$(mf_get NODE_VERSION)" "Node 버전 기록"
}
run_tests t_records_platform t_records_existing_hermes t_records_no_hermes t_node_dry
