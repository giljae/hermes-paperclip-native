#!/usr/bin/env bash
# AI 연결: 모델 설정, 연결 확인, 예산 제안.
#
# 모델/프로바이더는 Hermes 에 위임한다(어댑터의 model 을 비워 둔다).
# 가장 쉬운 길은 `hermes setup --portal`(Nous Portal OAuth) — API 키를 만들 필요가 없다.

HC_BUDGET_RECOMMENDED_CENTS=3000

connect_menu() {
  CONNECT_CHOICE="3"
  printf '어떤 방법으로 AI를 연결할까요?\n\n'
  printf '  1) Nous Portal로 간편 로그인 (추천 · API 키 불필요)\n'
  printf '  2) 내 API 키 사용 (Anthropic / OpenAI / OpenRouter)\n'
  printf '  3) 나중에 하기\n\n'

  local ans
  if read -r -p '번호를 입력하고 Enter (1/2/3): ' ans; then
    case "$ans" in
      1|2|3) CONNECT_CHOICE="$ans" ;;
    esac
  fi
  return 0
}

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

connect_verify() {
  [ -n "${HC_DRY_RUN:-}" ] && return 0
  "$(p_bin_dir)/hermes" doctor >/dev/null 2>&1
}

connect_budget_set() {
  local cents="$1" cid cli
  cli="$(p_bin_dir)/paperclipai"
  if [ -n "${HC_DRY_RUN:-}" ]; then
    p_run "$cli" agent update "$HC_AGENT_NAME" --payload-json "{\"budgetMonthlyCents\":$cents}"
  else
    p_paperclip_env
    cid="$(seed_company_id)"
    "$cli" agent update "$HC_AGENT_NAME" -C "$cid" \
      --payload-json "{\"budgetMonthlyCents\":$cents}" >/dev/null 2>&1 || true
  fi
  printf '월 예산을 %s 센트($%s)로 설정했습니다.\n' "$cents" "$((cents / 100))"
  return 0
}

connect_budget_prompt() {
  printf '\n지출 폭주를 막기 위해 월 예산을 걸어둘까요?\n'
  printf 'Paperclip은 CEO에게 월 $30~50을 권장합니다.\n\n'
  printf '  1) 월 $30으로 설정 (권장)\n'
  printf '  2) 직접 입력\n'
  printf '  3) 설정하지 않음\n\n'

  local ans
  if ! read -r ans; then
    ans=3
  fi

  case "$ans" in
    1)
      connect_budget_set "$HC_BUDGET_RECOMMENDED_CENTS"
      ;;
    2)
      local custom
      if read -r -p '월 예산(달러): ' custom && [ -n "$custom" ]; then
        case "$custom" in
          *[!0-9]*) printf '숫자가 아니어서 예산을 설정하지 않았습니다.\n' ;;
          *) connect_budget_set "$((custom * 100))" ;;
        esac
      else
        printf '예산을 설정하지 않았습니다.\n'
      fi
      ;;
    *)
      printf '예산을 설정하지 않았습니다. 나중에 대시보드에서 정할 수 있습니다.\n'
      ;;
  esac
  return 0
}

cmd_connect() {
  connect_menu
  connect_run "$CONNECT_CHOICE"

  if [ "$CONNECT_CHOICE" != "3" ]; then
    if connect_verify; then
      printf '연결을 확인했습니다.\n'
    else
      printf '연결을 확인하지 못했습니다. 다시 실행해 주세요.\n'
    fi
  fi

  connect_budget_prompt
  ui_pause
  return 0
}
