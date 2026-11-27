#!/usr/bin/env bash
# AI 연결: Hermes 웹 대시보드(설정 화면)를 연다.
#
# 모델/프로바이더는 Hermes 에 위임한다(어댑터의 model 을 비워 둔다). 일반 사용자가
# 터미널 위저드 대신 설정 화면(UI)에서 연결하도록, Hermes 대시보드의
# /models·/config(API 키) 화면을 브라우저로 연다. 대시보드를 못 띄우면 터미널
# 위저드로 폴백한다.

# 폴백용 터미널 위저드. 1=Nous Portal, 2=내 API 키.
connect_run() {
  local choice="$1" hermes
  hermes="$(p_bin_dir)/hermes"
  case "$choice" in
    1) p_run "$hermes" setup --portal ;;
    2) p_run "$hermes" setup ;;
    *) : ;;
  esac
  return 0
}

cmd_connect() {
  local url
  if p_hermes_dashboard_start; then
    url="$(p_hermes_dashboard_url)"
    printf 'AI 연결 화면: %s\n' "$url"
    if [ -z "${HC_SKIP_OPEN:-}" ] && p_has_display; then
      p_open_browser "$url" || ui_warn "브라우저를 자동으로 열지 못했습니다. 위 주소를 직접 열어 주세요."
    fi
    ui_pause
    return 0
  fi
  ui_warn "AI 연결 화면을 열지 못했습니다."
  # 대화형 위저드(hermes setup)는 TTY 가 아니면 입력을 기다리며 멈출 수 있다. 그래서
  # DRY_RUN(명령만 출력) 이거나 TTY 일 때만 실행하고, 아니면 건너뛴다.
  if [ -n "${HC_DRY_RUN:-}" ] || [ -t 0 ]; then
    printf '터미널 설정으로 진행합니다.\n'
    connect_run 1 || true
  else
    printf '대화형 터미널이 아니라 자동 설정을 건너뜁니다. 대화형 터미널에서 AI연결을 다시 실행해 주세요.\n'
  fi
  ui_pause
  return 0
}
