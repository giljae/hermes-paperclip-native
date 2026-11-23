#!/usr/bin/env bash
# 가짜 HOME 에서 실제 설치 → 멱등 확인 → 업데이트 → 제거까지 수행한다.
#
# 기본은 DRY_RUN(네트워크/디스크를 쓰지 않음)이다. 실제 설치를 검증하려면:
#   HC_SMOKE_REAL=1 bash tests/smoke.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
FAKE="$(mktemp -d)"

cleanup() { rm -rf "$FAKE"; }
trap cleanup EXIT

export HOME="$FAKE/home"
mkdir -p "$HOME"
export HC_HOME="$HOME/.hermes-paperclip-native"
export HC_SOURCE_DIR="$ROOT"
export HC_SKIP_AUTOSTART=1
export HC_SKIP_OPEN=1
export HC_NO_COLOR=1
export PAPERCLIP_HOME="$HOME/.paperclip"

if [ -z "${HC_SMOKE_REAL:-}" ]; then
  export HC_DRY_RUN=1
  MODE="DRY_RUN"
else
  MODE="REAL"
fi

fail() { printf '\nSMOKE FAIL: %s\n' "$1" >&2; exit 1; }
step() { printf '\n=== %s\n' "$1"; }

printf 'SMOKE (%s) — 가짜 홈: %s\n' "$MODE" "$HOME"

step "1) 설치"
bash "$ROOT/entry/bootstrap.sh" install || fail "설치가 실패했다"

if [ -z "${HC_SMOKE_REAL:-}" ]; then
  printf '\nSMOKE OK (DRY_RUN — 실제 설치 경로는 검증되지 않았다)\n'
  exit 0
fi

step "2) 두 번째 설치가 멱등한가"
out="$(bash "$ROOT/entry/bootstrap.sh" install 2>&1)" || fail "두 번째 설치가 실패했다"
printf '%s' "$out" | grep -q '건너뜀' || fail "두 번째 설치가 단계를 건너뛰지 않았다"

step "3) 업데이트"
HC_LATEST_VERSION=0.0.1 bash "$ROOT/entry/bootstrap.sh" update >/dev/null 2>&1 || fail "업데이트가 실패했다"

step "4) 제거"
bash "$ROOT/entry/bootstrap.sh" uninstall --yes >/dev/null 2>&1 || fail "제거가 실패했다"
[ -d "$PAPERCLIP_HOME" ] && fail "제거 후에도 Paperclip 데이터가 남아 있다"
[ -d "$HC_HOME" ] && fail "제거 후에도 설치 상태가 남아 있다"

printf '\nSMOKE OK\n'
