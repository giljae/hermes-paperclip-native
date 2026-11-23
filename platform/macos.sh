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


# 우리가 방금 설치한 도구들을 현재 프로세스의 PATH 앞에 붙인다.
# p_persist_path 는 "새 셸"에만 영향을 주므로, 설치 중에 npx/uv/paperclipai 를
# 쓰려면 이 함수가 필요하다. (실제 스모크에서 uv: command not found 로 드러났다.)

# HC_DRY_RUN=1 이면 실행하지 않고 명령만 출력한다(테스트/미리보기용).



# 모든 paperclipai 호출 전에 이걸 부른다. CLI 가 다른 인스턴스를 보는 사고를 막는다.

# --- 자동 시작 (LaunchAgent) --------------------------------------------
#
# Paperclip 자체 `service` 를 쓰지 않는 이유: launchd 는 PATH 를 비워 두므로
# 어댑터가 `hermes` 를 찾지 못한다. 우리 plist 는 PATH 를 명시한다.

p_autostart_label() { printf 'ing.hermes-paperclip.agent'; }

p_autostart_plist() {
  printf '%s/Library/LaunchAgents/%s.plist' "$HOME" "$(p_autostart_label)"
}

p_autostart_render() {
  local tpl path
  tpl="$(hc_root)/platform/launchagent.plist.template"
  [ -f "$tpl" ] || hc_die "자동 시작 템플릿을 찾을 수 없습니다: $tpl"
  path="$(p_bin_dir):$(p_node_dir)/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  sed -e "s|@@LABEL@@|$(p_autostart_label)|g" \
      -e "s|@@PAPERCLIP@@|$(p_bin_dir)/paperclipai|g" \
      -e "s|@@PATH@@|$path|g" \
      -e "s|@@HOME@@|$HOME|g" \
      -e "s|@@DATA_DIR@@|$(p_data_dir)|g" \
      -e "s|@@LOG@@|$(hc_home)/logs/server.log|g" \
      -e "s|@@LOG_ERR@@|$(hc_home)/logs/server.err.log|g" \
      "$tpl"
}

p_autostart_install() {
  [ -n "${HC_SKIP_AUTOSTART:-}" ] && return 0
  local plist; plist="$(p_autostart_plist)"
  mkdir -p "$(dirname "$plist")"
  p_autostart_render > "$plist" || return 1
  p_run launchctl bootout "gui/$UID/$(p_autostart_label)" >/dev/null 2>&1 || true
  p_run launchctl bootstrap "gui/$UID" "$plist" || hc_die "자동 시작 등록에 실패했습니다."
  return 0
}

p_autostart_remove() {
  local plist; plist="$(p_autostart_plist)"
  p_run launchctl bootout "gui/$UID/$(p_autostart_label)" >/dev/null 2>&1 || true
  [ -f "$plist" ] && rm -f "$plist"
  return 0
}

p_autostart_status() {
  local plist; plist="$(p_autostart_plist)"
  if [ ! -f "$plist" ]; then
    printf 'absent'
    return 0
  fi
  if launchctl print "gui/$UID/$(p_autostart_label)" >/dev/null 2>&1; then
    printf 'running'
  else
    printf 'stopped'
  fi
}
