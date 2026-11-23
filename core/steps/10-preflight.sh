#!/usr/bin/env bash
# 1단계: 이 컴퓨터가 설치 가능한지 확인하고, 나중에 필요한 사실을 기록한다.

HC_MIN_MACOS="13.0"
HC_MIN_DISK_GB=3

step_preflight() {
  p_detect

  if [ "$(p_version_num "$P_OS_VERSION")" -lt "$(p_version_num "$HC_MIN_MACOS")" ]; then
    hc_die "이 Mac은 macOS $HC_MIN_MACOS 이상이어야 합니다 (현재: $P_OS_VERSION)."
  fi

  local avail
  avail="$(df -g "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
  [ -n "$avail" ] || avail=0
  if [ "$avail" -lt "$HC_MIN_DISK_GB" ] 2>/dev/null; then
    hc_die "저장 공간이 부족합니다 (여유 ${avail}GB, ${HC_MIN_DISK_GB}GB 필요)."
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
