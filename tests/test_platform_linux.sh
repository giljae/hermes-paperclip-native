#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../platform/common.sh"
. "$HERE/../platform/linux.sh"
export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)" HC_NO_COLOR=1

t_detect() { p_detect; assert_eq "linux" "$P_OS" "OS"; }
t_arch() {
  p_detect
  case "$P_ARCH" in
    arm64|x64) assert_eq "ok" "ok" "아키텍처는 arm64 또는 x64" ;;
    *)         assert_eq "arm64 또는 x64" "$P_ARCH" "아키텍처는 arm64 또는 x64" ;;
  esac
}
t_paths()          { assert_eq "$HOME/.local/bin" "$(p_bin_dir)" "bin"; assert_eq "$HOME/.paperclip" "$(p_data_dir)" "data"; }
t_node_url_x64()   { assert_eq "https://nodejs.org/dist/v24.20.0/node-v24.20.0-linux-x64.tar.gz"   "$(P_ARCH=x64   p_node_archive_url 24.20.0)" "x64 URL"; }
t_node_url_arm64() { assert_eq "https://nodejs.org/dist/v24.20.0/node-v24.20.0-linux-arm64.tar.gz" "$(P_ARCH=arm64 p_node_archive_url 24.20.0)" "arm64 URL"; }
t_url_default()    { assert_eq "http://127.0.0.1:3100" "$(p_server_url)" "기본 포트"; }
t_headless()       { DISPLAY= WAYLAND_DISPLAY= p_has_display; assert_status 1 $? "DISPLAY 가 없으면 헤드리스"; }
t_display()        { DISPLAY=:0 p_has_display; assert_status 0 $? "DISPLAY 가 있으면 GUI"; }
t_open_no_xdg()    { PATH="/nonexistent" p_open_browser "http://x" >/dev/null 2>&1; assert_status 1 $? "xdg-open 이 없으면 실패를 반환한다(죽지 않는다)"; }
t_require_ok_on_mac() { p_require_supported >/dev/null 2>&1; assert_status 0 $? "현재 사용자로는 통과한다(root 아님)"; }
t_persist_profile() {
  export HOME="$(mktemp -d)"; : > "$HOME/.bashrc"; : > "$HOME/.profile"
  p_persist_path; p_persist_path
  assert_eq "1" "$(grep -c 'hermes-paperclip' "$HOME/.profile")" "profile 에 한 번만"
  assert_contains "$(cat "$HOME/.bashrc")" '.local/bin' "bashrc 에도 넣는다(비대화형 셸)"
}
t_persist_idempotent() {
  export HOME="$(mktemp -d)"; : > "$HOME/.profile"; : > "$HOME/.bashrc"
  p_persist_path; p_persist_path; p_persist_path
  assert_eq "1" "$(grep -c 'hermes-paperclip' "$HOME/.profile")" "여러 번 실행해도 한 번만"
  assert_eq "1" "$(grep -c 'hermes-paperclip' "$HOME/.bashrc")" "bashrc 도 한 번만"
}
run_tests t_detect t_arch t_paths t_node_url_x64 t_node_url_arm64 t_url_default t_headless t_display t_open_no_xdg t_require_ok_on_mac \
          t_persist_profile t_persist_idempotent
