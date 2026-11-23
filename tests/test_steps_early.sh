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
t_preflight_without_require() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  unset -f p_require_supported 2>/dev/null || true
  HC_SKIP_NETWORK=1 step_preflight
  assert_status 0 $? "플랫폼 지원 판정이 없어도 사전 점검은 동작한다"
}
t_preflight_calls_require() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  p_require_supported() { printf 'CALLED'; return 0; }
  local out; out="$(HC_SKIP_NETWORK=1 step_preflight 2>&1)" || true
  assert_contains "$out" "CALLED" "지원 판정이 있으면 호출한다"
}
t_step_node_persists_path() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  p_install_node() { return 0; }
  p_persist_path() { printf 'PERSISTED'; return 0; }
  local out; out="$(HC_DRY_RUN=1 step_node 2>&1)" || true
  assert_contains "$out" "PERSISTED" "step_node 가 PATH 등록을 호출한다"
}
t_disk_parse() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  local kb; kb="$(preflight_available_kb)"
  assert_status 0 "$([ -n "$kb" ] && [ "$kb" -gt 0 ]; echo $?)" "여유 공간을 KB 로 읽는다"
}
run_tests t_disk_parse t_step_node_persists_path t_records_platform t_records_existing_hermes t_records_no_hermes t_node_dry \
          t_preflight_without_require t_preflight_calls_require
