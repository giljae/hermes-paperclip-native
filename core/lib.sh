#!/usr/bin/env bash
# OS 중립 공통 헬퍼: 경로, OS 감지, 로깅, 플랫폼 로딩.
#
# 주의: 이 파일은 core/ui.sh 를 source 하지 않는다. lib 는 ui 보다 먼저 로드되어야
# 하고, 순환 의존을 만들면 어느 쪽도 단독으로 테스트할 수 없다.

hc_root() {
  local src="${BASH_SOURCE[0]}" dir
  dir="$(cd "$(dirname "$src")" && pwd)"
  printf '%s' "$(cd "$dir/.." && pwd)"
}

hc_home() {
  if [ -n "${HC_HOME:-}" ]; then
    printf '%s' "$HC_HOME"
  else
    printf '%s/.hermes-paperclip-native' "${HOME:-/tmp}"
  fi
}

hc_app_root() { printf '%s/app'  "$(hc_home)"; }
hc_log_dir()  { printf '%s/logs' "$(hc_home)"; }
hc_log_file() { printf '%s/install.log' "$(hc_log_dir)"; }

hc_os() {
  case "$(uname -s)" in
    Darwin) printf 'macos' ;;
    Linux)  printf 'linux' ;;
    *)      printf 'windows' ;;
  esac
}

hc_arch() {
  case "$(uname -m)" in
    arm64|aarch64) printf 'arm64' ;;
    x86_64|amd64)  printf 'x64' ;;
    *)             printf '%s' "$(uname -m)" ;;
  esac
}

hc_version() {
  local f; f="$(hc_root)/VERSION"
  [ -f "$f" ] || return 0
  head -n 1 "$f" | tr -d '[:space:]'
}

hc_pin() {
  local key="$1" f; f="$(hc_root)/pins.env"
  [ -f "$f" ] || return 1
  sed -n "s/^${key}=//p" "$f" | head -n 1
}

hc_log() {
  local d; d="$(hc_log_dir)"
  mkdir -p "$d" 2>/dev/null || return 0
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "$(hc_log_file)"
}

hc_die() {
  printf '✗ %s\n' "$*" >&2
  hc_log "실패: $*"
  exit 1
}

hc_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || hc_die "$2"
}

hc_load_platform() {
  local f; f="$(hc_root)/platform/$(hc_os).sh"
  [ -f "$f" ] || hc_die "이 운영체제($(hc_os))는 아직 지원하지 않습니다."
  # shellcheck disable=SC1090
  . "$f"
}
