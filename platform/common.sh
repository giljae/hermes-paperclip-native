#!/usr/bin/env bash
# OS 중립 플랫폼 함수.
#
# 여기에는 OS 이름이 들어가면 안 된다(launchctl/systemd/xdg-open/darwin 등은 각
# platform/<os>.sh 에 둔다). 설치 순서와 도구 확보 로직은 OS와 무관하기 때문이다.
#
# 이 파일의 함수들은 OS별 함수(p_node_dir, p_node_archive_url, p_bin_dir, p_data_dir,
# p_open_browser ...)를 호출한다 — 정의는 각 platform/<os>.sh 에 있다.

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

  if [ -n "${HC_DRY_RUN:-}" ]; then
    printf '%s → %s\n' "$(p_node_archive_url "$want")" "$(p_node_dir)"
    return 0
  fi

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
  p_activate_tools
  p_node_present
}

p_activate_tools() {
  local bin node
  bin="$(p_bin_dir)"
  node="$(p_node_dir)/bin"
  case ":$PATH:" in
    *":$node:"*) ;;
    *) PATH="$node:$PATH" ;;
  esac
  case ":$PATH:" in
    *":$bin:"*) ;;
    *) PATH="$bin:$PATH" ;;
  esac
  export PATH
}

p_run() {
  if [ -n "${HC_DRY_RUN:-}" ]; then
    printf '%s\n' "$*"
    return 0
  fi
  "$@"
}

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
  p_activate_tools
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

  p_activate_tools
  # uv 의 기본 TLS 스택(webpki 루트)은 시스템 신뢰 저장소를 쓰지 않아, 기업/백신
  # TLS 검사 환경에서 'invalid peer certificate: UnknownIssuer' 로 실패한다(실측).
  # 시스템 신뢰 저장소를 쓰게 한다 — 일반 환경에서도 안전하다.
  export UV_NATIVE_TLS=1
  p_run "$(p_bin_dir)/uv" python install "$py" || hc_die "Python $py 설치에 실패했습니다."
  p_run "$(p_bin_dir)/uv" tool install "hermes-agent==$hermes" || hc_die "Hermes 설치에 실패했습니다."

  [ -n "${HC_DRY_RUN:-}" ] || p_hermes_present
}

p_paperclip_present() { [ -x "$(p_bin_dir)/paperclipai" ]; }

p_paperclip_env() { export PAPERCLIP_HOME="$(p_data_dir)"; }

p_install_paperclip() {
  local v; v="${PAPERCLIP_VERSION:-$(hc_pin PAPERCLIP_VERSION)}"
  if [ -z "${HC_DRY_RUN:-}" ] && p_paperclip_present; then
    return 0
  fi
  p_activate_tools
  p_run npx --yes "paperclipai@$v" install || hc_die "Paperclip 설치에 실패했습니다."
  [ -n "${HC_DRY_RUN:-}" ] || p_paperclip_present
}

p_version_num() {
  printf '%s' "$1" | awk -F. '{printf "%d", $1*10000 + $2*100 + $3}'
}

p_server_pidfile() { printf '%s/server.pid' "$(hc_home)"; }

p_server_running() {
  local pidfile pid
  pidfile="$(p_server_pidfile)"
  [ -f "$pidfile" ] || return 1
  pid="$(cat "$pidfile" 2>/dev/null)"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

p_server_start_bg() {
  p_server_running && return 0
  mkdir -p "$(hc_home)" "$(hc_log_dir)"
  p_paperclip_env
  p_activate_tools
  nohup "$(p_bin_dir)/paperclipai" run >>"$(hc_log_dir)/server.log" 2>&1 &
  printf '%s' "$!" > "$(p_server_pidfile)"
  return 0
}

p_server_stop_bg() {
  local pidfile pid i
  pidfile="$(p_server_pidfile)"
  [ -f "$pidfile" ] || return 0
  pid="$(cat "$pidfile" 2>/dev/null)"
  if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null || true
    i=0
    while [ "$i" -lt 20 ]; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
      i=$((i + 1))
    done
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$pidfile"
  return 0
}

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


p_tail_log() {
  local n="${1:-5}" d f
  d="$(p_data_dir)/instances/default/logs"
  [ -d "$d" ] || return 0
  f="$(ls -t "$d"/*.log 2>/dev/null | head -n 1)"
  [ -n "$f" ] || return 0
  tail -n "$n" "$f"
}

