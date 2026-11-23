#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
. "$HERE/../core/fetch.sh"
# 현재 플랫폼을 로드한다(OS 하드코딩 금지).
. "$HERE/../core/lib.sh"
hc_load_platform
. "$HERE/../core/steps/30-paperclip.sh"
. "$HERE/../core/steps/40-hermes.sh"
export HC_NO_COLOR=1

t_paperclip_records() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect; HC_DRY_RUN=1 step_paperclip
  assert_eq "2026.1117.0" "$(mf_get PAPERCLIP_VERSION)" "Paperclip 버전 기록"
}
t_hermes_records() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect; HC_DRY_RUN=1 step_hermes
  assert_eq "0.19.0" "$(mf_get HERMES_VERSION)" "Hermes 버전 기록"
  assert_eq "3.13" "$(mf_get PYTHON_VERSION)" "Python 버전 기록"
}
run_tests t_paperclip_records t_hermes_records
