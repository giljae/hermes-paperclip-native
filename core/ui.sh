#!/usr/bin/env bash
# 한국어 사용자 출력.
#
# 계약: 모든 ui_* 는 stdout 으로 출력한다(호출자가 필요하면 리다이렉트한다).
# 색상 여부는 호출 시점의 HC_NO_COLOR / TTY 로 매번 다시 판정한다 — 사용자가
# source 이후에 HC_NO_COLOR 를 설정해도 반영되어야 하기 때문이다.
#
# 박스 폭은 "문자 수" 기준이다(터미널 표시 폭이 아니다). 한글 같은 전각 문자는
# 표시 폭이 2지만 여기서는 1로 센다 — 정렬이 조금 어긋날 뿐 기능에는 영향이 없다.

UI_COLOR=0

ui_init() {
  if [ -n "${HC_NO_COLOR:-}" ] || [ ! -t 1 ]; then
    UI_COLOR=0
  else
    UI_COLOR=1
  fi
}

ui_title() { ui_init; printf '%s\n' "$*"; }
ui_blank() { ui_init; printf '\n'; }

ui_step() {
  ui_init
  printf '[%s/%s] %s\n' "$1" "$2" "$3"
}

ui_ok()   { ui_init; printf '      ✓ %s\n' "$*"; }
ui_skip() { ui_init; printf '      · %s (건너뜀)\n' "$*"; }
ui_warn() { ui_init; printf '      ! %s\n' "$*"; }
ui_fail() { ui_init; printf '      ✗ %s\n' "$*"; }

ui_box() {
  ui_init
  local width=0 line n i bar
  for line in "$@"; do
    n=${#line}
    [ "$n" -gt "$width" ] && width=$n
  done
  bar=""
  i=0
  while [ "$i" -lt $((width + 2)) ]; do
    bar="${bar}─"
    i=$((i + 1))
  done
  printf '╭%s╮\n' "$bar"
  for line in "$@"; do
    printf '│ %s' "$line"
    i=${#line}
    while [ "$i" -lt "$width" ]; do
      printf ' '
      i=$((i + 1))
    done
    printf ' │\n'
  done
  printf '╰%s╯\n' "$bar"
}

# TTY 가 아니면 아무것도 출력하지 않고 즉시 돌아온다(CI 에서 멈추면 안 된다).
ui_pause() {
  ui_init
  if [ -t 0 ]; then
    printf '계속하려면 Enter 키를 누르세요...'
    read -r _ || true
    printf '\n'
  fi
  return 0
}

ui_init
