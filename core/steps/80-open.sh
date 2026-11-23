#!/usr/bin/env bash
# 9단계: 대시보드 주소를 알려주고 브라우저를 연다.

step_open() {
  if [ -n "${HC_SKIP_OPEN:-}" ]; then
    ui_skip "브라우저 열기"
    return 0
  fi

  local url; url="$(p_server_url)"
  printf '      %s\n' "$url"

  if ! p_has_display; then
    return 0
  fi

  p_open_browser "$url" >/dev/null 2>&1 \
    || ui_warn "브라우저를 자동으로 열지 못했습니다. 위 주소를 직접 열어 주세요."
  return 0
}
