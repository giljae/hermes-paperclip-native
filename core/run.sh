#!/usr/bin/env bash
# 명령 디스패처와 단계 실행기.
#
# core/ 는 platform/ 의 p_* 만 호출한다. launchctl/open/systemd 같은 단어가
# 여기 나오면 잘못 짠 것이다.

# 설치 단계 목록: "번호|함수|라벨|soft"
hc_install_steps() {
  cat <<'LIST'
1|step_preflight|이 컴퓨터를 확인하는 중...
2|step_node|Node.js를 설치하는 중...
3|step_paperclip|Paperclip을 설치하는 중...
4|step_hermes|Hermes를 설치하는 중...
5|step_onboard|초기 설정을 만드는 중...
6|step_autostart|자동 시작을 등록하는 중...
7|step_seed|AI 팀을 만드는 중...
8|step_shortcuts|관리 파일을 만드는 중...
9|step_open|브라우저를 여는 중...
LIST
}

hc_run_step() {
  local n="$1" total="$2" fn="$3" label="$4" soft="${5:-}"
  ui_step "$n" "$total" "$label"
  if "$fn"; then
    ui_ok "$label"
    return 0
  fi
  if [ "$soft" = "soft" ]; then
    ui_warn "$label"
    return 0
  fi
  ui_fail "$label"
  return 1
}

hc_load_steps() {
  local root s
  root="$(hc_root)"
  for s in "$root"/core/steps/*.sh; do
    [ -f "$s" ] || continue
    . "$s"
  done
}

hc_load_core() {
  local root; root="$(hc_root)"
  . "$root/core/ui.sh"
  . "$root/core/manifest.sh"
  . "$root/core/fetch.sh"
  hc_load_platform
  hc_load_steps
}

cmd_install() {
  local total n fn label soft
  # 제어 파일(75-shortcuts)이 이 값으로 앱 디렉토리를 찾는다. 업데이트만 설정하던
  # 것을 신규 설치에서도 기록한다(없으면 app//core/run.sh 로 깨진다).
  mf_set INSTALLER_VERSION "$(hc_version)"
  total="$(hc_install_steps | grep -c '|')"
  hc_install_steps | while IFS='|' read -r n fn label soft; do
    [ -n "$n" ] || continue
    hc_run_step "$n" "$total" "$fn" "$label" "$soft" || return 1
  done
}

hc_usage() {
  printf '사용법: run.sh <명령>\n'
  printf '  install | update | start | stop | status | connect | uninstall | verify\n'
}

hc_dispatch() {
  local cmd="${1:-}"
  case "$cmd" in
    install)   cmd_install ;;
    update)    step_update ;;
    start)     cmd_start ;;
    stop)      cmd_stop ;;
    status)    cmd_status ;;
    connect)   cmd_connect ;;
    uninstall) step_uninstall "${2:-}" ;;
    verify)    cmd_verify ;;
    *)         hc_usage >&2; return 2 ;;
  esac
}

# 직접 실행될 때만 디스패치한다(테스트에서 source 할 때는 아무것도 하지 않는다).
# lib.sh 를 먼저 로드해야 한다 — hc_load_core 자체가 hc_root 를 쓴다.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  _hc_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  . "$_hc_self_dir/lib.sh"
  hc_load_core
  hc_dispatch "$@"
fi
