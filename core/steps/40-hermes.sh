#!/usr/bin/env bash
# 4단계: uv + Python + Hermes Agent.

step_hermes() {
  local h p
  h="${HERMES_VERSION:-$(hc_pin HERMES_VERSION)}"
  p="${PYTHON_VERSION:-$(hc_pin PYTHON_VERSION)}"
  p_install_uv || return 1
  p_install_hermes || return 1
  mf_set HERMES_VERSION "$h"
  mf_set PYTHON_VERSION "$p"
  return 0
}
