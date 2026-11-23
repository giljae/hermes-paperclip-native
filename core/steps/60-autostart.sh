#!/usr/bin/env bash
# 6단계: 자동 시작 등록 + 서버가 응답할 때까지 기다리기.
# 그리고 start/stop/status 명령.

# 서버가 응답할 때까지 기다린다. 첫 부팅은 임베디드 Postgres 초기화와 마이그레이션
# 때문에 오래 걸린다(실측: 60초로는 부족했다). 기본 5분.
HC_HEALTH_WAIT_ITERATIONS=150

step_wait_for_health() {
  [ -n "${HC_DRY_RUN:-}" ] && return 0
  local url i limit
  limit="${HC_HEALTH_WAIT_ITERATIONS:-150}"
  url="$(p_server_url)"
  i=0
  while [ "$i" -lt "$limit" ]; do
    if curl -fsS --max-time 3 "$url/api/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    i=$((i + 1))
  done
  ui_warn "서버가 아직 응답하지 않습니다. 잠시 뒤 브라우저를 새로 고쳐 보세요."
  return 0
}

step_autostart() {
  if [ -n "${HC_SKIP_AUTOSTART:-}" ]; then
    ui_skip "자동 시작"
    # 자동 시작을 등록하지 않아도 서버는 떠 있어야 다음 단계가 동작한다.
    [ -n "${HC_DRY_RUN:-}" ] || p_server_start_bg
    step_wait_for_health
    return 0
  fi

  if ! p_autostart_install; then
    ui_warn "자동 시작을 등록하지 못했습니다. 대신 백그라운드로 실행합니다."
    [ -n "${HC_DRY_RUN:-}" ] || p_server_start_bg
  fi

  step_wait_for_health
  return 0
}

cmd_start() {
  if [ -n "${HC_SKIP_AUTOSTART:-}" ]; then
    printf '자동 시작이 미설치 상태입니다.\n'
    return 0
  fi
  if p_autostart_install; then
    printf '시작했습니다.\n'
  else
    printf '시작하지 못했습니다.\n'
  fi
  return 0
}

cmd_stop() {
  local st; st="$(p_autostart_status)"
  if [ "$st" = "absent" ]; then
    printf '자동 시작이 미설치 상태입니다.\n'
    return 0
  fi
  p_autostart_remove
  p_server_stop_bg
  printf '중지했습니다.\n'
  return 0
}

cmd_status() {
  local st url
  st="$(p_autostart_status)"
  case "$st" in
    running) printf '실행 중입니다.\n' ;;
    stopped) printf '자동 시작은 등록되어 있지만 지금은 실행 중이 아닙니다.\n' ;;
    *)       printf '자동 시작이 미설치 상태입니다.\n' ;;
  esac
  url="$(p_server_url)"
  printf '주소: %s\n' "$url"
  printf 'Node.js: %s\n' "$(mf_get NODE_VERSION)"
  printf 'Paperclip: %s\n' "$(mf_get PAPERCLIP_VERSION)"
  printf 'Hermes: %s\n' "$(mf_get HERMES_VERSION)"
  return 0
}
