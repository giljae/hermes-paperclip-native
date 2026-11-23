#!/usr/bin/env bash
# 제거. 사용자가 설치 전부터 쓰던 Hermes 설정은 절대 건드리지 않는다.

uninstall_plan() {
  cat <<'PLAN'
다음이 지워집니다:

  - 자동 시작 등록 (로그인해도 자동으로 켜지지 않게)
  - Paperclip 과 데이터 폴더 (~/.paperclip — 작업 내역과 대화 기록)
  - Hermes Agent
  - Node.js (~/.local/node)
  - 설치 상태와 로그 (~/.hermes-paperclip-native)
  - 관리용 파일 (~/HermesPaperclip)
PLAN
}

step_uninstall() {
  local yes=0 hermes_existed bin
  [ "${1:-}" = "--yes" ] && yes=1

  # 삭제 전에 먼저 읽는다. 아래에서 hc_home 을 지우면 매니페스트가 사라진다.
  hermes_existed="$(mf_get HERMES_EXISTED)"
  bin="$(p_bin_dir)"

  uninstall_plan

  if [ "$yes" = "0" ]; then
    local ans
    printf '\n정말 제거할까요? (y/N): '
    read -r ans || ans=""
    case "$ans" in
      y|Y|yes|YES) ;;
      *) printf '취소했습니다.\n'; return 0 ;;
    esac
  fi

  [ -n "${HC_SKIP_AUTOSTART:-}" ] || p_autostart_remove

  if [ -x "$bin/paperclipai" ]; then
    "$bin/paperclipai" uninstall >/dev/null 2>&1 || true
  fi
  rm -f "$bin/paperclipai"

  if [ -x "$bin/uv" ]; then
    "$bin/uv" tool uninstall hermes-agent >/dev/null 2>&1 || true
  fi

  rm -f "$bin/node" "$bin/npm" "$bin/npx"
  rm -rf "$(p_node_dir)"
  rm -rf "$(p_data_dir)"
  rm -rf "$(hc_home)"
  rm -rf "$(shortcut_dir)"

  if [ "$hermes_existed" = "true" ]; then
    printf '원래 있던 Hermes 설정(~/.hermes)은 그대로 두었습니다.\n'
  else
    rm -rf "$HOME/.hermes"
  fi

  return 0
}
