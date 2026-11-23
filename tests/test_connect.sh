#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
. "$HERE/../platform/common.sh"
. "$HERE/../platform/macos.sh"
. "$HERE/../core/steps/70-seed.sh"
. "$HERE/../core/steps/connect.sh"
export HC_NO_COLOR=1

t_menu_notty()  { connect_menu >/dev/null <<< ''; assert_eq "3" "$CONNECT_CHOICE" "비TTY 기본값은 3"; }
t_portal_cmd()  { local out; out="$(HC_DRY_RUN=1 connect_run 1)"; assert_contains "$out" "hermes setup --portal" "포털 경로"; }
t_key_cmd()     { local out; out="$(HC_DRY_RUN=1 connect_run 2)"; assert_contains "$out" "hermes setup" "내 키 경로"; }
t_none_silent() { assert_status 0 "$(type -t connect_run >/dev/null 2>&1; echo $?)" "connect_run 이 정의되어 있다"; local out; out="$(HC_DRY_RUN=1 connect_run 3)"; assert_eq "" "$out" "나중에는 아무것도 안 한다"; }
t_budget_skip() { local out; out="$(HC_DRY_RUN=1 connect_budget_prompt <<< '3' 2>&1)"; assert_contains "$out" "설정하지 않" "예산 건너뛰기 안내"; }
t_budget_set()  { local out; out="$(HC_DRY_RUN=1 connect_budget_prompt <<< '1' 2>&1)"; assert_contains "$out" "3000" "권장 30달러 = 3000 센트"; }
run_tests t_menu_notty t_portal_cmd t_key_cmd t_none_silent t_budget_skip t_budget_set
