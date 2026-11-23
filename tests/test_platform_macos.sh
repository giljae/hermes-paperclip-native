#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
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
run_tests t_detect t_paths t_node_url_arm t_node_url_x64 t_url_default t_url_from_cfg \
          t_install_node_skips t_persist_once t_install_node_unsets_other_node
