#!/usr/bin/env bash
# tests/test_*.sh 를 이름순으로 실행한다. 하나라도 실패하면 1로 끝난다.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
failed=0

for t in "$HERE"/test_*.sh; do
  [ -f "$t" ] || continue
  printf '\n=== %s\n' "$(basename "$t")"
  if ! bash "$t"; then
    failed=$((failed + 1))
  fi
done

if [ "$failed" -gt 0 ]; then
  printf '\n실패한 테스트 파일: %s개\n' "$failed" >&2
  exit 1
fi

printf '\n모든 테스트 파일 통과\n'
