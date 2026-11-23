#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../platform/common.sh"
export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)" HC_NO_COLOR=1

t_common_defines() {
  local fn
  for fn in p_run p_activate_tools p_version_num p_node_present p_install_node \
            p_uv_present p_install_uv p_hermes_present p_install_hermes \
            p_paperclip_present p_paperclip_env p_install_paperclip \
            p_server_pidfile p_server_running p_server_start_bg p_server_stop_bg; do
    assert_status 0 "$(type -t "$fn" >/dev/null 2>&1; echo $?)" "common 에 $fn 이 있다"
  done
}
t_common_has_no_os_words() {
  assert_status 0 "$([ -f "$HERE/../platform/common.sh" ]; echo $?)" "common.sh 파일이 있다"
  # 주석은 제외한다(문서화를 위해 OS 이름을 언급할 수 있다).
  local out; out="$(sed 's/#.*//' "$HERE/../platform/common.sh" | grep -nE 'launchctl|sw_vers|systemctl|xdg-open|/Library/|darwin' || true)"
  assert_eq "" "$out" "common.sh 코드에 OS 전용 단어가 없다"
}
t_macos_keeps_os_only() {
  local fn
  for fn in p_detect p_node_archive_url p_open_browser p_persist_path p_autostart_install; do
    assert_status 0 "$(bash -c '. '"$HERE"'/../core/lib.sh; . '"$HERE"'/../platform/macos.sh; type -t '"$fn"' >/dev/null 2>&1; echo $?')" "macos 에 $fn 이 있다"
  done
}
run_tests t_common_defines t_common_has_no_os_words t_macos_keeps_os_only
