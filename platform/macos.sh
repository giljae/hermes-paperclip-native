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

# --- Node ---------------------------------------------------------------

p_node_present() {
  local bin want
  bin="$(p_bin_dir)/node"
  want="${NODE_VERSION:-$(hc_pin NODE_VERSION)}"
  [ -x "$bin" ] || return 1
  [ -n "$want" ] || return 0
  [ "$("$bin" -v 2>/dev/null)" = "v$want" ]
}

p_install_node() {
  local want bin node url tmp inner f
  want="${NODE_VERSION:-$(hc_pin NODE_VERSION)}"
  p_node_present && return 0

  if [ -n "${HC_SKIP_NETWORK:-}" ]; then
    hc_die "네트워크를 건너뛰도록 설정되어 있어 Node.js를 설치할 수 없습니다."
  fi

  bin="$(p_bin_dir)"
  node="$(p_node_dir)"
  mkdir -p "$bin" "$node"
  url="$(p_node_archive_url "$want")"
  tmp="$(mktemp -d)"

  ft_download "$url" "$tmp/node.tar.gz" || hc_die "Node.js 다운로드에 실패했습니다. 인터넷 연결을 확인해 주세요."
  ft_extract "$tmp/node.tar.gz" "$node" || hc_die "Node.js 압축을 푸는 데 실패했습니다."

  # tarball 은 node-v<ver>-darwin-<arch>/ 아래에 풀린다.
  inner="$(find "$node" -maxdepth 1 -type d -name 'node-v*' 2>/dev/null | head -n 1)"
  [ -n "$inner" ] || hc_die "Node.js 압축 구조를 이해할 수 없습니다."
  for f in node npm npx; do
    [ -e "$inner/bin/$f" ] && ln -sf "$inner/bin/$f" "$bin/$f"
  done
  rm -rf "$tmp"
  p_node_present
}

# 마커는 한 줄이다. 이 줄이 'hermes-paperclip' 문자열을 한 번만 만들기 때문에
# 중복 검사가 grep -c == 1 로 단순해진다.
p_persist_path() {
  local profile="$HOME/.zprofile" marker='# hermes-paperclip: PATH'
  touch "$profile" 2>/dev/null || return 1
  if grep -qF "$marker" "$profile" 2>/dev/null; then
    return 0
  fi
  {
    printf '%s\n' "$marker"
    printf 'export PATH="$HOME/.local/bin:$PATH"\n'
  } >> "$profile"
}

# --- 실행 헬퍼 -----------------------------------------------------------

# HC_DRY_RUN=1 이면 실행하지 않고 명령만 출력한다(테스트/미리보기용).
p_run() {
  if [ -n "${HC_DRY_RUN:-}" ]; then
    printf '%s\n' "$*"
    return 0
  fi
  "$@"
}

# --- uv / Hermes --------------------------------------------------------

p_uv_present() { [ -x "$(p_bin_dir)/uv" ]; }

p_install_uv() {
  local tmp
  p_uv_present && return 0
  if [ -n "${HC_DRY_RUN:-}" ]; then
    printf '%s\n' "uv 설치 (astral.sh)"
    return 0
  fi
  tmp="$(mktemp -d)"
  ft_download "https://astral.sh/uv/install.sh" "$tmp/uv-install.sh" \
    || hc_die "uv 설치 스크립트를 받지 못했습니다. 인터넷 연결을 확인해 주세요."
  UV_INSTALL_DIR="$(p_bin_dir)" sh "$tmp/uv-install.sh" >/dev/null 2>&1 \
    || hc_die "uv 설치에 실패했습니다."
  rm -rf "$tmp"
  p_uv_present
}

p_hermes_present() { [ -x "$(p_bin_dir)/hermes" ]; }

p_install_hermes() {
  local py hermes
  py="${PYTHON_VERSION:-$(hc_pin PYTHON_VERSION)}"
  hermes="${HERMES_VERSION:-$(hc_pin HERMES_VERSION)}"

  # DRY_RUN 에서는 이미 설치돼 있어도 계획을 보여준다(사람이 미리 확인할 수 있게).
  if [ -z "${HC_DRY_RUN:-}" ] && p_hermes_present; then
    return 0
  fi

  p_run uv python install "$py" || hc_die "Python $py 설치에 실패했습니다."
  p_run uv tool install "hermes-agent==$hermes" || hc_die "Hermes 설치에 실패했습니다."

  [ -n "${HC_DRY_RUN:-}" ] || p_hermes_present
}

# --- Paperclip ----------------------------------------------------------

p_paperclip_present() { [ -x "$(p_bin_dir)/paperclipai" ]; }

# 모든 paperclipai 호출 전에 이걸 부른다. CLI 가 다른 인스턴스를 보는 사고를 막는다.
p_paperclip_env() { export PAPERCLIP_HOME="$(p_data_dir)"; }

p_install_paperclip() {
  local v; v="${PAPERCLIP_VERSION:-$(hc_pin PAPERCLIP_VERSION)}"
  if [ -z "${HC_DRY_RUN:-}" ] && p_paperclip_present; then
    return 0
  fi
  p_run npx --yes "paperclipai@$v" install || hc_die "Paperclip 설치에 실패했습니다."
  [ -n "${HC_DRY_RUN:-}" ] || p_paperclip_present
}
