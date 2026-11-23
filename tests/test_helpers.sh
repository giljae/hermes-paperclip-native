#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$0")/helpers.sh"

t_ok()    { assert_eq "a" "a" "동일한 값은 통과"; }
t_has()   { assert_contains "hello world" "world" "부분 문자열 포함"; }
t_code()  { assert_status 0 0 "0은 0"; }
t_fail_detected() {
  local rc
  ( assert_eq "a" "b" "다른 값은 실패" ) >/dev/null 2>&1 && rc=0 || rc=$?
  assert_status 1 "$rc" "다르면 실패를 보고한다"
}

run_tests t_ok t_has t_code t_fail_detected
