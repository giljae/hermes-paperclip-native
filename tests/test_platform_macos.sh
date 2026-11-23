#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../platform/common.sh"
. "$HERE/../platform/macos.sh"
export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"

t_detect()       { p_detect; assert_contains "arm64 x64" "$P_ARCH" "아키텍처"; assert_eq "macos" "$P_OS" "OS"; }
t_paths()        { assert_eq "$HOME/.local/bin" "$(p_bin_dir)" "bin"; assert_eq "$HOME/.local/node" "$(p_node_dir)" "node"; assert_eq "$HOME/.paperclip" "$(p_data_dir)" "data"; }
t_node_url_arm() { assert_eq "https://nodejs.org/dist/v24.20.0/node-v24.20.0-darwin-arm64.tar.gz" "$(P_ARCH=arm64 p_node_archive_url 24.20.0)" "arm64 URL"; }
t_node_url_x64() { assert_eq "https://nodejs.org/dist/v24.20.0/node-v24.20.0-darwin-x64.tar.gz"   "$(P_ARCH=x64   p_node_archive_url 24.20.0)" "x64 URL"; }
t_url_default()  { assert_eq "http://127.0.0.1:3100" "$(p_server_url)" "설정이 없으면 3100"; }
t_url_from_cfg() {
  mkdir -p "$HOME/.paperclip/instances/default"
  printf '{"server":{"port":3210}}' > "$HOME/.paperclip/instances/default/config.json"
  assert_eq "http://127.0.0.1:3210" "$(p_server_url)" "설정에 적힌 실제 포트를 읽는다"
}
t_install_node_skips() {
  mkdir -p "$(p_bin_dir)"
  printf '#!/bin/sh\necho v24.20.0\n' > "$(p_bin_dir)/node"; chmod +x "$(p_bin_dir)/node"
  NODE_VERSION=24.20.0
  p_install_node
  assert_status 0 $? "이미 있으면 건너뛴다"
}
t_persist_once() {
  export HOME="$(mktemp -d)"; : > "$HOME/.zprofile"
  p_persist_path; p_persist_path
  assert_eq "1" "$(grep -c 'hermes-paperclip' "$HOME/.zprofile")" "PATH 블록은 한 번만"
  assert_contains "$(cat "$HOME/.zprofile")" '.local/bin' "PATH 내용"
}
t_install_node_unsets_other_node() {
  mkdir -p "$(p_bin_dir)"
  printf '#!/bin/sh\necho v24.20.0\n' > "$(p_bin_dir)/node"; chmod +x "$(p_bin_dir)/node"
  NODE_VERSION=24.20.0
  p_install_node
  assert_status 0 $? "설치 함수가 0 을 반환한다"
  local out; out="$(PATH="$(p_bin_dir):$PATH" command -v node)"
  assert_eq "$(p_bin_dir)/node" "$out" "우리 node가 우선한다"
}
t_uv_present_true() {
  mkdir -p "$(p_bin_dir)"; printf '#!/bin/sh\nexit 0\n' > "$(p_bin_dir)/uv"; chmod +x "$(p_bin_dir)/uv"
  assert_status 0 "$(p_uv_present; echo $?)" "uv 존재 판정"
}
t_uv_skip() {
  mkdir -p "$(p_bin_dir)"; printf '#!/bin/sh\nexit 0\n' > "$(p_bin_dir)/uv"; chmod +x "$(p_bin_dir)/uv"
  p_install_uv; assert_status 0 $? "이미 있으면 건너뛴다"
}
t_hermes_present() {
  mkdir -p "$(p_bin_dir)"; : > "$(p_bin_dir)/hermes"; chmod +x "$(p_bin_dir)/hermes"
  assert_status 0 "$(p_hermes_present; echo $?)" "hermes 존재 판정"
}
t_hermes_pins() {
  local out; out="$(HC_DRY_RUN=1 p_install_hermes)"
  assert_contains "$out" "uv tool install hermes-agent==0.19.0" "Hermes 버전 핀"
  assert_contains "$out" "uv python install 3.13" "Python 버전 핀"
}
t_pc_pins() { local out; out="$(HC_DRY_RUN=1 p_install_paperclip)"; assert_contains "$out" "paperclipai@2026.1117.0 install" "Paperclip 버전 핀"; }
t_pc_env()  { p_paperclip_env; assert_eq "$HOME/.paperclip" "$PAPERCLIP_HOME" "PAPERCLIP_HOME 을 홈 데이터로 고정"; }
t_pc_skip() { mkdir -p "$(p_bin_dir)"; : > "$(p_bin_dir)/paperclipai"; chmod +x "$(p_bin_dir)/paperclipai"; p_install_paperclip; assert_status 0 $? "이미 있으면 건너뛴다"; }
t_plist_render() {
  local out; out="$(p_autostart_render)"
  assert_contains "$out" "<string>$HOME/.local/bin:$HOME/.local/node/bin:" "PATH 를 plist 에 명시"
  assert_contains "$out" "<string>$HOME/.local/bin/paperclipai</string>" "paperclipai 실행"
  assert_contains "$out" "ing.hermes-paperclip.agent" "라벨"
  assert_contains "$out" "$(hc_home)/logs/server.log" "로그 경로"
}
t_plist_no_placeholder() {
  local out; out="$(p_autostart_render)"
  assert_contains "$out" "<plist" "plist 본문이 나온다"
  if printf '%s' "$out" | grep -q '@@'; then assert_eq "no-placeholder" "found" "@@ 치환이 남아 있다"; else assert_eq "ok" "ok" "@@ 치환 완료"; fi
}
t_status_absent() {
  export HOME="$(mktemp -d)"
  assert_eq "absent" "$(p_autostart_status)" "plist 가 없으면 absent"
}
t_activate_tools() {
  local before="$PATH"
  p_activate_tools
  assert_contains "$PATH" "$(p_bin_dir)" "bin 이 PATH 에 들어간다"
  assert_contains "$PATH" "$(p_node_dir)/bin" "node bin 이 PATH 에 들어간다"
  export PATH="$before"
}
t_install_hermes_absolute_uv() {
  local out; out="$(HC_DRY_RUN=1 p_install_hermes)"
  assert_contains "$out" "$(p_bin_dir)/uv python install" "uv 를 절대 경로로 부른다"
}
t_hermes_native_tls() {
  local before="${UV_NATIVE_TLS:-}"
  HC_DRY_RUN=1 p_install_hermes >/dev/null 2>&1
  assert_eq "1" "${UV_NATIVE_TLS:-}" "UV_NATIVE_TLS 를 켠다"
  UV_NATIVE_TLS="$before"
}
t_server_pidfile_lifecycle() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  mkdir -p "$(hc_home)"
  sleep 60 &
  local pid=$!
  printf '%s' "$pid" > "$(p_server_pidfile)"
  assert_status 0 "$(p_server_running; echo $?)" "pid 가 살아 있으면 실행 중"
  p_server_stop_bg
  if kill -0 "$pid" 2>/dev/null; then assert_eq "종료됨" "살아 있음" "중지되어야 한다"; else assert_eq "ok" "ok" "중지됨"; fi
}
run_tests t_detect t_paths t_node_url_arm t_node_url_x64 t_url_default t_url_from_cfg \
          t_install_node_skips t_persist_once t_install_node_unsets_other_node \
          t_uv_present_true t_uv_skip t_hermes_present t_hermes_pins \
          t_pc_pins t_pc_env t_pc_skip \
          t_plist_render t_plist_no_placeholder t_status_absent \
          t_activate_tools t_install_hermes_absolute_uv t_hermes_native_tls \
          t_server_pidfile_lifecycle
