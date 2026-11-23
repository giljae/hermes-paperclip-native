#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/fetch.sh"
export HC_HOME="$(mktemp -d)"

t_sha() {
  local f; f="$(mktemp)"; printf 'hello' > "$f"
  assert_eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" "$(ft_sha256 "$f")" "sha256 계산"
}
t_verify_ok()  { local f; f="$(mktemp)"; printf 'hello' > "$f"; assert_status 0 "$(ft_verify "$f" "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"; echo $?)" "올바른 해시 통과"; }
t_verify_bad() { local f; f="$(mktemp)"; printf 'hello' > "$f"; assert_status 1 "$(ft_verify "$f" "deadbeef"; echo $?)" "틀린 해시 거부"; }
t_extract_zip() {
  local d; d="$(mktemp -d)"; printf 'x' > "$d/a.txt"; (cd "$d" && zip -q out.zip a.txt)
  local o; o="$(mktemp -d)"; ft_extract "$d/out.zip" "$o"
  assert_status 0 $? "zip 해제"
  assert_status 0 "$([ -f "$o/a.txt" ]; echo $?)" "해제된 파일 존재"
}
t_download_missing() { assert_status 1 "$(ft_download "https://example.invalid/nope" "$(mktemp -d)/f" >/dev/null 2>&1; echo $?)" "잘못된 URL은 실패"; }
run_tests t_sha t_verify_ok t_verify_bad t_extract_zip t_download_missing
