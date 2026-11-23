#!/usr/bin/env bash
# 2단계: Node.js 확보.

step_node() {
  local want; want="${NODE_VERSION:-$(hc_pin NODE_VERSION)}"
  p_install_node || return 1
  mf_set NODE_VERSION "$want"
  return 0
}
