#!/usr/bin/env bash
# Linux 전용. core/ 는 platform/common.sh 와 이 파일의 p_* 만 안다.
# 여기에는 macOS 전용 단어(launchctl, sw_vers, .zprofile)를 쓰지 않는다.

p_detect() {
  P_OS="linux"
  case "$(uname -m)" in
    aarch64|arm64)  P_ARCH="arm64" ;;
    x86_64|amd64)   P_ARCH="x64" ;;
    *)              P_ARCH="$(uname -m)" ;;
  esac
  P_OS_VERSION="$(uname -r)"
  P_DISTRO=""
  if [ -r /etc/os-release ]; then
    P_DISTRO="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"' | head -n 1)"
  fi
}

p_bin_dir()  { printf '%s/.local/bin'  "$HOME"; }
p_node_dir() { printf '%s/.local/node' "$HOME"; }
p_data_dir() { printf '%s/.paperclip'  "$HOME"; }
p_app_dir()  { hc_home; }

# GUI 세션이 있어야 브라우저를 열 수 있다. 서버에서는 없다.
p_has_display() {
  [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]
}

# 이 배포판에서 설치가 가능한지 판정한다. root 거부와 glibc 하한은 중단 사유이고,
# systemd 부재는 경고만 한다(백그라운드 러너로 폴백하므로).
p_require_supported() {
  if [ "$(id -u)" = "0" ]; then
    hc_die "root 로 실행하지 마세요. 설치한 것을 일반 사용자만 쓸 수 있게 됩니다."
  fi

  if command -v ldd >/dev/null 2>&1; then
    local v num
    v="$(ldd --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+$' || true)"
    if [ -n "$v" ]; then
      num="$(printf '%s' "$v" | awk -F. '{printf "%d", $1*100 + $2}')"
      if [ "$num" -lt 235 ]; then
        hc_die "glibc $v 는 너무 오래되었습니다. glibc 2.35 이상(Ubuntu 22.04+ / Debian 12+)이 필요합니다."
      fi
    fi
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    printf '%s\n' "  ! systemd 가 없어 자동 시작을 등록할 수 없습니다. 백그라운드로 실행합니다." >&2
  fi
  return 0
}

p_node_archive_url() {
  local v="$1" arch="${P_ARCH:-x64}"
  printf 'https://nodejs.org/dist/v%s/node-v%s-linux-%s.tar.gz' "$v" "$v" "$arch"
}

# xdg-open 이 없으면(헤드리스) 실패를 반환할 뿐 죽지 않는다. 호출자가 URL 을 출력한다.
p_open_browser() {
  command -v xdg-open >/dev/null 2>&1 || return 1
  xdg-open "$1" >/dev/null 2>&1 &
  return 0
}
