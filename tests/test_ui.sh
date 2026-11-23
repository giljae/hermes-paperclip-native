#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/ui.sh"
export HC_NO_COLOR=1

t_step()  { assert_eq "[1/8] 이 컴퓨터를 확인하는 중..." "$(ui_step 1 8 "이 컴퓨터를 확인하는 중...")" "단계 표시"; }
t_ok()    { assert_eq "      ✓ Node.js v24.20.0" "$(ui_ok "Node.js v24.20.0")" "성공 표시"; }
t_skip()  { assert_eq "      · 이미 설치됨 (건너뜀)" "$(ui_skip "이미 설치됨")" "건너뜀 표시"; }
t_fail()  { assert_eq "      ✗ 실패했습니다" "$(ui_fail "실패했습니다")" "실패 표시"; }
t_box()   { local out; out="$(ui_box "안녕" "세계")"; assert_contains "$out" "│ 안녕 │" "박스 내용"; assert_contains "$out" "╰" "박스 닫힘"; }
t_pause_notty() {
  local out; out="$(printf '' | ui_pause)"; assert_eq "" "$out" "비-TTY에서 멈추지 않는다"
}
t_nocolor() { assert_contains "$(ui_step 1 2 "x")" "[1/2] x" "색상 없는 출력"; assert_eq "0" "$UI_COLOR" "색상 꺼짐"; }
run_tests t_step t_ok t_skip t_fail t_box t_pause_notty t_nocolor
