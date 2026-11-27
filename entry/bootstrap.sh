#!/usr/bin/env bash
# 진입점: 이미 있는 설치를 실행하거나, 릴리스에서 내려받아 실행한다.
#
# 세 가지 경우를 처리한다.
#   1) HC_SOURCE_DIR 가 있으면 그 체크아웃의 core/run.sh 를 쓴다(개발/테스트).
#   2) 자기 옆에 core/run.sh 가 있으면 그것을 쓴다(배포 zip 을 푼 경우).
#   3) 아니면 릴리스에서 zip 을 받아 검증한 뒤 실행한다.
set -uo pipefail

# `curl … | bash` 로 실행하면 BASH_SOURCE 가 없다(BASH_SOURCE[0] 를 그냥 쓰면
# set -u 에서 'unbound variable' 로 죽는다 — 문서화된 주 설치 경로).
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  HC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  HC_SELF_DIR=""
fi
HC_HOME="${HC_HOME:-$HOME/.hermes-paperclip-native}"
HC_RELEASE_BASE="${HC_RELEASE_BASE:-https://github.com/giljae/hermes-paperclip-native/releases/latest/download}"

bootstrap_version() {
  if [ -n "${HC_LATEST_VERSION:-}" ]; then
    printf '%s' "$HC_LATEST_VERSION"
    return 0
  fi
  curl -fsSL --max-time 20 "$HC_RELEASE_BASE/VERSION" 2>/dev/null | tr -d '[:space:]'
}

bootstrap_plan() {
  local cmd="${1:-install}" v
  v="$(bootstrap_version)"
  [ -n "$v" ] || v="unknown"
  printf '내려받을 파일: hermes-paperclip-%s.zip\n' "$v"
  printf '검증: checksums.txt (sha256)\n'
  printf '설치 위치: %s/app/%s\n' "$HC_HOME" "$v"
  printf '실행: %s/app/%s/core/run.sh %s\n' "$HC_HOME" "$v" "$cmd"
}

bootstrap_download() {
  local v="$1" appdir="$2" tmp zip expected
  tmp="$(mktemp -d)" || return 1
  zip="hermes-paperclip-$v.zip"

  curl -fsSL --max-time 600 -o "$tmp/$zip" "$HC_RELEASE_BASE/$zip" || {
    printf '내려받기에 실패했습니다. 인터넷 연결을 확인해 주세요.\n' >&2
    rm -rf "$tmp"; return 1
  }
  curl -fsSL --max-time 60 -o "$tmp/checksums.txt" "$HC_RELEASE_BASE/checksums.txt" 2>/dev/null || true

  if [ -f "$tmp/checksums.txt" ]; then
    expected="$(grep " $zip\$" "$tmp/checksums.txt" | awk '{print $1}' | head -n 1)"
    if [ -n "$expected" ]; then
      if [ "$(shasum -a 256 "$tmp/$zip" | awk '{print $1}')" != "$expected" ]; then
        printf '내려받은 파일이 손상되었습니다(체크섬 불일치).\n' >&2
        rm -rf "$tmp"; return 1
      fi
    fi
  fi

  mkdir -p "$appdir" || { rm -rf "$tmp"; return 1; }
  unzip -q -o "$tmp/$zip" -d "$appdir" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  return 0
}

bootstrap_main() {
  local cmd="${1:-install}" v appdir

  if [ -n "${HC_SOURCE_DIR:-}" ] && [ -f "$HC_SOURCE_DIR/core/run.sh" ]; then
    exec bash "$HC_SOURCE_DIR/core/run.sh" "$@"
  fi

  if [ -f "$HC_SELF_DIR/core/run.sh" ]; then
    exec bash "$HC_SELF_DIR/core/run.sh" "$@"
  fi

  if [ -n "${HC_DRY_RUN:-}" ]; then
    bootstrap_plan "$cmd"
    return 0
  fi

  v="$(bootstrap_version)"
  if [ -z "$v" ]; then
    printf '최신 버전을 확인하지 못했습니다. 인터넷 연결을 확인해 주세요.\n' >&2
    return 1
  fi

  appdir="$HC_HOME/app/$v"
  if [ ! -f "$appdir/core/run.sh" ]; then
    bootstrap_download "$v" "$appdir" || return 1
  fi

  exec bash "$appdir/core/run.sh" "$@"
}

if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  bootstrap_main "$@"
fi
