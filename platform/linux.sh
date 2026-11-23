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

# 마커는 macOS 와 같은 한 줄을 쓴다(중복 검사가 grep -c == 1 로 단순해진다).
# ~/.profile 은 로그인 셸, ~/.bashrc 는 비대화형 셸(`ssh host '명령'`)을 담당하므로
# 둘 다에 넣는다. 한쪽만 넣으면 "설치했는데 명령이 없다"가 된다.
p_persist_path() {
  local marker='# hermes-paperclip: PATH' f
  for f in "$HOME/.profile" "$HOME/.bashrc"; do
    touch "$f" 2>/dev/null || continue
    if grep -qF "$marker" "$f" 2>/dev/null; then
      continue
    fi
    {
      printf '%s\n' "$marker"
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    } >> "$f"
  done
  return 0
}

# --- 자동 시작 (systemd user) -------------------------------------------
#
# PATH 를 유닛에 명시한다. systemd user 유닛의 기본 PATH 는 최소한이라,
# 명시하지 않으면 어댑터가 `hermes` 를 찾지 못한다(macOS launchd 와 같은 이유).
# systemd 를 쓸 수 없는 환경(컨테이너/WSL)에서는 1 을 반환하고 코어가
# 백그라운드 러너로 폴백한다.

p_autostart_label() { printf 'hermes-paperclip'; }

p_autostart_unit() {
  printf '%s/.config/systemd/user/%s.service' "$HOME" "$(p_autostart_label)"
}

p_autostart_available() {
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl --user show-environment >/dev/null 2>&1 || return 1
  return 0
}

p_autostart_render() {
  local tpl path
  tpl="$(hc_root)/platform/hermes-paperclip.service.template"
  [ -f "$tpl" ] || hc_die "자동 시작 템플릿을 찾을 수 없습니다: $tpl"
  path="$(p_bin_dir):$(p_node_dir)/bin:/usr/local/bin:/usr/bin:/bin"
  sed -e "s|@@PAPERCLIP@@|$(p_bin_dir)/paperclipai|g" \
      -e "s|@@PATH@@|$path|g" \
      -e "s|@@HOME@@|$HOME|g" \
      -e "s|@@DATA_DIR@@|$(p_data_dir)|g" \
      -e "s|@@LOG@@|$(hc_home)/logs/server.log|g" \
      -e "s|@@LOG_ERR@@|$(hc_home)/logs/server.err.log|g" \
      "$tpl"
}

p_autostart_install() {
  [ -n "${HC_SKIP_AUTOSTART:-}" ] && return 0
  p_autostart_available || return 1

  local unit; unit="$(p_autostart_unit)"
  mkdir -p "$(dirname "$unit")" || return 1
  p_autostart_render > "$unit" || return 1

  p_run systemctl --user daemon-reload >/dev/null 2>&1 || true
  p_run systemctl --user enable --now "$(p_autostart_label).service" >/dev/null 2>&1 || return 1
  # 로그아웃해도 계속 돌게 한다. 실패해도 설치는 계속한다(경고만).
  p_run loginctl enable-linger "$USER" >/dev/null 2>&1 || true
  return 0
}

p_autostart_remove() {
  local unit; unit="$(p_autostart_unit)"
  if p_autostart_available; then
    p_run systemctl --user disable --now "$(p_autostart_label).service" >/dev/null 2>&1 || true
  fi
  rm -f "$unit"
  if p_autostart_available; then
    p_run systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi
  return 0
}

p_autostart_status() {
  local unit; unit="$(p_autostart_unit)"
  if [ ! -f "$unit" ]; then
    printf 'absent'
    return 0
  fi
  if p_autostart_available && systemctl --user is-active --quiet "$(p_autostart_label).service" 2>/dev/null; then
    printf 'running'
  else
    printf 'stopped'
  fi
}
