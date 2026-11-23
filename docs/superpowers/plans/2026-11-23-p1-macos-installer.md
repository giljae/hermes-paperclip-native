# P1: macOS 설치기 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 터미널에 익숙하지 않은 macOS 사용자가 `설치.command`를 더블클릭(또는 한 줄 명령)하면 Node·Paperclip·Hermes를 무sudo로 설치하고, 자동 시작을 등록하고, `hermes_local` CEO 에이전트가 있는 대시보드를 브라우저에 띄운다.

**Architecture:** 한국어 UX와 단계 오케스트레이션을 담은 OS 중립 `core/`와, macOS 전용 동작만 담은 `platform/macos.sh`를 분리한다. `core/`는 `platform/`이 제공하는 `p_*` 함수만 호출하며, 그 밖의 OS 의존 코드(launchctl, open, uname 결과 분기)를 포함하지 않는다. 모든 상태는 `~/.hermes-paperclip-native/`에 모으고, 모든 설치는 사용자 홈 안에서 끝나 관리자 권한을 요구하지 않는다.

**Tech Stack:** Bash 3.2 호환 셸(macOS 기본), launchd LaunchAgent, curl/tar/unzip/shasum, Node.js 24.20.0(포터블 tarball), uv + Python 3.13, `paperclipai` CLI, `hermes-agent` 0.19.0

**Spec:** `docs/superpowers/specs/2026-11-23-hermes-paperclip-cross-platform-installer-design.md`

## Global Constraints

- **관리자 권한(sudo) 금지.** 어떤 단계도 `sudo`를 호출하지 않는다. 시스템 디렉터리(`/usr/local/bin`, `/Library`)에 쓰지 않는다.
- **Bash 3.2 호환.** macOS 기본 bash에서 돌아야 한다. 연관 배열(`declare -A`), `mapfile`, `${var^^}`, `[[ -v ]]`를 쓰지 않는다. shebang은 `#!/usr/bin/env bash`.
- **모든 사용자 노출 문구는 한국어.** 영어 스택트레이스를 그대로 보여주지 않는다.
- **경로는 항상 따옴표로 감싼다.** 사용자명·경로에 공백이나 한글이 있을 수 있다.
- **모든 `paperclipai` 호출에 `PAPERCLIP_HOME="$HOME/.paperclip"`을 export 한다.**
- **버전 핀은 `pins.env` 한 곳에서만 정의한다.** 다른 파일에 버전 문자열을 중복 기재하지 않는다.
- **테스트는 `HC_HOME`을 임시 디렉터리로 덮어써 실제 홈을 건드리지 않는다.**
- 환경 변수 스위치(테스트/CI용): `HC_HOME`, `HC_SOURCE_DIR`, `HC_LATEST_VERSION`, `HC_SKIP_AUTOSTART`, `HC_SKIP_OPEN`, `HC_SKIP_NETWORK`, `HC_NO_COLOR`, `HC_DRY_RUN`, `HC_SMOKE_REAL`.
- 실패 시 창을 닫지 않는다. 마지막에 `ui_pause`로 대기하고 로그 경로를 보여준다.
- **최소 지원 버전: macOS 13.0 (Ventura).** 그 아래는 설치를 시작하지 않고 한국어로 이유를 알린다.
- 지원 아키텍처: `arm64`·`x64` 둘 다.

## Review Focus

이 목록은 스펙이 명시하지 않았지만 실제 사용자에게 물릴 것이 확실한 입력/상황들이다. 각 항목은 아래에 지정된 태스크의 테스트로 고정한다.

1. **이미 다른 Node가 있는 사용자**(nvm, homebrew). 우리 `~/.local/bin/node`가 그들의 것을 가리거나 반대로 밀려나면 안 된다. → Task 7
2. **`~/.hermes`가 이미 있는데 우리가 만든 게 아닌 경우.** 업데이트·제거가 그들의 기존 Hermes를 건드리면 안 된다. → Task 19
3. **3100 포트가 이미 사용 중.** Paperclip이 다른 포트를 고르는데 우리가 3100을 열어주면 사용자는 빈 화면을 본다. → Task 6, Task 16
4. **경로에 공백이나 한글**(`/Users/김 철수/...`). 따옴표 누락은 macOS에서 흔하고 재현이 어렵다. → Task 2
5. **비-TTY 실행**(CI, 스크립트). `ui_pause`가 입력을 기다리며 영원히 멈추면 안 된다. → Task 3

---

## File Structure

| 파일 | 책임 |
|---|---|
| `VERSION` | 설치기 자체의 버전 (`0.1.0`) |
| `pins.env` | Node / Paperclip / Hermes / Python 버전 핀 |
| `.gitignore` | `dist/`, `.paperclip/`, `*.log` |
| `Makefile` | `test`, `lint`, `release-check` |
| `core/lib.sh` | 경로 계산, OS 감지, 로그, `hc_die`, 플랫폼 로더 |
| `core/ui.sh` | 한국어 출력(박스, 단계, ok/skip/warn/fail, pause) |
| `core/manifest.sh` | `manifest.env` 읽기/쓰기 |
| `core/fetch.sh` | 다운로드, sha256 검증, 압축 해제 |
| `core/run.sh` | 명령 디스패처, `hc_run_step` |
| `core/steps/10-preflight.sh` … `90-verify.sh` | 각 단계 함수 |
| `core/steps/connect.sh` | AI 연결 |
| `core/steps/update.sh` | 업데이트 + 롤백 |
| `core/steps/uninstall.sh` | 제거 |
| `platform/macos.sh` | `p_*` 함수 전부 |
| `platform/launchagent.plist.template` | LaunchAgent 템플릿 |
| `entry/bootstrap.sh` | curl 진입점 (버전 확인 → zip 다운로드 → core 실행) |
| `entry/설치.command` | 더블클릭 진입점 |
| `entry/사용방법.html` | 우클릭→열기 안내 |
| `tests/helpers.sh` | assert 헬퍼 |
| `tests/run.sh` | 모든 `tests/test_*.sh` 실행 |
| `tests/test_*.sh` | 단위 테스트 |
| `tests/smoke.sh` | 가짜 HOME에서 실제 설치 E2E |
| `.github/workflows/ci.yml` | macOS 잡: `make test` + `tests/smoke.sh` |

**스펙 대비 조정 2가지** (구현자에게 알림):
- 스펙 12절은 `install.json`을 썼지만 **`manifest.env`(key=value)** 로 바꾼다. 이유: bash와 PowerShell 모두에서 파서 의존성 없이 읽히고, macOS에 `jq`도 안정적인 `python3`도 없다.
- 스펙 14절의 `VERSION` 외에 **`pins.env`를 추가**한다. 버전 문자열이 여러 파일에 흩어지는 것을 막는다.

---

### Task 1: 저장소 뼈대와 테스트 러너

**Files:**
- Create: `VERSION`, `pins.env`, `.gitignore`, `Makefile`, `tests/helpers.sh`, `tests/run.sh`, `tests/test_helpers.sh`

**Interfaces:**
- Consumes: 없음
- Produces: `tests/run.sh`(모든 `tests/test_*.sh`를 실행하고 실패 수를 반환), `assert_eq <expected> <actual> <label>`, `assert_contains <haystack> <needle> <label>`, `assert_status <expected> <actual> <label>`. 이후 모든 테스트는 이 헬퍼만 쓴다.

- [ ] **Step 1: 테스트 헬퍼의 실패 테스트를 쓴다**

`tests/test_helpers.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$0")/helpers.sh"

t_ok()    { assert_eq "a" "a" "동일한 값은 통과"; }
t_fail()  { assert_eq "a" "b" "다른 값은 실패"; }
t_has()   { assert_contains "hello world" "world" "부분 문자열 포함"; }
t_code()  { assert_status 0 0 "0은 0"; }

run_tests t_ok t_fail t_has t_code
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_helpers.sh`
Expected: FAIL — `tests/helpers.sh: No such file or directory`

- [ ] **Step 3: 헬퍼와 러너를 구현한다**

`tests/helpers.sh` — 다음 함수를 정의한다. `TESTS_RUN`, `TESTS_FAILED` 카운터를 전역으로 유지한다.
- `assert_eq <expected> <actual> <label>` — 같지 않으면 `✗ <label>: expected=<e> actual=<a>` 출력, `TESTS_FAILED` 증가
- `assert_contains <haystack> <needle> <label>`
- `assert_status <expected> <actual> <label>`
- `run_tests <fn>...` — 각 함수를 `( )` 서브셸에서 실행하고, 마지막에 `pass=<n> fail=<n>` 요약 출력, `TESTS_FAILED>0`이면 exit 1

`tests/run.sh` — `tests/test_*.sh`를 이름순으로 `bash`로 실행하고, 하나라도 실패하면 exit 1.

`VERSION`:
```
0.1.0
```

`pins.env`:
```sh
NODE_VERSION=24.20.0
PAPERCLIP_VERSION=2026.1117.0
HERMES_VERSION=0.19.0
PYTHON_VERSION=3.13
```

`.gitignore`:
```
dist/
.paperclip/
*.log
.DS_Store
```

`Makefile`:
```make
SHELL := /usr/bin/env bash
.PHONY: test
test:
	bash tests/run.sh
```

- [ ] **Step 4: 통과를 확인한다**

Run: `make test`
Expected: `pass=4 fail=0` 그리고 exit 0

- [ ] **Step 5: 커밋**

```bash
git add VERSION pins.env .gitignore Makefile tests/
git commit -m "chore: add repo skeleton, version pins, and test runner"
```

---

### Task 2: `core/lib.sh` — 경로, OS 감지, 로깅

**Files:**
- Create: `core/lib.sh`, `tests/test_lib.sh`
- Modify: `tests/run.sh` (변경 없음 — `test_*.sh` 자동 수집이면 그대로)

**Interfaces:**
- Consumes: `tests/helpers.sh`
- Produces:
  - `hc_root() -> path` — 설치기가 놓인 디렉터리(이 파일 기준 `..`)
  - `hc_home() -> path` — `${HC_HOME:-$HOME/.hermes-paperclip-native}`
  - `hc_app_root() -> path`, `hc_log_dir() -> path`, `hc_log_file() -> path`
  - `hc_os() -> "macos"|"linux"|"windows"`, `hc_arch() -> "arm64"|"x64"`
  - `hc_version() -> string` — `VERSION` 파일 내용
  - `hc_pin <NAME> -> string` — `pins.env`에서 값 조회
  - `hc_log <message>` — 로그 파일에 `[ISO8601] message` 추가
  - `hc_die <korean message>` — `ui_fail` 후 exit 1
  - `hc_load_platform` — `platform/$(hc_os).sh`를 source

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_lib.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"

t_home_override() {
  local out; out="$(HC_HOME=/tmp/hc-test hc_home)"
  assert_eq "/tmp/hc-test" "$out" "HC_HOME 이 있으면 그 값을 쓴다"
}
t_home_default() {
  local out; out="$(HOME=/tmp/fakehome HC_HOME= hc_home)"
  assert_eq "/tmp/fakehome/.hermes-paperclip-native" "$out" "기본값은 HOME 아래"
}
t_paths() {
  assert_eq "/tmp/hc-test/logs" "$(HC_HOME=/tmp/hc-test hc_log_dir)" "로그 디렉터리"
  assert_eq "/tmp/hc-test/app"  "$(HC_HOME=/tmp/hc-test hc_app_root)" "app 디렉터리"
}
t_version() { assert_eq "0.1.0" "$(hc_version)" "VERSION 파일"; }
t_pin()     { assert_eq "24.20.0" "$(hc_pin NODE_VERSION)" "pins.env 조회"; }
t_arch()    { assert_contains "arm64 x64" "$(hc_arch)" "아키텍처는 둘 중 하나"; }
t_space_path() {
  local d; d="$(mktemp -d)/공백 있는 폴더"
  mkdir -p "$d"
  HC_HOME="$d" hc_log "테스트"
  assert_status 0 $? "공백/한글 경로에 로그를 쓸 수 있다"
}
t_log() {
  local d; d="$(mktemp -d)"
  HC_HOME="$d" hc_log "안녕"
  assert_contains "$(cat "$d/logs/install.log")" "안녕" "로그에 메시지가 남는다"
}
run_tests t_home_override t_home_default t_paths t_version t_pin t_arch t_space_path t_log
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_lib.sh`
Expected: FAIL — `core/lib.sh: No such file or directory`

- [ ] **Step 3: `core/lib.sh`를 구현한다**

모든 경로는 `printf '%s'` 로 출력하고 **반드시 큰따옴표로** 사용한다. `hc_log`는 `hc_log_dir`를 `mkdir -p` 한 뒤 append 한다. `hc_die`는 `ui_fail`을 호출하므로 `core/ui.sh`가 아직 없으면 텍스트만 출력하고 exit 1 한다(순환 의존 금지: `lib.sh`는 `ui.sh`를 source 하지 않는다).

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_lib.sh`
Expected: `pass=8 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add core/lib.sh tests/test_lib.sh
git commit -m "feat(core): add path, OS detection, and logging helpers"
```

---

### Task 3: `core/ui.sh` — 한국어 출력

**Files:**
- Create: `core/ui.sh`, `tests/test_ui.sh`

**Interfaces:**
- Consumes: 없음 (`ui_*`는 `lib.sh`에 의존하지 않는다)
- Produces:
  - `ui_init` — `HC_NO_COLOR`가 설정됐거나 stdout이 TTY가 아니면 `UI_COLOR=0`, 아니면 `UI_COLOR=1`
  - `ui_title <text>`
  - `ui_box <line>...` — `╭─...─╮` / `│ text │` / `╰─...─╯` (박스 폭은 가장 긴 줄 + 여백)
  - `ui_step <n> <total> <text>` → `[n/total] text`
  - `ui_ok <text>` → `      ✓ text`, `ui_skip` → `      · text (건너뜀)`, `ui_warn` → `      ! text`, `ui_fail` → `      ✗ text`
  - `ui_pause` — **stdin이 TTY일 때만** `계속하려면 Enter 키를 누르세요...` 출력 후 한 줄 읽는다. TTY가 아니면 즉시 반환한다(Review Focus 5).
  - `ui_blank`

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_ui.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/ui.sh"
export HC_NO_COLOR=1

t_step()  { assert_eq "[1/8] 이 컴퓨터를 확인하는 중..." "$(ui_step 1 8 "이 컴퓨터를 확인하는 중...")" "단계 표시"; }
t_ok()    { assert_eq "      ✓ Node.js v24.20.0" "$(ui_ok "Node.js v24.20.0")" "성공 표시"; }
t_skip()  { assert_eq "      · 이미 설치됨 (건너뜀)" "$(ui_skip "이미 설치됨")" "건너뜀 표시"; }
t_fail()  { assert_eq "      ✗ 실패했습니다" "$(ui_fail "실패했습니다")" "실패 표시"; }
t_box()   { local out; out="$(ui_box "안녕" "세계")"; assert_contains "$out" "│ 안녕 │" "박스 내용"; assert_contains "$out" "╰" "박스 닫힘"; }
t_pause_notty() {
  local out; out="$(printf '' | ui_pause)"; assert_eq "" "$out" "비-TTY에서 멈추지 않는다"
}
t_nocolor() { assert_contains "$(ui_step 1 2 "x")" "[1/2] x" "색상 없는 출력"; assert_eq "0" "$UI_COLOR" "색상 꺼짐"; }
run_tests t_step t_ok t_skip t_fail t_box t_pause_notty t_nocolor
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_ui.sh`
Expected: FAIL — `core/ui.sh: No such file or directory`

- [ ] **Step 3: `core/ui.sh`를 구현한다**

`ui_step` 등은 `printf`로 정확히 위 문자열을 만든다(`echo` 금지). `ui_box`는 `LC_ALL=en_US.UTF-8` 가정 하에 문자 수 기준으로 폭을 맞춘다 — 한글 폭 계산이 필요하면 `awk` 대신 문자 수로 단순 계산하고, 폭이 어긋나도 기능에는 영향이 없음을 주석으로 남긴다. `ui_pause`는 `[ -t 0 ]`로 판정한다. 색상은 변수 `UI_C_OK/UI_C_WARN/UI_C_FAIL/UI_C_OFF`로 두고 `ui_init`에서 채운다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_ui.sh`
Expected: `pass=7 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add core/ui.sh tests/test_ui.sh
git commit -m "feat(core): add Korean UI output helpers"
```

---

### Task 4: `core/manifest.sh` — 설치 상태 기록

**Files:**
- Create: `core/manifest.sh`, `tests/test_manifest.sh`

**Interfaces:**
- Consumes: `hc_home()`
- Produces:
  - `mf_path() -> path` — `$(hc_home)/manifest.env`
  - `mf_exists` — 파일 존재 시 0
  - `mf_get <KEY> -> string` — 없으면 빈 문자열
  - `mf_set <KEY> <VALUE>` — 없으면 추가, 있으면 교체. 원자적(임시 파일 + `mv`)
  - `mf_dump` — 전체 출력

파일 형식(`key=value`, `#` 주석 허용):
```
HC_MANIFEST_VERSION=1
INSTALLER_VERSION=0.1.0
INSTALLED_AT=2026-11-23T12:00:00Z
PLATFORM=macos-arm64
HERMES_EXISTED=false
NODE_VERSION=24.20.0
PAPERCLIP_VERSION=2026.1117.0
HERMES_VERSION=0.19.0
PYTHON_VERSION=3.13
DATA_DIR=/Users/me/.paperclip
AUTOSTART_LABEL=ing.hermes-paperclip.agent
```

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_manifest.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/manifest.sh"

setup() { export HC_HOME="$(mktemp -d)"; }

t_missing()  { setup; assert_eq "" "$(mf_get NODE_VERSION)" "없는 키는 빈 문자열"; assert_status 1 $?; }
t_set_get()  { setup; mf_set NODE_VERSION 24.20.0; assert_eq "24.20.0" "$(mf_get NODE_VERSION)" "저장 후 조회"; }
t_replace()  { setup; mf_set NODE_VERSION 1.0.0; mf_set NODE_VERSION 2.0.0; assert_eq "2.0.0" "$(mf_get NODE_VERSION)" "같은 키는 교체"; }
t_no_dup()   { setup; mf_set A 1; mf_set A 2; assert_eq "1" "$(grep -c '^A=' "$(mf_path)")" "중복 줄이 생기지 않는다"; }
t_persist()  { setup; mf_set A 1; assert_eq "1" "$(HC_HOME="$HC_HOME" mf_get A)" "새 프로세스에서도 읽힌다"; }
t_space()    { setup; mf_set MSG "안녕 세계"; assert_eq "안녕 세계" "$(mf_get MSG)" "공백 포함 값"; }
run_tests t_missing t_set_get t_replace t_no_dup t_persist t_space
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_manifest.sh`
Expected: FAIL — `core/manifest.sh: No such file or directory`

- [ ] **Step 3: `core/manifest.sh`를 구현한다**

`mf_set`은 `grep -v "^${KEY}=" "$tmp" > "$new"` 방식으로 중복을 제거하고 `mv`로 교체한다. `mf_path`가 없으면 `mf_set`이 `hc_home`을 `mkdir -p` 한다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_manifest.sh`
Expected: `pass=6 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add core/manifest.sh tests/test_manifest.sh
git commit -m "feat(core): add key=value install manifest"
```

---

### Task 5: `core/fetch.sh` — 다운로드·검증·해제

**Files:**
- Create: `core/fetch.sh`, `tests/test_fetch.sh`

**Interfaces:**
- Consumes: `hc_log`, `hc_die`
- Produces:
  - `ft_download <url> <dest-path>` — `curl -fL --retry 2 --connect-timeout 15` 로 저장. 성공 0
  - `ft_sha256 <file> -> hex`
  - `ft_verify <file> <expected-hex>` — 일치 0, 불일치 1
  - `ft_extract <archive> <dest-dir>` — `.zip`이면 `unzip -q`, `.tar.gz`/`.tgz`면 `tar -xzf`
  - `ft_fetch_and_verify <url> <dest> <expected-hex>` — 다운로드 후 검증, 실패 시 `hc_die`

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_fetch.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/fetch.sh"
export HC_HOME="$(mktemp -d)"

t_sha() {
  local f; f="$(mktemp)"; printf 'hello' > "$f"
  assert_eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" "$(ft_sha256 "$f")" "sha256 계산"
}
t_verify_ok()   { local f; f="$(mktemp)"; printf 'hello' > "$f"; assert_status 0 $(ft_verify "$f" "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"; echo $?) "올바른 해시 통과"; }
t_verify_bad()  { local f; f="$(mktemp)"; printf 'hello' > "$f"; assert_status 1 $(ft_verify "$f" "deadbeef"; echo $?) "틀린 해시 거부"; }
t_extract_zip() { local d; d="$(mktemp -d)"; printf 'x' > "$d/a.txt"; (cd "$d" && zip -q out.zip a.txt)
  local o; o="$(mktemp -d)"; ft_extract "$d/out.zip" "$o"; assert_status 0 $? "zip 해제"; assert_status 0 $([ -f "$o/a.txt" ]; echo $?) "해제된 파일 존재"; }
t_download_missing() { assert_status 1 $(ft_download "https://example.invalid/nope" "$(mktemp -d)/f" 2>/dev/null; echo $?) "잘못된 URL은 실패"; }
run_tests t_sha t_verify_ok t_verify_bad t_extract_zip t_download_missing
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_fetch.sh`
Expected: FAIL — `core/fetch.sh: No such file or directory`

- [ ] **Step 3: `core/fetch.sh`를 구현한다**

`ft_sha256`은 `shasum -a 256 "$f" | awk '{print $1}'` (macOS에 `sha256sum`이 없음). `ft_extract`는 `unzip`/`tar` 존재를 `command -v`로 확인하고 없으면 한국어 메시지로 `hc_die`.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_fetch.sh`
Expected: `pass=5 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add core/fetch.sh tests/test_fetch.sh
git commit -m "feat(core): add download, sha256 verify, and extract"
```

---

### Task 6: `platform/macos.sh` — 감지, 경로, URL, 브라우저, 로그

**Files:**
- Create: `platform/macos.sh`, `tests/test_platform_macos.sh`

**Interfaces:**
- Consumes: `hc_*`
- Produces:
  - `p_detect` — `P_OS=macos`, `P_ARCH`(`arm64`|`x64`), `P_OS_VERSION`(예 `26.7.3`) 설정
  - `p_bin_dir -> $HOME/.local/bin`
  - `p_node_dir -> $HOME/.local/node`
  - `p_data_dir -> $HOME/.paperclip`
  - `p_app_dir -> $(hc_home)`
  - `p_has_display -> 0` (macOS는 항상 GUI)
  - `p_node_archive_url <version> -> url` — `https://nodejs.org/dist/v$v/node-v$v-darwin-$arch.tar.gz`
  - `p_server_url -> http://127.0.0.1:<port>` — `$(p_data_dir)/instances/default/config.json`에서 실제 포트를 읽고, 못 읽으면 `3100`
  - `p_open_browser <url>` — `open "$url"`
  - `p_tail_log <n>` — `$(p_data_dir)/instances/default/logs` 아래 최신 로그 n줄

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_platform_macos.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../platform/macos.sh"
export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"

t_detect() { p_detect; assert_contains "arm64 x64" "$P_ARCH" "아키텍처"; assert_eq "macos" "$P_OS" "OS"; }
t_paths()  { assert_eq "$HOME/.local/bin" "$(p_bin_dir)" "bin"; assert_eq "$HOME/.local/node" "$(p_node_dir)" "node"; assert_eq "$HOME/.paperclip" "$(p_data_dir)" "data"; }
t_node_url_arm() { assert_eq "https://nodejs.org/dist/v24.20.0/node-v24.20.0-darwin-arm64.tar.gz" "$(P_ARCH=arm64 p_node_archive_url 24.20.0)" "arm64 URL"; }
t_node_url_x64() { assert_eq "https://nodejs.org/dist/v24.20.0/node-v24.20.0-darwin-x64.tar.gz"   "$(P_ARCH=x64   p_node_archive_url 24.20.0)" "x64 URL"; }
t_url_default()  { assert_eq "http://127.0.0.1:3100" "$(p_server_url)" "설정이 없으면 3100"; }
t_url_from_cfg() {
  mkdir -p "$HOME/.paperclip/instances/default"
  printf '{"server":{"port":3210}}' > "$HOME/.paperclip/instances/default/config.json"
  assert_eq "http://127.0.0.1:3210" "$(p_server_url)" "설정에 적힌 실제 포트를 읽는다"
}
run_tests t_detect t_paths t_node_url_arm t_node_url_x64 t_url_default t_url_from_cfg
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_platform_macos.sh`
Expected: FAIL — `platform/macos.sh: No such file or directory`

- [ ] **Step 3: `platform/macos.sh`를 구현한다**

`p_server_url`은 `sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p'` 로 추출한다. `jq`를 쓰지 않는다. 포트 파싱은 **Review Focus 3**을 위한 것이므로 실패해도 3100으로 폴백한다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_platform_macos.sh`
Expected: `pass=6 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add platform/macos.sh tests/test_platform_macos.sh
git commit -m "feat(macos): add detection, paths, server URL, and browser"
```

---

### Task 7: `platform/macos.sh` — Node 설치와 PATH 등록

**Files:**
- Modify: `platform/macos.sh`, `tests/test_platform_macos.sh`

**Interfaces:**
- Consumes: `p_node_archive_url`, `p_bin_dir`, `p_node_dir`, `ft_*`
- Produces:
  - `p_node_present -> 0/1` — `$(p_bin_dir)/node`가 있고 `node -v`가 `v$NODE_VERSION`이면 0
  - `p_install_node` — 없으면 tarball 다운로드 → `p_node_dir`에 해제 → `node`, `npm`, `npx`를 `p_bin_dir`에 심볼릭 링크. 이미 있으면 아무것도 안 하고 0
  - `p_persist_path` — `~/.zprofile`에 마커 블록이 없으면 추가. 두 번 실행해도 한 번만 추가

- [ ] **Step 1: 실패 테스트를 쓴다**

기존 `tests/test_platform_macos.sh`의 `run_tests` 줄 앞에 추가한다.
```bash
t_install_node_skips() {
  mkdir -p "$(p_bin_dir)"
  printf '#!/bin/sh\necho v24.20.0\n' > "$(p_bin_dir)/node"; chmod +x "$(p_bin_dir)/node"
  NODE_VERSION=24.20.0
  p_install_node
  assert_status 0 $? "이미 있으면 건너뛴다"
}
t_persist_once() {
  export HOME="$(mktemp -d)"; : > "$HOME/.zprofile"
  p_persist_path; p_persist_path
  assert_eq "1" "$(grep -c 'hermes-paperclip' "$HOME/.zprofile")" "PATH 블록은 한 번만"
  assert_contains "$(cat "$HOME/.zprofile")" '.local/bin' "PATH 내용"
}
t_install_node_unsets_other_node() {
  # 다른 Node(nvm 등)가 PATH 앞에 있어도 우리 것을 쓴다
  mkdir -p "$(p_bin_dir)"
  printf '#!/bin/sh\necho v24.20.0\n' > "$(p_bin_dir)/node"; chmod +x "$(p_bin_dir)/node"
  NODE_VERSION=24.20.0
  local out; out="$(p_install_node; PATH="$(p_bin_dir):$PATH" command -v node)"
  assert_eq "$(p_bin_dir)/node" "$out" "우리 node가 우선한다"
}
```
`run_tests` 줄은 다음과 같이 교체한다:
```bash
run_tests t_detect t_paths t_node_url_arm t_node_url_x64 t_url_default t_url_from_cfg \
          t_install_node_skips t_persist_once t_install_node_unsets_other_node
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_platform_macos.sh`
Expected: FAIL — `p_install_node: command not found`

- [ ] **Step 3: 구현한다**

`p_install_node`은 `HC_SKIP_NETWORK=1`이면 다운로드 대신 즉시 실패 메시지를 낸다(테스트용). `p_persist_path`의 마커 블록:
```
# >>> hermes-paperclip >>>
export PATH="$HOME/.local/bin:$PATH"
# <<< hermes-paperclip <<<
```
**Review Focus 1**을 위해 `p_persist_path`는 `~/.local/bin`을 **맨 앞**에 넣는다. 기존 `~/.zprofile` 내용은 보존한다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_platform_macos.sh`
Expected: `pass=9 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add platform/macos.sh tests/test_platform_macos.sh
git commit -m "feat(macos): install portable Node and persist PATH"
```

---

### Task 8: `platform/macos.sh` — uv와 Hermes

**Files:**
- Modify: `platform/macos.sh`, `tests/test_platform_macos.sh`

**Interfaces:**
- Consumes: `p_bin_dir`, `hc_pin`, `ft_*`
- Produces:
  - `p_uv_present -> 0/1`
  - `p_install_uv` — `$(p_bin_dir)/uv`가 없으면 `https://astral.sh/uv/install.sh`를 받아 `UV_INSTALL_DIR="$(dirname "$(p_bin_dir)")/bin"` 로 실행. 있으면 skip
  - `p_install_hermes` — `uv python install $PYTHON_VERSION` → `uv tool install hermes-agent==$HERMES_VERSION`. 이미 같은 버전이면 skip
  - `p_hermes_present -> 0/1` — `$(p_bin_dir)/hermes` 존재

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_uv_skip() {
  mkdir -p "$(p_bin_dir)"; printf '#!/bin/sh\nexit 0\n' > "$(p_bin_dir)/uv"; chmod +x "$(p_bin_dir)/uv"
  assert_status 0 $? "uv 존재 판정"
  p_install_uv; assert_status 0 $? "이미 있으면 건너뛴다"
}
t_hermes_present() {
  mkdir -p "$(p_bin_dir)"; : > "$(p_bin_dir)/hermes"; chmod +x "$(p_bin_dir)/hermes"
  assert_status 0 $? "hermes 존재 판정"
}
t_hermes_pins() {
  # 실행 계획만 검사한다: HC_DRY_RUN=1이면 실제로 설치하지 않고 명령을 출력한다
  local out; out="$(HC_DRY_RUN=1 p_install_hermes)"
  assert_contains "$out" "uv tool install hermes-agent==0.19.0" "Hermes 버전 핀"
  assert_contains "$out" "uv python install 3.13" "Python 버전 핀"
}
```
`run_tests`에 `t_uv_skip t_hermes_present t_hermes_pins`를 추가한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_platform_macos.sh`
Expected: FAIL — `p_install_hermes: command not found`

- [ ] **Step 3: 구현한다**

`HC_DRY_RUN=1`일 때 설치 계열 함수는 실행 대신 `p_run <command...>`가 명령 문자열을 출력한다. `p_run`은 `HC_DRY_RUN`이면 `printf '%s\n' "$*"`, 아니면 `"$@"` 실행. 이후 모든 설치 함수가 `p_run`을 쓴다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_platform_macos.sh`
Expected: `pass=12 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add platform/macos.sh tests/test_platform_macos.sh
git commit -m "feat(macos): install uv, pinned Python, and hermes-agent"
```

---

### Task 9: `platform/macos.sh` — Paperclip CLI

**Files:**
- Modify: `platform/macos.sh`, `tests/test_platform_macos.sh`

**Interfaces:**
- Consumes: `p_bin_dir`, `p_data_dir`, `hc_pin`, `p_run`
- Produces:
  - `p_paperclip_present -> 0/1` — `$(p_bin_dir)/paperclipai` 존재
  - `p_install_paperclip` — 없으면 `p_run npx --yes "paperclipai@$PAPERCLIP_VERSION" install`
  - `p_paperclip_env` — `PAPERCLIP_HOME="$(p_data_dir)"`를 export (다른 함수들이 이걸 호출)

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_pc_pins() {
  local out; out="$(HC_DRY_RUN=1 p_install_paperclip)"
  assert_contains "$out" "paperclipai@2026.1117.0 install" "Paperclip 버전 핀"
}
t_pc_env() {
  p_paperclip_env
  assert_eq "$HOME/.paperclip" "$PAPERCLIP_HOME" "PAPERCLIP_HOME 을 홈 데이터로 고정"
}
t_pc_skip() {
  mkdir -p "$(p_bin_dir)"; : > "$(p_bin_dir)/paperclipai"; chmod +x "$(p_bin_dir)/paperclipai"
  p_install_paperclip; assert_status 0 $? "이미 있으면 건너뛴다"
}
```
`run_tests`에 `t_pc_pins t_pc_env t_pc_skip`을 추가한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_platform_macos.sh`
Expected: FAIL — `p_install_paperclip: command not found`

- [ ] **Step 3: 구현한다**

managed install은 `~/.local/bin`에 `paperclipai`를 만든다. `npx`는 Node tarball에 포함되어 있고 `p_bin_dir`에 심볼릭 링크되어 있다(Task 7).

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_platform_macos.sh`
Expected: `pass=15 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add platform/macos.sh tests/test_platform_macos.sh
git commit -m "feat(macos): install pinned paperclipai CLI"
```

---

### Task 10: `platform/macos.sh` — 자동 시작 (LaunchAgent)

**Files:**
- Create: `platform/launchagent.plist.template`
- Modify: `platform/macos.sh`, `tests/test_platform_macos.sh`

**Interfaces:**
- Consumes: `p_bin_dir`, `p_node_dir`, `p_data_dir`, `hc_home`, `p_run`
- Produces:
  - `p_autostart_label -> ing.hermes-paperclip.agent`
  - `p_autostart_plist -> ~/Library/LaunchAgents/ing.hermes-paperclip.agent.plist`
  - `p_autostart_render -> string` — 템플릿의 `@@HOME@@`, `@@PATH@@`, `@@LOG@@`를 치환한 plist 전체
  - `p_autostart_install` — plist 기록, `launchctl bootout`(무시) → `launchctl bootstrap gui/$UID <plist>`
  - `p_autostart_remove` — `launchctl bootout gui/$UID/<label>`, plist 삭제
  - `p_autostart_status -> running|stopped|absent`

**plist의 PATH가 이 태스크의 존재 이유다.** launchd는 PATH를 비워 두므로, 여기서 `~/.local/bin`을 넣지 않으면 Hermes 어댑터가 `hermes`를 찾지 못한다.

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_plist_render() {
  local out; out="$(p_autostart_render)"
  assert_contains "$out" "<string>$HOME/.local/bin:$HOME/.local/node/bin:" "PATH 를 plist 에 명시"
  assert_contains "$out" "<string>$HOME/.local/bin/paperclipai</string>" "paperclipai 실행"
  assert_contains "$out" "ing.hermes-paperclip.agent" "라벨"
  assert_contains "$out" "$(hc_home)/logs/server.log" "로그 경로"
}
t_plist_no_placeholder() {
  local out; out="$(p_autostart_render)"
  if printf '%s' "$out" | grep -q '@@'; then assert_eq "no-placeholder" "found" "@@ 치환이 남아 있다"; else assert_eq "ok" "ok" "@@ 치환 완료"; fi
}
t_status_absent() {
  export HOME="$(mktemp -d)"
  assert_eq "absent" "$(p_autostart_status)" "plist 가 없으면 absent"
}
```
`run_tests`에 `t_plist_render t_plist_no_placeholder t_status_absent`을 추가한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_platform_macos.sh`
Expected: FAIL — `p_autostart_render: command not found`

- [ ] **Step 3: 템플릿과 함수를 구현한다**

`platform/launchagent.plist.template`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>@@LABEL@@</string>
  <key>ProgramArguments</key>
  <array>
    <string>@@PAPERCLIP@@</string>
    <string>run</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>@@PATH@@</string>
    <key>HOME</key><string>@@HOME@@</string>
    <key>PAPERCLIP_HOME</key><string>@@DATA_DIR@@</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>StandardOutPath</key><string>@@LOG@@</string>
  <key>StandardErrorPath</key><string>@@LOG_ERR@@</string>
</dict>
</plist>
```
`p_autostart_render`는 `sed`로 치환한다. `HC_SKIP_AUTOSTART=1`이면 `p_autostart_install`은 즉시 0을 반환한다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_platform_macos.sh`
Expected: `pass=18 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add platform/launchagent.plist.template platform/macos.sh tests/test_platform_macos.sh
git commit -m "feat(macos): manage autostart LaunchAgent with explicit PATH"
```

---

### Task 11: `core/run.sh` — 디스패처와 단계 실행기

**Files:**
- Create: `core/run.sh`, `tests/test_run.sh`

**Interfaces:**
- Consumes: `hc_*`, `ui_*`, `mf_*`
- Produces:
  - `hc_run_step <n> <total> <fn> <korean-label> [soft]` — `ui_step` 출력 → `fn` 호출 → 성공 시 `ui_ok <label>`; 실패 시 `soft`면 `ui_warn` 후 0 반환, 아니면 `ui_fail` 후 1 반환
  - `hc_dispatch <command> [args]` — `install|update|start|stop|status|connect|uninstall|verify` 중 하나를 실행. 알 수 없는 명령은 사용법 출력 후 exit 2. `start`/`stop`/`status`/`verify`의 구현은 **Task 16**이 제공한다.
  - `hc_install_steps` — 설치 단계의 `(번호, 함수, 라벨, soft)` 목록을 순서대로 출력

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_run.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/run.sh"
export HC_HOME="$(mktemp -d)" HC_NO_COLOR=1

step_ok()   { return 0; }
step_bad()  { return 1; }

t_step_ok()   { local out; out="$(HC_HOME="$HC_HOME" hc_run_step 1 8 step_ok "확인" 2>&1)"; assert_contains "$out" "✓ 확인" "성공 라벨"; }
t_step_hard() { HC_HOME="$HC_HOME" hc_run_step 2 8 step_bad "실패단계" >/dev/null 2>&1; assert_status 1 $? "실패하면 1"; }
t_step_soft() { HC_HOME="$HC_HOME" hc_run_step 2 8 step_bad "무른단계" soft >/dev/null 2>&1; assert_status 0 $? "soft 는 0"; }
t_unknown()   { hc_dispatch "존재하지않음" >/dev/null 2>&1; assert_status 2 $? "알 수 없는 명령은 2"; }
t_steps_list(){ assert_contains "$(hc_install_steps)" "preflight" "단계 목록에 preflight"; }
run_tests t_step_ok t_step_hard t_step_soft t_unknown t_steps_list
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_run.sh`
Expected: FAIL — `core/run.sh: No such file or directory`

- [ ] **Step 3: 구현한다**

`hc_dispatch`는 각 명령에 대해 대응하는 `step_*`/`cmd_*` 함수를 호출한다. `install`은 `hc_install_steps`를 순회하며 `hc_run_step`을 호출한다. 이 태스크에서는 단계 함수를 아직 만들지 않았으므로 `hc_install_steps`가 이름만 나열하고, 없는 함수 호출은 `soft`로 처리하지 않는다 — 대신 각 단계 파일을 source 하는 `hc_load_steps`를 두고, 파일이 없으면 `hc_die`로 "설치 파일이 손상되었습니다"를 낸다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_run.sh`
Expected: `pass=5 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add core/run.sh tests/test_run.sh
git commit -m "feat(core): add command dispatcher and step runner"
```

---

### Task 12: 설치 단계 1–2 (사전 점검, Node)

**Files:**
- Create: `core/steps/10-preflight.sh`, `core/steps/20-node.sh`, `tests/test_steps_early.sh`

**Interfaces:**
- Consumes: `hc_*`, `mf_*`, `p_*`, `ui_*`
- Produces:
  - `step_preflight` — macOS 최소 버전 확인, 디스크 3GB 확인, `~/.hermes` 존재 여부를 `HERMES_EXISTED`로 기록, `DATA_DIR`/`PLATFORM`/`INSTALLED_AT`을 매니페스트에 기록
  - `step_node` — `p_install_node`, `p_persist_path`, `NODE_VERSION` 기록

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_steps_early.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"; . "$HERE/../core/ui.sh"; . "$HERE/../core/manifest.sh"
. "$HERE/../platform/macos.sh"; . "$HERE/../core/steps/10-preflight.sh"; . "$HERE/../core/steps/20-node.sh"
export HC_NO_COLOR=1

t_records_platform() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  HC_SKIP_NETWORK=1 step_preflight
  assert_eq "macos-$P_ARCH" "$(mf_get PLATFORM)" "플랫폼 기록"
  assert_contains "$(mf_get INSTALLED_AT)" "20" "설치 시각 기록"
}
t_records_existing_hermes() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; mkdir -p "$HOME/.hermes"; p_detect
  HC_SKIP_NETWORK=1 step_preflight
  assert_eq "true" "$(mf_get HERMES_EXISTED)" "기존 Hermes 감지"
}
t_records_no_hermes() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  HC_SKIP_NETWORK=1 step_preflight
  assert_eq "false" "$(mf_get HERMES_EXISTED)" "Hermes 없음"
}
t_node_dry() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  HC_DRY_RUN=1 step_node
  assert_eq "24.20.0" "$(mf_get NODE_VERSION)" "Node 버전 기록"
}
run_tests t_records_platform t_records_existing_hermes t_records_no_hermes t_node_dry
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_steps_early.sh`
Expected: FAIL — `core/steps/10-preflight.sh: No such file or directory`

- [ ] **Step 3: 구현한다**

디스크 확인은 `df -g "$HOME"` 의 여유 GB(4번째 필드)를 읽는다. **macOS 버전은 `sw_vers -productVersion`으로 읽어 `13.0`과 비교하고, 낮으면 `hc_die "이 Mac은 macOS 13 이상이어야 합니다 (현재: <ver>)."`** 로 중단한다. 네트워크 확인은 `HC_SKIP_NETWORK=1`이면 건너뛰고, 아니면 `curl -fsS --max-time 10 -o /dev/null https://registry.npmjs.org/` 로 판정한다. **Review Focus 2**를 위해 `HERMES_EXISTED`를 기록한다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_steps_early.sh`
Expected: `pass=4 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add core/steps/10-preflight.sh core/steps/20-node.sh tests/test_steps_early.sh
git commit -m "feat(steps): add preflight and Node installation"
```

---

### Task 13: 설치 단계 3–4 (Paperclip, Hermes)

**Files:**
- Create: `core/steps/30-paperclip.sh`, `core/steps/40-hermes.sh`, `tests/test_steps_install.sh`

**Interfaces:**
- Consumes: `p_*`, `mf_*`
- Produces:
  - `step_paperclip` — `p_install_paperclip`, `PAPERCLIP_VERSION` 기록
  - `step_hermes` — `p_install_uv`, `p_install_hermes`, `HERMES_VERSION`/`PYTHON_VERSION` 기록

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_paperclip_records() { export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect; HC_DRY_RUN=1 step_paperclip
  assert_eq "2026.1117.0" "$(mf_get PAPERCLIP_VERSION)" "Paperclip 버전 기록"; }
t_hermes_records() { export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect; HC_DRY_RUN=1 step_hermes
  assert_eq "0.19.0" "$(mf_get HERMES_VERSION)" "Hermes 버전 기록"
  assert_eq "3.13" "$(mf_get PYTHON_VERSION)" "Python 버전 기록"; }
run_tests t_paperclip_records t_hermes_records
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_steps_install.sh`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현한다**

각 단계는 이미 설치돼 있으면 `ui_skip`을 출력하고 매니페스트 값만 갱신한다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_steps_install.sh`
Expected: `pass=2 fail=0`

- [ ] **Step 5: 커밋**

```bash
git add core/steps/30-paperclip.sh core/steps/40-hermes.sh tests/test_steps_install.sh
git commit -m "feat(steps): install Paperclip and Hermes"
```

---

### Task 14: 설치 단계 5 (Paperclip 온보딩)

**Files:**
- Create: `core/steps/50-onboard.sh`, `tests/test_steps_onboard.sh`

**Interfaces:**
- Consumes: `p_data_dir`, `p_paperclip_env`, `p_run`, `mf_*`
- Produces:
  - `step_onboard` — `$(p_data_dir)/instances/default/config.json`이 있으면 skip. 없으면 `PAPERCLIP_NO_BROWSER=1` + `PAPERCLIP_HOME` 로 `p_run paperclipai onboard --yes --no-install-service` 실행

- [ ] **Step 1: 수동 스파이크로 실제 동작을 먼저 확인한다**

Run (임시 데이터 디렉터리에서):
```bash
HOME="$(mktemp -d)" PAPERCLIP_HOME="$HOME/.paperclip" \
  PAPERCLIP_NO_BROWSER=1 npx --yes paperclipai@2026.1117.0 onboard --yes --no-install-service
```
Expected: 명령이 **끝나고 셸 프롬프트로 돌아오는지**, 아니면 서버를 포그라운드로 띄워 **블로킹되는지** 관찰한다.
- 끝나면: 이 태스크의 구현을 그대로 진행한다.
- 블로킹되면: `--no-install-service` 대신 `--install-service`를 쓰지 않고, `timeout 120`으로 감싼 뒤 헬스 폴링으로 넘어간다. **어느 쪽이었는지 `docs/architecture.md`에 한 줄로 기록한다.** (스펙 17절 리스크 2)

- [ ] **Step 2: 실패 테스트를 쓴다**

```bash
t_onboard_skip() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  mkdir -p "$HOME/.paperclip/instances/default"; printf '{}' > "$HOME/.paperclip/instances/default/config.json"
  local out; out="$(step_onboard 2>&1)"
  assert_contains "$out" "건너뜀" "설정이 있으면 건너뛴다"
}
t_onboard_command() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  local out; out="$(HC_DRY_RUN=1 step_onboard 2>&1)"
  assert_contains "$out" "onboard --yes --no-install-service" "온보딩 명령"
  assert_contains "$out" "$HOME/.paperclip" "데이터 위치 고정"
}
run_tests t_onboard_skip t_onboard_command
```

- [ ] **Step 3: 실패를 확인한다**

Run: `bash tests/test_steps_onboard.sh`
Expected: FAIL — 파일 없음

- [ ] **Step 4: 구현한다**

- [ ] **Step 5: 통과를 확인하고 커밋한다**

Run: `bash tests/test_steps_onboard.sh`
Expected: `pass=2 fail=0`
```bash
git add core/steps/50-onboard.sh tests/test_steps_onboard.sh
git commit -m "feat(steps): onboard a local Paperclip instance"
```

---

### Task 15: 설치 단계 7 (회사와 CEO 에이전트 시드)

**Files:**
- Create: `core/steps/70-seed.sh`, `tests/test_steps_seed.sh`

**Interfaces:**
- Consumes: `p_run`, `p_paperclip_env`, `hc_pin`
- Produces:
  - `step_seed` — `company list --json`에 `내 AI 회사`가 없으면 `company create`, 그 id로 `agent list --json`에 `CEO`가 없으면 `agent create`. 두 번 실행해도 중복 생성하지 않는다
  - `seed_company_payload -> string`
  - `seed_agent_payload -> string`

**Paperclip 관례를 따른다**: 첫 에이전트는 CEO, timed heartbeat 꺼짐, **예산 미설정**(`budgetMonthlyCents` 키 자체를 넣지 않는다).

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_agent_payload() {
  local p; p="$(seed_agent_payload)"
  assert_contains "$p" '"name": "CEO"' "이름은 CEO"
  assert_contains "$p" '"role": "ceo"' "역할은 ceo"
  assert_contains "$p" 'hermes_local' "Hermes 어댑터"
  assert_contains "$p" '"enabled": false' "timed heartbeat 꺼짐"
  if printf '%s' "$p" | grep -q 'budgetMonthlyCents'; then assert_eq "no-budget" "found" "예산을 넣으면 안 된다"; else assert_eq "ok" "ok" "예산 미설정"; fi
}
t_company_payload() { assert_contains "$(seed_company_payload)" '내 AI 회사' "회사 기본 이름"; }
run_tests t_agent_payload t_company_payload
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_steps_seed.sh`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현한다**

`seed_agent_payload`가 만드는 JSON은 스펙 11절 그대로다(위 4개 단언을 만족해야 한다). 회사 id는 `paperclipai company list --json` 출력에서 `내 AI 회사`의 `id`를 `sed`/`grep`으로 뽑는다 — `jq`를 쓰지 않는다.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `bash tests/test_steps_seed.sh`
Expected: `pass=2 fail=0`
```bash
git add core/steps/70-seed.sh tests/test_steps_seed.sh
git commit -m "feat(steps): seed company and hermes_local CEO agent"
```

---

### Task 16: 생명주기 — 자동 시작, 브라우저 열기, verify, start/stop/status 명령

**Files:**
- Create: `core/steps/60-autostart.sh`, `core/steps/80-open.sh`, `core/steps/90-verify.sh`, `tests/test_steps_lifecycle.sh`

**Interfaces:**
- Consumes: `p_autostart_install`, `p_autostart_remove`, `p_autostart_status`, `p_server_url`, `p_open_browser`, `p_has_display`, `p_tail_log`, `p_paperclip_env`, `mf_get`
- Produces (설치 단계):
  - `step_autostart` — `HC_SKIP_AUTOSTART=1`이면 skip. 아니면 `p_autostart_install` 후 `p_server_url`로 헬스 폴링(최대 60초, 2초 간격)
  - `step_open` — `HC_SKIP_OPEN=1`이면 skip. `p_has_display`가 아니면 URL만 출력. 아니면 `p_open_browser "$(p_server_url)"`
  - `step_verify` — 설치 완료 후 확인: `paperclipai doctor` 통과 여부, `hermes` 실행 가능 여부, `agent list`에 `hermes_local` 에이전트 존재. 실패는 경고로만 알리고 설치 전체를 실패시키지 않는다(soft)
- Produces (명령):
  - `cmd_start` — `p_autostart_install`, 결과를 한국어로 출력
  - `cmd_stop` — `p_autostart_remove`, 결과를 한국어로 출력
  - `cmd_status` — `p_autostart_status`(실행/중지/미설치) + 대시보드 주소 + 설치 버전(Node/Paperclip/Hermes) + 최근 로그 5줄
  - `cmd_verify` — `step_verify`를 직접 실행

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_autostart_skip() { export HC_HOME="$(mktemp -d)"; local out; out="$(HC_SKIP_AUTOSTART=1 step_autostart 2>&1)"; assert_contains "$out" "건너뜀" "자동 시작 건너뛰기"; }
t_open_skip()      { export HC_HOME="$(mktemp -d)"; local out; out="$(HC_SKIP_OPEN=1 step_open 2>&1)"; assert_contains "$out" "건너뜀" "브라우저 건너뛰기"; }
t_open_prints_url(){ export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect; local out; out="$(step_open 2>&1)"; assert_contains "$out" "http://127.0.0.1:3100" "URL 출력"; }
t_status_cmd()     { export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect; local out; out="$(cmd_status 2>&1)"; assert_contains "$out" "http://127.0.0.1:3100" "상태에 주소"; assert_contains "$out" "Paperclip" "상태에 버전"; }
t_stop_cmd_skip()  { export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect; local out; out="$(HC_SKIP_AUTOSTART=1 cmd_stop 2>&1)"; assert_contains "$out" "미설치" "중지 시 상태 안내"; }
t_verify_soft()    { export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect; HC_DRY_RUN=1 step_verify >/dev/null 2>&1; assert_status 0 $? "verify 실패는 설치를 깨지 않는다"; }
run_tests t_autostart_skip t_open_skip t_open_prints_url t_status_cmd t_stop_cmd_skip t_verify_soft
```
`t_open_prints_url`은 `p_open_browser`를 스텁으로 덮어써 실제로 브라우저가 뜨지 않게 한다(`p_open_browser() { printf 'OPEN %s\n' "$1"; }`). `t_verify_soft`도 `p_run`을 스텁으로 바꿔 실패를 주입한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_steps_lifecycle.sh`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현한다**

헬스 폴링은 `curl -fsS --max-time 3 "$(p_server_url)/api/health"`를 반복한다. **Review Focus 3**을 위해 폴링·표시 대상은 항상 `p_server_url`이지 `3100`이 아니다. `cmd_status`의 버전은 매니페스트에서 읽고, 값이 없으면 `알 수 없음`을 출력한다.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `bash tests/test_steps_lifecycle.sh`
Expected: `pass=6 fail=0`
```bash
git add core/steps/60-autostart.sh core/steps/80-open.sh core/steps/90-verify.sh tests/test_steps_lifecycle.sh
git commit -m "feat(steps): add lifecycle steps, verify, and start/stop/status commands"
```

---

### Task 17: 설치 단계 8 (`~/HermesPaperclip/` 제어 파일 생성)

**Files:**
- Create: `core/steps/75-shortcuts.sh`, `tests/test_steps_shortcuts.sh`

**Interfaces:**
- Consumes: `hc_home`, `hc_version`, `mf_*`
- Produces:
  - `shortcut_dir -> ~/HermesPaperclip`
  - `shortcut_render <command> <korean-title> -> string` — 현재 설치 버전을 찾아 `core/run.sh`를 실행하는 `.command` 본문
  - `step_shortcuts` — `시작/중지/상태/AI연결/업데이트/제거.command` 6개를 생성하고 `chmod +x`. 각 파일은 **매니페스트에서 버전을 읽어** 앱 디렉터리를 찾는다(업데이트 후에도 계속 동작해야 한다)

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_render_selflocating() {
  local out; out="$(shortcut_render status "상태 확인")"
  assert_contains "$out" 'HC_HOME="${HC_HOME:-$HOME/.hermes-paperclip-native}"' "홈 경로"
  assert_contains "$out" 'manifest.env' "매니페스트에서 버전을 읽는다"
  assert_contains "$out" 'run.sh" status' "명령 전달"
}
t_step_creates_files() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"
  mf_set INSTALLER_VERSION 0.1.0
  step_shortcuts
  assert_status 0 $([ -x "$HOME/HermesPaperclip/상태.command" ]; echo $?) "실행 권한 있는 파일 생성"
  assert_eq "6" "$(ls -1 "$HOME/HermesPaperclip" | wc -l | tr -d ' ')" "6개 파일"
}
run_tests t_render_selflocating t_step_creates_files
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_steps_shortcuts.sh`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현한다**

생성되는 파일 본문의 뼈대:
```bash
#!/bin/bash
printf '\033]0;%s\007' "Hermes + Paperclip — 상태 확인"
HC_HOME="${HC_HOME:-$HOME/.hermes-paperclip-native}"
VER="$(sed -n 's/^INSTALLER_VERSION=//p' "$HC_HOME/manifest.env")"
exec "$HC_HOME/app/$VER/core/run.sh" status
```
마지막에 `read -r -p "계속하려면 Enter 키를 누르세요..." _` 를 붙여, 창이 바로 닫히지 않게 한다.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `bash tests/test_steps_shortcuts.sh`
Expected: `pass=2 fail=0`
```bash
git add core/steps/75-shortcuts.sh tests/test_steps_shortcuts.sh
git commit -m "feat(steps): generate self-locating control commands"
```

---

### Task 18: `connect` — AI 연결, 연결 확인, 예산 제안

**Files:**
- Create: `core/steps/connect.sh`, `tests/test_connect.sh`

**Interfaces:**
- Consumes: `p_run`, `p_paperclip_env`, `ui_*`
- Produces:
  - `connect_menu` — 1/2/3 선택을 stdin에서 읽어 `CONNECT_CHOICE`에 저장. 비TTY면 기본값 `3`
  - `connect_run <choice>` — 1이면 `p_run hermes setup --portal`, 2면 `p_run hermes setup`, 3이면 안내만
  - `connect_verify -> 0/1` — `p_run hermes doctor` 성공 여부
  - `connect_budget_prompt` — 1/2/3 선택 후 `budgetMonthlyCents`를 설정. 3이면 아무것도 안 함
  - `cmd_connect` — 위를 순서대로 호출하고 `ui_pause`로 끝난다

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_menu_notty()   { local out; out="$(printf '' | connect_menu)"; assert_eq "3" "$CONNECT_CHOICE" "비TTY 기본값은 3"; }
t_portal_cmd()   { local out; out="$(HC_DRY_RUN=1 connect_run 1)"; assert_contains "$out" "hermes setup --portal" "포털 경로"; }
t_key_cmd()      { local out; out="$(HC_DRY_RUN=1 connect_run 2)"; assert_contains "$out" "hermes setup" "내 키 경로"; }
t_none_silent()  { local out; out="$(HC_DRY_RUN=1 connect_run 3)"; assert_eq "" "$out" "나중에는 아무것도 안 한다"; }
t_budget_skip()  { local out; out="$(HC_DRY_RUN=1 connect_budget_prompt <<< '3' 2>&1)"; assert_contains "$out" "설정하지 않" "예산 건너뛰기 안내"; }
t_budget_set()   { local out; out="$(HC_DRY_RUN=1 connect_budget_prompt <<< '1' 2>&1)"; assert_contains "$out" "3000" "권장 \$30 = 3000 센트"; }
run_tests t_menu_notty t_portal_cmd t_key_cmd t_none_silent t_budget_skip t_budget_set
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_connect.sh`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현한다**

예산은 `paperclipai agent update <id> --payload-json '{"budgetMonthlyCents":3000}'` 로 설정한다. 스펙 10.5절의 한국어 문구를 그대로 쓴다.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `bash tests/test_connect.sh`
Expected: `pass=6 fail=0`
```bash
git add core/steps/connect.sh tests/test_connect.sh
git commit -m "feat(connect): add AI connection, verification, and budget prompt"
```

---

### Task 19: `uninstall` — 제거 (+ 기존 Hermes 보존)

**Files:**
- Create: `core/steps/uninstall.sh`, `tests/test_uninstall.sh`

**Interfaces:**
- Consumes: `mf_get`, `p_autostart_remove`, `p_bin_dir`, `p_node_dir`, `p_data_dir`, `hc_home`, `ui_*`
- Produces:
  - `uninstall_plan -> lines` — 지울 항목을 한국어로 나열 (`^` 접두사로 표시)
  - `step_uninstall [--yes]` — 확인을 받고, `p_autostart_remove` → `paperclipai uninstall` → `uv tool uninstall hermes-agent` → `p_node_dir` → `p_data_dir` → `hc_home` → `~/HermesPaperclip` 순으로 삭제. `HERMES_EXISTED=true`면 `~/.hermes`를 **삭제하지 않고** 그 사실을 알린다

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_plan_lists()      { local out; out="$(uninstall_plan)"; assert_contains "$out" "paperclip"; assert_contains "$out" "Hermes"; assert_contains "$out" "로그"; }
t_preserves_hermes() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"
  mkdir -p "$HOME/.hermes" "$HOME/.local/node" "$HOME/.paperclip"
  mf_set HERMES_EXISTED true
  HC_SKIP_AUTOSTART=1 step_uninstall --yes >/dev/null 2>&1
  assert_status 0 $([ -d "$HOME/.hermes" ]; echo $?) "기존 Hermes 는 남는다"
}
t_removes_ours() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"
  mkdir -p "$HOME/.local/node" "$HOME/.paperclip" "$HC_HOME"
  mf_set HERMES_EXISTED false
  HC_SKIP_AUTOSTART=1 step_uninstall --yes >/dev/null 2>&1
  assert_status 1 $([ -d "$HOME/.paperclip" ]; echo $?) "우리 데이터는 지운다"
  assert_status 1 $([ -d "$HC_HOME" ]; echo $?) "설치 상태도 지운다"
}
run_tests t_plan_lists t_preserves_hermes t_removes_ours
```
`t_plan_lists`는 `assert_contains`에 label 인자를 넘기도록 수정해 3개 단언을 각각 라벨과 함께 쓴다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_uninstall.sh`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현한다**

**Review Focus 2**가 이 태스크의 핵심이다. `HERMES_EXISTED=true`일 때 `~/.hermes`를 절대 건드리지 않고, 사용자에게 "원래 있던 Hermes는 그대로 두었습니다"를 한국어로 알린다. `--yes`가 없으면 `ui_pause` 전에 `정말 제거할까요? (y/N)` 을 묻는다.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `bash tests/test_uninstall.sh`
Expected: `pass=5 fail=0`
```bash
git add core/steps/uninstall.sh tests/test_uninstall.sh
git commit -m "feat(uninstall): remove our install while preserving existing Hermes"
```

---

### Task 20: `update` — 자체 + Paperclip + Hermes 갱신, 실패 시 롤백

**Files:**
- Create: `core/steps/update.sh`, `tests/test_update.sh`

**Interfaces:**
- Consumes: `hc_home`, `hc_version`, `mf_*`, `ft_*`, `p_run`, `p_autostart_install`
- Produces:
  - `update_latest_version -> string` — `HC_LATEST_VERSION` 환경변수(테스트용) 또는 릴리스의 `VERSION` 파일
  - `update_should_run -> 0/1` — 최신 버전이 현재와 같으면 1
  - `step_update` — 새 버전을 `$(hc_home)/app/<ver>/`에 설치하고, `paperclipai update` + `hermes update` 실행, 자동 시작 재시작, 헬스 확인. 실패하면 이전 버전으로 되돌리고 실패를 보고
  - `update_rollback <old-version>` — 매니페스트의 `INSTALLER_VERSION`을 되돌린다 (이전 `app/<old>/`는 남겨 둔다)

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_should_run_yes() { HC_LATEST_VERSION=0.2.0 mf_set INSTALLER_VERSION 0.1.0; assert_status 0 $(update_should_run; echo $?) "새 버전이면 실행"; }
t_should_run_no()  { HC_LATEST_VERSION=0.1.0 mf_set INSTALLER_VERSION 0.1.0; assert_status 1 $(update_should_run; echo $?) "같으면 건너뛴다"; }
t_rollback()       { mf_set INSTALLER_VERSION 0.2.0; update_rollback 0.1.0; assert_eq "0.1.0" "$(mf_get INSTALLER_VERSION)" "롤백이 버전을 되돌린다"; }
run_tests t_should_run_yes t_should_run_no t_rollback
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_update.sh`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현한다**

성공 시 `app/<old>/`를 지우지 않는다(롤백 여지). 매니페스트 갱신은 **모든 단계가 성공한 뒤 마지막에** 한다.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `bash tests/test_update.sh`
Expected: `pass=3 fail=0`
```bash
git add core/steps/update.sh tests/test_update.sh
git commit -m "feat(update): self-update with rollback"
```

---

### Task 21: 진입점 — `bootstrap.sh`, `설치.command`, `사용방법.html`

**Files:**
- Create: `entry/bootstrap.sh`, `entry/설치.command`, `entry/사용방법.html`, `tests/test_entry.sh`

**Interfaces:**
- Consumes: `hc_*`, `ft_*`, `p_*`
- Produces:
  - `bootstrap_main <command>` — `HC_SOURCE_DIR`가 설정되면 그 로컬 체크아웃의 `core/run.sh`를 바로 실행. 아니면 릴리스 `VERSION` 확인 → `hermes-paperclip-<ver>.zip` + `checksums.txt` 다운로드 → `ft_verify` → `$(hc_app_root)/<ver>/`에 해제 → `core/run.sh <command>` 실행
  - `설치.command` — `exec "$(dirname "$0")/bootstrap.sh" install`

- [ ] **Step 1: Gatekeeper 동작을 실측한다 (스펙 17절 리스크 1, 최우선)**

더블클릭 경로가 실제로 열리는지 확인한다. 인터넷에서 받은 파일과 같은 상태를 `xattr`로 만든다.

```bash
cd "$(mktemp -d)"
printf '#!/bin/bash\necho 열렸습니다\nread -r -p "Enter..." _\n' > 테스트.command
chmod +x 테스트.command
xattr -w com.apple.quarantine "0081;00000000;Safari;$(uuidgen)" 테스트.command
open 테스트.command
```

Expected: macOS가 경고 창을 띄우고, **우클릭 → 열기** 경로가 있는지 확인한다.
- 우클릭→열기가 **통하면**: `entry/사용방법.html`을 그 흐름의 스크린샷으로 작성한다.
- 우클릭→열기가 **막히면**: 더블클릭을 주 진입점으로 쓰지 않고, 한 줄 명령을 기본으로 안내하도록 `사용방법.html`을 고친다. 이 결정을 `docs/architecture.md`에 한 줄로 기록한다.

- [ ] **Step 2: 실패 테스트를 쓴다**

```bash
t_source_dir() {
  export HC_SOURCE_DIR="$HERE/.." HC_HOME="$(mktemp -d)" HC_SKIP_AUTOSTART=1 HC_SKIP_OPEN=1 HC_NO_COLOR=1
  local out; out="$(HC_DRY_RUN=1 bash "$HERE/../entry/bootstrap.sh" status 2>&1)"
  assert_contains "$out" "status" "로컬 체크아웃에서는 run.sh 로 넘긴다"
}
t_release_plan() {
  export HC_HOME="$(mktemp -d)" HC_LATEST_VERSION=0.1.0
  local out; out="$(HC_DRY_RUN=1 bootstrap_plan 2>&1)"
  assert_contains "$out" "hermes-paperclip-0.1.0.zip" "zip 이름"
  assert_contains "$out" "checksums.txt" "체크섬 파일"
}
run_tests t_source_dir t_release_plan
```

- [ ] **Step 3: 실패를 확인한다**

Run: `bash tests/test_entry.sh`
Expected: FAIL — 파일 없음

- [ ] **Step 4: 구현한다**

`bootstrap.sh`는 `#!/usr/bin/env bash`, `set -uo pipefail`, `HC_HOME`을 명시적으로 넘긴다. `checksums.txt`는 `<sha256>  <filename>` 형식으로 가정하고, 자기 파일의 해시와 맞는 줄을 `grep`으로 찾는다.

`entry/사용방법.html`은 다음 순서를 스크린샷 자리표시자와 함께 담는다: 1) 압축 풀기 2) `설치.command` **우클릭 → 열기** 3) 경고 창에서 **열기** 클릭 4) 진행이 끝날 때까지 창을 닫지 않기 5) 브라우저 자동 열림. 스크린샷은 실제 재현 후 캡처해 `entry/img/`에 넣는다(이 태스크에서는 자리표시자 `TODO: 스크린샷`).

- [ ] **Step 5: 통과를 확인하고 커밋한다**

Run: `bash tests/test_entry.sh`
Expected: `pass=2 fail=0`
```bash
git add entry/ tests/test_entry.sh
git commit -m "feat(entry): add bootstrap, double-click entry, and how-to page"
```

---

### Task 22: E2E 스모크 테스트 (가짜 HOME)

**Files:**
- Create: `tests/smoke.sh`, `tests/test_smoke_shape.sh`

**Interfaces:**
- Consumes: `entry/bootstrap.sh` 전체
- Produces: `tests/smoke.sh` — 가짜 `HOME`에서 실제 설치를 수행하고, 멱등성과 제거를 검증한다. `HC_SMOKE_REAL=1`이 아니면 네트워크가 필요한 단계(2~5)를 `HC_DRY_RUN=1`로 돌린다

**검증 항목**: 설치 성공 → 두 번째 실행이 전부 skip → 업데이트가 롤백 없이 통과 → 제거 후 홈에 잔여물 0 (`~/.hermes`는 보존)

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_smoke_shape.sh` — 스모크 스크립트 자체의 계약을 검사한다.
```bash
t_smoke_exists()   { assert_status 0 $([ -x "$HERE/../tests/smoke.sh" ]; echo $?) "smoke.sh 실행 가능"; }
t_smoke_fakehome() { assert_contains "$(cat "$HERE/../tests/smoke.sh")" "HC_HOME=" "가짜 HOME 을 쓴다"; }
t_smoke_never_real_home() {
  if grep -qE 'rm -rf "?\$HOME"?[^/]' "$HERE/../tests/smoke.sh"; then assert_eq "unsafe" "found" "실제 HOME 을 지우면 안 된다"; else assert_eq "ok" "ok" "실제 HOME 삭제 없음"; fi
}
run_tests t_smoke_exists t_smoke_fakehome t_smoke_never_real_home
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_smoke_shape.sh`
Expected: FAIL — `tests/smoke.sh` 없음

- [ ] **Step 3: 구현한다**

`tests/smoke.sh`는 다음을 순서대로 하고, 각 단계에서 실패하면 그 사실을 한국어로 출력하고 exit 1 한다. `trap`으로 종료 시 임시 디렉터리를 정리한다.

- [ ] **Step 4: 로컬에서 실제 스모크를 돌린다**

Run: `HC_SMOKE_REAL=1 bash tests/smoke.sh`
Expected: `SMOKE OK` — 실제로 Node/Paperclip/Hermes가 임시 홈에 설치되고, 두 번째 실행이 전부 skip되고, 제거 후 잔여물이 없다. **이 Mac에서 통과해야 P1이 끝난다.**

- [ ] **Step 5: 커밋**

```bash
git add tests/smoke.sh tests/test_smoke_shape.sh
git commit -m "test: add end-to-end smoke test in a fake HOME"
```

---

### Task 23: CI (macOS 잡)

**Files:**
- Create: `.github/workflows/ci.yml`, `tests/test_ci_shape.sh`

**Interfaces:**
- Consumes: `make test`, `tests/smoke.sh`
- Produces: GitHub Actions 워크플로 — `macos-latest`에서 `make test`와 `bash tests/smoke.sh`(가짜 HOME, `HC_SKIP_AUTOSTART=1`, `HC_SKIP_OPEN=1`) 실행

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_ci_shape.sh` — 워크플로가 실제로 테스트를 돌리는지 검사한다(워크플로 파일은 실행할 수 없으므로 내용 계약을 검사한다).
```bash
t_ci_exists()  { assert_status 0 $([ -f "$HERE/../.github/workflows/ci.yml" ]; echo $?) "워크플로 존재"; }
t_ci_macos()   { assert_contains "$(cat "$HERE/../.github/workflows/ci.yml")" "macos-latest" "macOS 러너"; }
t_ci_test()    { assert_contains "$(cat "$HERE/../.github/workflows/ci.yml")" "make test" "단위 테스트 실행"; }
t_ci_smoke()   { assert_contains "$(cat "$HERE/../.github/workflows/ci.yml")" "tests/smoke.sh" "스모크 실행"; }
t_ci_nostart() { assert_contains "$(cat "$HERE/../.github/workflows/ci.yml")" "HC_SKIP_AUTOSTART" "CI 에서 자동 시작을 끈다"; }
run_tests t_ci_exists t_ci_macos t_ci_test t_ci_smoke t_ci_nostart
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_ci_shape.sh`
Expected: FAIL — 워크플로 없음

- [ ] **Step 3: 구현한다**

워크플로는 `push`와 `pull_request`에서 실행한다. 스모크가 실패하면 로그 디렉터리를 아티팩트로 업로드한다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash tests/test_ci_shape.sh && make test`
Expected: `pass=5 fail=0` 그리고 전체 단위 테스트 통과

- [ ] **Step 5: 커밋**

```bash
git add .github/workflows/ci.yml tests/test_ci_shape.sh
git commit -m "ci: run unit tests and smoke test on macOS"
```

---

## P1 완료 조건

- `make test`가 모든 단위 테스트를 통과한다.
- `HC_SMOKE_REAL=1 bash tests/smoke.sh`가 **이 Mac에서** 통과한다 (실제 설치 → 멱등 확인 → 업데이트 → 제거).
- `dist/`가 아니라 저장소에서 `entry/설치.command`를 더블클릭했을 때 실제로 설치가 끝나고 브라우저가 열린다.
- P1이 끝나면 **P2(Linux) 계획을 새로 쓴다.** 이 계획에 Linux 작업을 덧붙이지 않는다.
