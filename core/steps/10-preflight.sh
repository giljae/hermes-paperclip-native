#!/usr/bin/env bash
# 1단계: 이 컴퓨터가 설치 가능한지 확인하고, 나중에 필요한 사실을 기록한다.

HC_MIN_DISK_GB=3

# 남은 공간을 KB 로 돌려준다.
#
# df -g 는 macOS 전용이라 Linux(GNU df)에서 실패한다 — 그래서 -Pk(POSIX, 1K 블록)를
# 쓴다. ubuntu CI 가 이 버그를 잡았다.
preflight_available_kb() {
  local kb
  kb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
  case "$kb" in
    ''|*[!0-9]*) kb=0 ;;
  esac
  printf '%s' "$kb"
}

step_preflight() {
  p_detect

  # 플랫폼이 자기 지원 조건을 판정한다(macOS 는 최소 OS 버전, Linux 는 root/glibc).
  # 함수를 제공하지 않는 플랫폼도 있으므로 가드를 둔다.
  if command -v p_require_supported >/dev/null 2>&1; then
    p_require_supported
  fi

  local avail_kb
  avail_kb="$(preflight_available_kb)"
  if [ "$avail_kb" -lt $((HC_MIN_DISK_GB * 1048576)) ] 2>/dev/null; then
    hc_die "저장 공간이 부족합니다 (여유 $((avail_kb / 1048576))GB, ${HC_MIN_DISK_GB}GB 필요)."
  fi

  if [ -z "${HC_SKIP_NETWORK:-}" ]; then
    curl -fsS --max-time 10 -o /dev/null https://registry.npmjs.org/ \
      || hc_die "인터넷에 연결할 수 없습니다. 연결을 확인한 뒤 다시 실행해 주세요."
  fi

  mf_set PLATFORM "${P_OS}-${P_ARCH}"
  mf_set DATA_DIR "$(p_data_dir)"
  mf_set INSTALLED_AT "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  if [ -d "$HOME/.hermes" ]; then
    mf_set HERMES_EXISTED true
  else
    mf_set HERMES_EXISTED false
  fi
  return 0
}
