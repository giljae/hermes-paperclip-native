#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
. "$HERE/../core/fetch.sh"
. "$HERE/../platform/macos.sh"
. "$HERE/../core/steps/update.sh"
export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)" HC_NO_COLOR=1
p_detect

t_should_run_yes() { export HC_LATEST_VERSION=0.2.0; mf_set INSTALLER_VERSION 0.1.0; assert_status 0 "$(update_should_run; echo $?)" "새 버전이면 실행"; }
t_should_run_no()  { export HC_LATEST_VERSION=0.1.0; mf_set INSTALLER_VERSION 0.1.0; assert_status 1 "$(update_should_run; echo $?)" "같으면 건너뛴다"; }
t_rollback()       { mf_set INSTALLER_VERSION 0.2.0; update_rollback 0.1.0; assert_eq "0.1.0" "$(mf_get INSTALLER_VERSION)" "롤백이 버전을 되돌린다"; }
run_tests t_should_run_yes t_should_run_no t_rollback
