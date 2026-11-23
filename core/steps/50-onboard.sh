#!/usr/bin/env bash
# 5단계: Paperclip 초기 설정(onboard).
#
# onboard --yes 는 설정을 쓰는 동시에 서버를 포그라운드로 띄울 수 있다. 어느 쪽인지에
# 의존하지 않도록, 백그라운드로 돌리고 설정 파일이 생길 때까지 기다린 뒤, 남아 있는
# 프로세스는 정리한다. 서버는 다음 단계의 LaunchAgent 가 소유한다.

step_onboard() {
  local cfg cli log pid i
  cfg="$(p_data_dir)/instances/default/config.json"

  if [ -f "$cfg" ]; then
    ui_skip "초기 설정이 이미 있습니다"
    return 0
  fi

  p_paperclip_env
  cli="$(p_bin_dir)/paperclipai"

  if [ -n "${HC_DRY_RUN:-}" ]; then
    printf 'PAPERCLIP_HOME=%s %s onboard --yes --no-install-service\n' "$(p_data_dir)" "$cli"
    return 0
  fi

  log="$(hc_log_dir)/onboard.log"
  mkdir -p "$(hc_log_dir)" 2>/dev/null || true

  (
    PAPERCLIP_NO_BROWSER=1 "$cli" onboard --yes --no-install-service >"$log" 2>&1
  ) &
  pid=$!

  i=0
  while [ "$i" -lt 300 ]; do
    sleep 2
    [ -f "$cfg" ] && break
    kill -0 "$pid" 2>/dev/null || break
    i=$((i + 1))
  done

  if [ ! -f "$cfg" ]; then
    kill "$pid" 2>/dev/null || true
    hc_die "초기 설정을 만들지 못했습니다. 기록: $log"
  fi

  # onboard 가 포그라운드 서버로 계속 살아 있으면 정리한다.
  # SIGTERM 은 Paperclip 이 지원하는 종료 경로다(임베디드 DB 를 순서대로 닫는다).
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    i=0
    while [ "$i" -lt 20 ]; do
      sleep 1
      kill -0 "$pid" 2>/dev/null || break
      i=$((i + 1))
    done
    kill -9 "$pid" 2>/dev/null || true
  fi

  return 0
}
