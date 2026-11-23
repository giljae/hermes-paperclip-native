#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
. "$HERE/../platform/macos.sh"
. "$HERE/../core/steps/70-seed.sh"
export HC_NO_COLOR=1

t_agent_payload() {
  local p; p="$(seed_agent_payload)"
  assert_contains "$p" '"name": "CEO"' "이름은 CEO"
  assert_contains "$p" '"role": "ceo"' "역할은 ceo"
  assert_contains "$p" 'hermes_local' "Hermes 어댑터"
  assert_contains "$p" '"enabled": false' "timed heartbeat 꺼짐"
  if printf '%s' "$p" | grep -q 'budgetMonthlyCents'; then assert_eq "no-budget" "found" "예산을 넣으면 안 된다"; else assert_eq "ok" "ok" "예산 미설정"; fi
}
t_company_payload() { assert_contains "$(seed_company_payload)" '내 AI 회사' "회사 기본 이름"; }
run_tests t_agent_payload t_company_payload
