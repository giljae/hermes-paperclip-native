#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"

# dist 는 macOS 에서 만드는 릴리스 작업이다(ditto 로 zip 을 만들며, 실행 권한 보존이
# zip 명령보다 확실하다). macOS 가 아니면 건너뛴다 — macOS CI 잡이 이 경로를 검증한다.
[ "$(uname -s)" = "Darwin" ] || { printf 'dist 테스트는 macOS 에서만 실행됩니다 (건너뜀)\n'; exit 0; }
ROOT="$(cd "$HERE/.." && pwd)"
DIST="$ROOT/dist"
VER="$(cat "$ROOT/VERSION")"

t_make_dist_runs() {
  (cd "$ROOT" && make dist >/dev/null 2>&1)
  assert_status 0 $? "make dist 가 성공한다"
}
t_macos_zip_exists() {
  assert_status 0 "$([ -f "$DIST/HermesPaperclip-macOS-$VER.zip" ]; echo $?)" "macOS 번들 zip 이 있다"
}
t_generic_zip_exists() {
  assert_status 0 "$([ -f "$DIST/hermes-paperclip-$VER.zip" ]; echo $?)" "범용 zip 이 있다"
}
t_checksums_exists() {
  assert_contains "$(cat "$DIST/checksums.txt" 2>/dev/null)" "HermesPaperclip-macOS-$VER.zip" "체크섬 목록"
}
t_install_command_is_executable() {
  local out; out="$(mktemp -d)"
  ditto -x -k "$DIST/HermesPaperclip-macOS-$VER.zip" "$out" 2>/dev/null
  local f; f="$(find "$out" -name '설치.command' -maxdepth 3 | head -n 1)"
  assert_status 0 "$([ -n "$f" ]; echo $?)" "설치.command 가 zip 안에 있다"
  assert_status 0 "$([ -x "$f" ]; echo $?)" "설치.command 가 실행 권한을 유지한다"
  rm -rf "$out"
}
t_generic_has_core() {
  local out; out="$(mktemp -d)"
  ditto -x -k "$DIST/hermes-paperclip-$VER.zip" "$out" 2>/dev/null
  assert_status 0 "$([ -f "$out/core/run.sh" ]; echo $?)" "범용 zip 루트에 core/run.sh 가 있다"
  rm -rf "$out"
}
t_generic_has_win() {
  local out; out="$(mktemp -d)"
  ditto -x -k "$DIST/hermes-paperclip-$VER.zip" "$out" 2>/dev/null
  assert_status 0 "$([ -f "$out/win/commands.ps1" ]; echo $?)" "범용 zip 루트에 win/commands.ps1 가 있다"
  assert_status 0 "$([ -f "$out/win/bootstrap.ps1" ]; echo $?)" "범용 zip 루트에 win/bootstrap.ps1 가 있다"
  rm -rf "$out"
}
run_tests t_make_dist_runs t_macos_zip_exists t_generic_zip_exists t_checksums_exists t_install_command_is_executable t_generic_has_core t_generic_has_win
