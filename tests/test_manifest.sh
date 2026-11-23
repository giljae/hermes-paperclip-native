#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/manifest.sh"

setup() { export HC_HOME="$(mktemp -d)"; }

t_missing()      { setup; assert_status 0 "$(type -t mf_get >/dev/null 2>&1; echo $?)" "mf_get 이 정의되어 있다"; assert_eq "" "$(mf_get NODE_VERSION)" "없는 키는 빈 문자열"; }
t_set_get()      { setup; mf_set NODE_VERSION 24.20.0; assert_eq "24.20.0" "$(mf_get NODE_VERSION)" "저장 후 조회"; }
t_replace()      { setup; mf_set NODE_VERSION 1.0.0; mf_set NODE_VERSION 2.0.0; assert_eq "2.0.0" "$(mf_get NODE_VERSION)" "같은 키는 교체"; }
t_no_dup()       { setup; mf_set A 1; mf_set A 2; assert_eq "1" "$(grep -c '^A=' "$(mf_path)")" "중복 줄이 생기지 않는다"; }
t_persist()      { setup; mf_set A 1; assert_eq "1" "$(HC_HOME="$HC_HOME" mf_get A)" "새 프로세스에서도 읽힌다"; }
t_space()        { setup; mf_set MSG "안녕 세계"; assert_eq "안녕 세계" "$(mf_get MSG)" "공백 포함 값"; }
t_exists_false() { setup; assert_status 1 "$(mf_exists; echo $?)" "파일이 없으면 mf_exists 는 1"; }
t_exists_true()  { setup; mf_set A 1; assert_status 0 "$(mf_exists; echo $?)" "파일이 있으면 mf_exists 는 0"; }
t_dump()         { setup; mf_set A 1; mf_set B 2; local out; out="$(mf_dump)"; assert_contains "$out" "A=1" "dump 에 A"; assert_contains "$out" "B=2" "dump 에 B"; }
run_tests t_missing t_set_get t_replace t_no_dup t_persist t_space t_exists_false t_exists_true t_dump
