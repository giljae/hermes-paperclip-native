#!/usr/bin/env bash
# 7단계: 회사와 CEO 에이전트를 만든다.
#
# Paperclip 관례를 따른다: 첫 에이전트는 항상 CEO, timed heartbeat 은 꺼짐,
# 설정 흐름은 예산 상한을 잡지 않는다(예산은 'connect' 단계에서 한 번 제안한다).

HC_COMPANY_NAME="내 AI 회사"
HC_COMPANY_PREFIX="AI"
HC_AGENT_NAME="CEO"

seed_company_payload() {
  cat <<'JSON'
{
  "name": "내 AI 회사",
  "issuePrefix": "AI"
}
JSON
}

seed_agent_payload() {
  cat <<'JSON'
{
  "name": "CEO",
  "role": "ceo",
  "adapterType": "hermes_local",
  "adapterConfig": {
    "persistSession": true,
    "timeoutSec": 1800,
    "quiet": true
  },
  "runtimeConfig": {
    "heartbeat": {
      "enabled": false
    }
  },
  "instructionsBundle": {
    "files": {
      "AGENTS.md": "You are the CEO agent of this Paperclip company. Plan strategy, break it into tasks, and delegate. Keep reports short."
    }
  }
}
JSON
}

# jq 를 쓰지 않는다(macOS 에 항상 있는 게 아니다). 첫 번째 id 를 뽑는다.
seed_first_id() {
  tr -d '\n' | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/'
}

seed_company_id() {
  "$(p_bin_dir)/paperclipai" company list --json 2>/dev/null | seed_first_id
}

seed_agent_exists() {
  local cid="$1"
  "$(p_bin_dir)/paperclipai" agent list -C "$cid" --json 2>/dev/null | grep -q "$HC_AGENT_NAME"
}

step_seed() {
  local cli cid
  p_paperclip_env
  cli="$(p_bin_dir)/paperclipai"

  if [ -n "${HC_DRY_RUN:-}" ]; then
    printf 'PAPERCLIP_HOME=%s %s company create --payload-json <회사>\n' "$(p_data_dir)" "$cli"
    printf 'PAPERCLIP_HOME=%s %s agent create -C <회사 id> --payload-json <CEO>\n' "$(p_data_dir)" "$cli"
    return 0
  fi

  cid="$(seed_company_id)"
  if [ -z "$cid" ]; then
    "$cli" company create --payload-json "$(seed_company_payload)" >>"$(hc_log_dir)/seed.log" 2>&1 || {
      ui_warn "회사를 만들지 못했습니다. 다음에 다시 시도할 수 있습니다."
      return 0
    }
    cid="$(seed_company_id)"
  fi

  if [ -z "$cid" ]; then
    ui_warn "회사 id 를 확인하지 못해 CEO 채용을 건너뜁니다."
    return 0
  fi

  if seed_agent_exists "$cid"; then
    ui_skip "이미 CEO 가 있습니다"
    return 0
  fi

  "$cli" agent create -C "$cid" --payload-json "$(seed_agent_payload)" >>"$(hc_log_dir)/seed.log" 2>&1 || {
    ui_warn "CEO 채용에 실패했습니다. 다음에 다시 시도할 수 있습니다."
    return 0
  }
  return 0
}
