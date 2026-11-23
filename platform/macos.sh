#!/usr/bin/env bash
# macOS 전용 동작. core/ 는 이 파일의 p_* 함수만 호출한다.
# launchctl / open / sw_vers 같은 단어가 core/ 에 나오면 잘못 짠 것이다.

p_detect() {
  P_OS="macos"
  case "$(uname -m)" in
    arm64)   P_ARCH="arm64" ;;
    x86_64)  P_ARCH="x64" ;;
    *)       P_ARCH="$(uname -m)" ;;
  esac
  P_OS_VERSION="$(sw_vers -productVersion 2>/dev/null || printf 'unknown')"
}

p_bin_dir()  { printf '%s/.local/bin'  "$HOME"; }
p_node_dir() { printf '%s/.local/node' "$HOME"; }
p_data_dir() { printf '%s/.paperclip'  "$HOME"; }
p_app_dir()  { hc_home; }

# macOS 데스크톱에는 항상 GUI 세션이 있다.
p_has_display() { return 0; }

p_node_archive_url() {
  local v="$1" arch="${P_ARCH:-arm64}"
  printf 'https://nodejs.org/dist/v%s/node-v%s-darwin-%s.tar.gz' "$v" "$v" "$arch"
}

# Paperclip 설정에서 실제 포트를 읽는다. 3100 이 점유되면 Paperclip 이 다른 포트를
# 고르므로, 여기서 3100 을 가정하면 사용자는 빈 화면을 본다.
p_server_url() {
  local cfg port
  cfg="$(p_data_dir)/instances/default/config.json"
  port=""
  if [ -f "$cfg" ]; then
    port="$(sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$cfg" | head -n 1)"
  fi
  [ -n "$port" ] || port=3100
  printf 'http://127.0.0.1:%s' "$port"
}

p_open_browser() { open "$1"; }

p_tail_log() {
  local n="${1:-5}" d f
  d="$(p_data_dir)/instances/default/logs"
  [ -d "$d" ] || return 0
  f="$(ls -t "$d"/*.log 2>/dev/null | head -n 1)"
  [ -n "$f" ] || return 0
  tail -n "$n" "$f"
}
