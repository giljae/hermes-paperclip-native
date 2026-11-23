#!/usr/bin/env bash
# 3단계: Paperclip CLI(managed install).

step_paperclip() {
  local v; v="${PAPERCLIP_VERSION:-$(hc_pin PAPERCLIP_VERSION)}"
  p_install_paperclip || return 1
  mf_set PAPERCLIP_VERSION "$v"
  return 0
}
