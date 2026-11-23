#!/usr/bin/env bash
# 테스트 헬퍼.
#
# 계약:
#   - assert_* 는 성공하면 0, 실패하면 1을 반환한다.
#   - 실패하면 "✗ <label>" 과 expected/actual 을 출력하고 TESTS_FAILED 를 올린다.
#   - 모든 단언은 TESTS_RUN 을 올린다.
#   - run_tests 는 각 테스트 함수를 ( ) 서브셸에서 실행한다. 서브셸의 종료 상태가
#     그 테스트의 성패다(테스트 도중 단언이 하나라도 실패하면 서브셸이 1로 끝난다).
#     카운터는 서브셸마다 독립이므로 부모의 카운터는 서브셸 종료 상태로만 집계된다.

TESTS_RUN=0
TESTS_FAILED=0

_assert_fail() {
  # $1 label, $2 expected, $3 actual
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '✗ %s\n' "$1" >&2
  printf '  expected: %s\n' "$2" >&2
  printf '  actual:   %s\n' "$3" >&2
}

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" = "$actual" ]; then
    printf '✓ %s\n' "$label"
    return 0
  fi
  _assert_fail "$label" "$expected" "$actual"
  return 1
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  case "$haystack" in
    *"$needle"*)
      printf '✓ %s\n' "$label"
      return 0
      ;;
  esac
  _assert_fail "$label" "다음을 포함: $needle" "$haystack"
  return 1
}

assert_status() {
  local expected="$1" actual="$2" label="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" = "$actual" ]; then
    printf '✓ %s\n' "$label"
    return 0
  fi
  _assert_fail "$label" "종료 상태 $expected" "종료 상태 $actual"
  return 1
}

run_tests() {
  local fn rc pass=0 fail=0
  for fn in "$@"; do
    (
      "$fn"
      rc=$?
      if [ "$rc" -ne 0 ] || [ "${TESTS_FAILED:-0}" -gt 0 ]; then
        exit 1
      fi
      exit 0
    )
    rc=$?
    if [ "$rc" -eq 0 ]; then
      pass=$((pass + 1))
    else
      fail=$((fail + 1))
      printf '테스트 실패: %s\n' "$fn" >&2
    fi
  done
  printf 'pass=%s fail=%s\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
}
