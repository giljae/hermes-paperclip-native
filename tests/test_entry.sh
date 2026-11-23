#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
# 현재 플랫폼을 로드한다(OS 하드코딩 금지).
. "$HERE/../core/lib.sh"
hc_load_platform
export HC_NO_COLOR=1

t_source_dir() {
  export HC_SOURCE_DIR="$HERE/.." HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"
  export HC_SKIP_AUTOSTART=1 HC_SKIP_OPEN=1 HC_DRY_RUN=1
  local out; out="$(bash "$HERE/../entry/bootstrap.sh" status 2>&1)"
  assert_contains "$out" "자동 시작" "로컬 체크아웃에서는 run.sh 로 넘긴다"
}
t_release_plan() {
  export HC_HOME="$(mktemp -d)" HC_LATEST_VERSION=0.1.0
  . "$HERE/../entry/bootstrap.sh"
  local out; out="$(HC_DRY_RUN=1 bootstrap_plan install 2>&1)"
  assert_contains "$out" "hermes-paperclip-0.1.0.zip" "zip 이름"
  assert_contains "$out" "checksums.txt" "체크섬 파일"
}
t_forwards_all_args() {
  export HC_SOURCE_DIR="$HERE/.." HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)" HC_NO_COLOR=1 HC_SKIP_AUTOSTART=1
  local out; out="$(bash "$HERE/../entry/bootstrap.sh" uninstall --yes 2>&1 </dev/null)"
  if printf '%s' "$out" | grep -q '정말 제거할까요'; then
    assert_eq "프롬프트 없음" "프롬프트 나옴" "--yes 가 step_uninstall 까지 전달된다"
  else
    assert_eq "ok" "ok" "--yes 가 step_uninstall 까지 전달된다"
  fi
}
run_tests t_source_dir t_release_plan t_forwards_all_args
