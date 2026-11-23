#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"

t_home_override() {
  local out; out="$(HC_HOME=/tmp/hc-test hc_home)"
  assert_eq "/tmp/hc-test" "$out" "HC_HOME 이 있으면 그 값을 쓴다"
}
t_home_default() {
  local out; out="$(HOME=/tmp/fakehome HC_HOME= hc_home)"
  assert_eq "/tmp/fakehome/.hermes-paperclip-native" "$out" "기본값은 HOME 아래"
}
t_paths() {
  assert_eq "/tmp/hc-test/logs" "$(HC_HOME=/tmp/hc-test hc_log_dir)" "로그 디렉터리"
  assert_eq "/tmp/hc-test/app"  "$(HC_HOME=/tmp/hc-test hc_app_root)" "app 디렉터리"
}
t_version() {
  local v; v="$(hc_version)"
  case "$v" in
    [0-9]*.[0-9]*.[0-9]*) assert_eq "ok" "ok" "VERSION 파일이 x.y.z 형태다 ($v)" ;;
    *) assert_eq "x.y.z 형태" "$v" "VERSION 파일이 x.y.z 형태다" ;;
  esac
}
t_pin()     { assert_eq "24.20.0" "$(hc_pin NODE_VERSION)" "pins.env 조회"; }
t_arch() {
  local a; a="$(hc_arch)"
  case "$a" in
    arm64|x64) assert_eq "ok" "ok" "아키텍처는 arm64 또는 x64" ;;
    *)         assert_eq "arm64 또는 x64" "$a" "아키텍처는 arm64 또는 x64" ;;
  esac
}
t_space_path() {
  local d; d="$(mktemp -d)/공백 있는 폴더"
  mkdir -p "$d"
  HC_HOME="$d" hc_log "테스트"
  assert_status 0 $? "공백/한글 경로에 로그를 쓸 수 있다"
}
t_log() {
  local d; d="$(mktemp -d)"
  HC_HOME="$d" hc_log "안녕"
  assert_contains "$(cat "$d/logs/install.log")" "안녕" "로그에 메시지가 남는다"
}
run_tests t_home_override t_home_default t_paths t_version t_pin t_arch t_space_path t_log
