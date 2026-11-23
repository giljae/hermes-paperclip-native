#!/usr/bin/env bash
# 설치 후 확인. 실패해도 설치 전체를 실패시키지 않는다(soft).

step_verify() {
  [ -n "${HC_DRY_RUN:-}" ] && return 0

  if ! "$(p_bin_dir)/paperclipai" doctor >/dev/null 2>&1; then
    ui_warn "Paperclip 자체 점검에서 경고가 있습니다. '상태'를 실행해 확인하세요."
  fi

  if [ ! -x "$(p_bin_dir)/hermes" ]; then
    ui_warn "Hermes를 찾지 못했습니다. 'AI연결'을 다시 실행해 주세요."
  fi

  return 0
}

cmd_verify() { step_verify; return 0; }
