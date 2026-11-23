# P2: Linux 지원 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 같은 설치기가 Linux에서도 동작하게 한다 — 한 줄 명령으로 Node·Paperclip·Hermes를 무sudo로 설치하고, systemd user 서비스로 자동 시작하고, (헤드리스면 URL만 출력하며) 동작한다.

**Architecture:** 현재 `platform/macos.sh`에 OS 중립 코드와 macOS 전용 코드가 섞여 있다. 먼저 중립 부분(`p_run`, `p_activate_tools`, uv/Hermes/Paperclip 설치, Node 설치 골격)을 `platform/common.sh`로 추출하고, `platform/macos.sh`와 `platform/linux.sh`는 정말 OS별인 것만 남긴다. `core/`는 `p_*` 인터페이스만 알면 되므로 **코어 수정은 거의 없다.**

**Tech Stack:** Bash 3.2 호환(sh), systemd user 유닛 + `loginctl enable-linger`, `xdg-open`, Node 공식 `linux-x64`/`linux-arm64` tarball, uv, `paperclipai`, `hermes-agent`

**Spec:** `docs/superpowers/specs/2026-11-23-hermes-paperclip-cross-platform-installer-design.md` (8절 Linux 열, 15절 P2)

## Global Constraints

P1의 Global Constraints를 전부 물려받는다(sudo 금지, Bash 3.2 호환, 한국어 문구, 경로 따옴표, `PAPERCLIP_HOME` export, `pins.env` 단일 버전 원천, `HC_*` 스위치). 추가:

- **`core/` 에 OS 이름을 쓰지 않는다.** `linux`, `systemd`, `xdg-open` 같은 단어는 `platform/` 에만 있어야 한다.
- **Linux 1차 지원 대상: Ubuntu 22.04+/Debian 12+ 계열** (systemd + glibc 2.35+). 그 외는 "지원하지 않음"을 한국어로 알리고 중단한다.
- **root 로 실행하지 않는다.** `id -u` 가 0이면 중단하고 이유를 알린다(`/root` 에 설치하면 일반 사용자가 못 쓴다).
- **헤드리스에서 브라우저 열기 실패는 오류가 아니다.** URL 을 출력하고 계속한다.
- systemd 가 없거나 linger 를 켤 수 없으면 **백그라운드 러너(`p_server_start_bg`)로 폴백**한다(이미 구현됨).

## Review Focus

스펙이 명시하지 않았지만 실제 사용자에게 물릴 것이 확실한 입력/상황들이다. 각 항목은 지정된 태스크의 테스트로 고정한다.

1. **컨테이너/WSL 처럼 systemd user 가 없는 환경.** `systemctl --user` 가 실패하는데 설치가 죽으면 안 된다. → Task 4
2. **`xdg-open` 이 없는 헤드리스 서버.** 브라우저를 못 여는 것이 설치 실패가 되면 안 된다. → Task 2
3. **`~/.bashrc` 만 고치는 PATH 등록.** 비대화형/비로그인 셸(예: `ssh host 'paperclipai ...'`)에서 PATH 가 없으면 "설치했는데 명령이 없다"가 된다. → Task 3
4. **root 실행.** `/root` 에 설치되어 아무도 못 쓰게 되는 경우. → Task 2
5. **낮은 glibc 배포판(예: Ubuntu 20.04).** Node 24 의 최소 요구를 못 맞추는데 설치가 진행되면 알 수 없는 오류로 죽는다. → Task 2

---

## File Structure

| 파일 | 책임 |
|---|---|
| `platform/common.sh` (신규) | OS 중립: `p_run`, `p_activate_tools`, `p_uv_present`/`p_install_uv`, `p_hermes_present`/`p_install_hermes`, `p_paperclip_present`/`p_paperclip_env`/`p_install_paperclip`, `p_version_num`, `p_server_pidfile`/`p_server_running`/`p_server_start_bg`/`p_server_stop_bg`, `p_node_present`, `p_install_node`(URL·경로는 `p_node_archive_url`/`p_node_dir` 에 위임) |
| `platform/macos.sh` (수정) | macOS 전용만: `p_detect`, `p_bin_dir`, `p_node_dir`, `p_data_dir`, `p_has_display`, `p_node_archive_url`(darwin), `p_server_url`, `p_open_browser`, `p_tail_log`, `p_persist_path`, `p_autostart_*` |
| `platform/linux.sh` (신규) | Linux 전용: 위와 같은 이름의 OS별 구현 |
| `core/lib.sh` (수정) | `hc_load_platform` 이 `platform/common.sh` 를 먼저 로드하고, 그다음 `platform/<os>.sh` 를 로드 |
| `tests/test_platform_linux.sh` (신규) | Linux 구현 테스트 (ubuntu CI 에서 실행) |
| `tests/test_platform_common.sh` (신규) | 추출된 공통 함수 테스트 |
| `.github/workflows/ci.yml` (수정) | ubuntu 잡 추가 |
| `docs/linux.md` (신규) | Linux 사용자 안내 |

**P1 파일은 그대로 둔다.** `platform/macos.sh` 는 계속 같은 이름의 함수를 제공하므로 `core/` 는 바뀌지 않는다.

---

### Task 1: `platform/common.sh` 추출 (동작 변화 없음)

**Files:**
- Create: `platform/common.sh`
- Modify: `platform/macos.sh`, `core/lib.sh`
- Create: `tests/test_platform_common.sh`

**Interfaces:**
- Consumes: `hc_*`
- Produces: `platform/common.sh` 가 다음을 정의한다 — `p_run`, `p_activate_tools`, `p_version_num`, `p_node_present`, `p_install_node`, `p_uv_present`, `p_install_uv`, `p_hermes_present`, `p_install_hermes`, `p_paperclip_present`, `p_paperclip_env`, `p_install_paperclip`, `p_server_pidfile`, `p_server_running`, `p_server_start_bg`, `p_server_stop_bg`. `hc_load_platform` 은 `platform/common.sh` → `platform/<os>.sh` 순서로 로드한다.

**회귀 가드**: P1의 기존 테스트 104개가 그대로 통과해야 한다. 이 태스크는 **순수 이동**이다 — 동작을 바꾸지 않는다.

- [ ] **Step 1: 공통 함수 목록을 테스트로 고정한다**

`tests/test_platform_common.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../platform/common.sh"
export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)" HC_NO_COLOR=1

t_common_defines() {
  local fn
  for fn in p_run p_activate_tools p_version_num p_node_present p_install_node \
            p_uv_present p_install_uv p_hermes_present p_install_hermes \
            p_paperclip_present p_paperclip_env p_install_paperclip \
            p_server_pidfile p_server_running p_server_start_bg p_server_stop_bg; do
    assert_status 0 "$(type -t "$fn" >/dev/null 2>&1; echo $?)" "common 에 $fn 이 있다"
  done
}
t_common_has_no_os_words() {
  local out; out="$(grep -nE 'launchctl|sw_vers|systemctl|xdg-open|/Library/' "$HERE/../platform/common.sh" || true)"
  assert_eq "" "$out" "common.sh 에 OS 전용 단어가 없다"
}
t_macos_keeps_os_only() {
  local fn
  for fn in p_detect p_node_archive_url p_open_browser p_persist_path p_autostart_install; do
    assert_status 0 "$(bash -c '. '"$HERE"'/../core/lib.sh; . '"$HERE"'/../platform/macos.sh; type -t '"$fn"' >/dev/null 2>&1; echo $?')" "macos 에 $fn 이 있다"
  done
}
run_tests t_common_defines t_common_has_no_os_words t_macos_keeps_os_only
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_platform_common.sh`
Expected: FAIL — `platform/common.sh: No such file or directory`

- [ ] **Step 3: 함수를 옮긴다**

`platform/macos.sh` 에서 위 목록의 함수 정의를 **그대로 잘라내어** `platform/common.sh` 로 옮긴다. `platform/common.sh` 는 `#!/usr/bin/env bash` 로 시작한다. `hc_load_platform` 을 고친다:
```bash
hc_load_platform() {
  local root common os
  root="$(hc_root)"
  common="$root/platform/common.sh"
  os="$root/platform/$(hc_os).sh"
  [ -f "$common" ] && . "$common"
  [ -f "$os" ] || hc_die "이 운영체제($(hc_os))는 아직 지원하지 않습니다."
  . "$os"
}
```

- [ ] **Step 4: 회귀와 새 테스트를 확인한다**

Run: `make test`
Expected: 모든 테스트 파일 통과 (104 + 3)

- [ ] **Step 5: 커밋**

```bash
git add platform/common.sh platform/macos.sh core/lib.sh tests/test_platform_common.sh
git commit -m "refactor(platform): extract OS-neutral functions into common.sh"
```

---

### Task 2: `platform/linux.sh` — 감지·경로·브라우저·디스플레이·로그

**Files:**
- Create: `platform/linux.sh`, `tests/test_platform_linux.sh`

**Interfaces:**
- Produces: `p_detect`(P_OS/P_ARCH/P_OS_VERSION/`P_DISTRO`), `p_bin_dir`, `p_node_dir`, `p_data_dir`, `p_app_dir`, `p_has_display`, `p_require_supported`(root·glibc·systemd 여부를 한국어로 판정 — 실패 시 `hc_die`), `p_node_archive_url`, `p_server_url`, `p_open_browser`, `p_tail_log`

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_platform_linux.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../platform/common.sh"
. "$HERE/../platform/linux.sh"
export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)" HC_NO_COLOR=1

t_detect()      { p_detect; assert_eq "linux" "$P_OS" "OS"; assert_contains "arm64 x64" "$P_ARCH" "아키텍처"; }
t_paths()       { assert_eq "$HOME/.local/bin" "$(p_bin_dir)" "bin"; assert_eq "$HOME/.paperclip" "$(p_data_dir)" "data"; }
t_node_url_x64()   { assert_eq "https://nodejs.org/dist/v24.20.0/node-v24.20.0-linux-x64.tar.gz"   "$(P_ARCH=x64   p_node_archive_url 24.20.0)" "x64 URL"; }
t_node_url_arm64() { assert_eq "https://nodejs.org/dist/v24.20.0/node-v24.20.0-linux-arm64.tar.gz" "$(P_ARCH=arm64 p_node_archive_url 24.20.0)" "arm64 URL"; }
t_url_default() { assert_eq "http://127.0.0.1:3100" "$(p_server_url)" "기본 포트"; }
t_headless()    { DISPLAY= WAYLAND_DISPLAY= p_has_display; assert_status 1 $? "DISPLAY 가 없으면 헤드리스"; }
t_display()     { DISPLAY=:0 p_has_display; assert_status 0 $? "DISPLAY 가 있으면 GUI"; }
t_open_no_xdg() {
  PATH="/nonexistent" p_open_browser "http://x" >/dev/null 2>&1
  assert_status 1 $? "xdg-open 이 없으면 실패를 반환한다(죽지 않는다)"
}
run_tests t_detect t_paths t_node_url_x64 t_node_url_arm64 t_url_default t_headless t_display t_open_no_xdg
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_platform_linux.sh`
Expected: FAIL — `platform/linux.sh: No such file or directory`

- [ ] **Step 3: 구현한다**

`p_detect` 는 `uname -m` 과 `/etc/os-release` 의 `ID`/`VERSION_ID` 를 읽는다. `p_require_supported` 는 (a) `id -u` 가 0이면 중단, (b) `ldd --version` 에서 glibc 2.35 미만이면 중단, (c) `command -v systemctl` 이 없으면 **중단하지 않고 경고만** 한다(Task 4에서 폴백). `p_has_display` 는 `DISPLAY` 또는 `WAYLAND_DISPLAY` 가 비어 있지 않으면 0. `p_open_browser` 는 `xdg-open` 이 없으면 1을 반환한다(**죽지 않는다**).

- [ ] **Step 3b: `p_require_supported` 를 실제로 호출한다**

정의만 하고 아무도 부르지 않으면 죽은 코드다. `core/steps/10-preflight.sh` 의 앞부분에 **선택적 호출**을 넣는다(macOS 에는 이 함수가 없으므로 가드가 필요하다):

```bash
  # 플랫폼이 자체 지원 판정을 제공하면 먼저 실행한다(Linux 는 root/glibc 를 본다).
  if command -v p_require_supported >/dev/null 2>&1; then
    p_require_supported
  fi
```

`tests/test_steps_early.sh` 에 테스트 두 개를 추가한다 — 플랫폼이 판정을 **제공하지 않는** 환경(macOS)에서도 사전 점검이 정상 동작해야 한다는 것과, 제공하면 실제로 호출된다는 것을 고정한다:

```bash
t_preflight_without_require() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  unset -f p_require_supported 2>/dev/null || true
  HC_SKIP_NETWORK=1 step_preflight
  assert_status 0 $? "플랫폼 지원 판정이 없어도 사전 점검은 동작한다"
}
t_preflight_calls_require() {
  export HC_HOME="$(mktemp -d)" HOME="$(mktemp -d)"; p_detect
  p_require_supported() { printf 'CALLED'; return 0; }
  local out; out="$(HC_SKIP_NETWORK=1 step_preflight 2>&1)" || true
  assert_eq "CALLED" "$out" "지원 판정이 있으면 호출한다"
}
```
`run_tests` 줄에 두 테스트를 추가한다.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `bash tests/test_platform_linux.sh`
Expected: `pass=8 fail=0`
```bash
git add platform/linux.sh core/steps/10-preflight.sh tests/test_platform_linux.sh tests/test_steps_early.sh
git commit -m "feat(linux): add detection, paths, display, browser, and platform gate"
```

---

### Task 3: `platform/linux.sh` — Node 설치와 PATH 등록

**Files:**
- Modify: `platform/linux.sh`, `tests/test_platform_linux.sh`

**Interfaces:**
- Produces: `p_install_node`(common 재사용, linux URL 사용), `p_persist_path`

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_persist_profile() {
  export HOME="$(mktemp -d)"; : > "$HOME/.bashrc"; : > "$HOME/.profile"
  p_persist_path; p_persist_path
  assert_eq "1" "$(grep -c 'hermes-paperclip' "$HOME/.profile")" "profile 에 한 번만"
  assert_contains "$(cat "$HOME/.bashrc")" '.local/bin' "bashrc 에도 넣는다(비대화형 셸)"
}
t_persist_idempotent() {
  export HOME="$(mktemp -d)"; : > "$HOME/.profile"; : > "$HOME/.bashrc"
  p_persist_path; p_persist_path; p_persist_path
  assert_eq "1" "$(grep -c 'hermes-paperclip' "$HOME/.profile")" "여러 번 실행해도 한 번만"
}
run_tests ... t_persist_profile t_persist_idempotent
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_platform_linux.sh`
Expected: FAIL — `p_persist_path: command not found`

- [ ] **Step 3: 구현한다**

마커는 macOS와 같은 한 줄 `# hermes-paperclip: PATH` 를 쓴다. **`~/.profile` 과 `~/.bashrc` 둘 다**에 넣는다 — `~/.profile` 은 로그인 셸, `~/.bashrc` 는 비대화형 셸(`ssh host '명령'`)을 담당한다. 이미 있으면 건너뛴다.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `bash tests/test_platform_linux.sh`
Expected: `pass=10 fail=0`
```bash
git add platform/linux.sh tests/test_platform_linux.sh
git commit -m "feat(linux): persist PATH in both profile and bashrc"
```

---

### Task 4: `platform/linux.sh` — 자동 시작 (systemd user + 폴백)

**Files:**
- Modify: `platform/linux.sh`, `tests/test_platform_linux.sh`

**Interfaces:**
- Produces: `p_autostart_available`(systemd user 사용 가능 여부), `p_autostart_label`(`hermes-paperclip`), `p_autostart_unit`(`~/.config/systemd/user/hermes-paperclip.service`), `p_autostart_render`, `p_autostart_install`, `p_autostart_remove`, `p_autostart_status`

- [ ] **Step 1: 실패 테스트를 쓴다**

```bash
t_unit_render() {
  local out; out="$(p_autostart_render)"
  assert_contains "$out" "ExecStart=$HOME/.local/bin/paperclipai run" "실행 명령"
  assert_contains "$out" "Environment=" "환경변수(PATH/HOME)"
  assert_contains "$out" "$HOME/.local/bin" "PATH 에 bin 포함"
  assert_contains "$out" "Restart=on-failure" "재시작 정책"
}
t_unit_no_placeholder() {
  local out; out="$(p_autostart_render)"
  assert_contains "$out" "[Unit]" "유닛 본문이 나온다"
  if printf '%s' "$out" | grep -q '@@'; then assert_eq "no-placeholder" "found" "@@ 치환 완료"; else assert_eq "ok" "ok" "@@ 치환 완료"; fi
}
t_status_absent() { export HOME="$(mktemp -d)"; assert_eq "absent" "$(p_autostart_status)" "유닛 파일이 없으면 absent"; }
run_tests ... t_unit_render t_unit_no_placeholder t_status_absent
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_platform_linux.sh`
Expected: FAIL — 파일/함수 없음

- [ ] **Step 3: `platform/hermes-paperclip.service.template` 과 함수를 구현한다**

```ini
[Unit]
Description=Hermes + Paperclip
After=network-online.target

[Service]
Type=simple
ExecStart=@@PAPERCLIP@@ run
Environment=HOME=@@HOME@@
Environment=PATH=@@PATH@@
Environment=PAPERCLIP_HOME=@@DATA_DIR@@
Restart=on-failure
RestartSec=5
StandardOutput=append:@@LOG@@
StandardError=append:@@LOG_ERR@@
KillMode=mixed

[Install]
WantedBy=default.target
```
`p_autostart_install` 은 유닛을 쓴 뒤 `systemctl --user daemon-reload` → `systemctl --user enable --now hermes-paperclip.service` → `loginctl enable-linger "$USER"`(실패해도 경고만). **systemd user 를 쓸 수 없으면(`p_autostart_available` 이 1) `systemctl` 을 호출하지 않고 1을 반환**한다 — 호출자(`step_autostart`)가 백그라운드 러너로 폴백한다(Review Focus 1).

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `bash tests/test_platform_linux.sh`
Expected: `pass=13 fail=0`
```bash
git add platform/linux.sh platform/hermes-paperclip.service.template tests/test_platform_linux.sh
git commit -m "feat(linux): systemd user autostart with background fallback"
```

---

### Task 5: CI 에 ubuntu 잡 추가

**Files:**
- Modify: `.github/workflows/ci.yml`, `tests/test_ci_shape.sh`

**Interfaces:**
- Consumes: `make test`, `tests/smoke.sh`
- Produces: `ubuntu-latest` 잡 — 리눅스 전용 테스트가 실제로 도는 곳

- [ ] **Step 1: 실패 테스트를 쓴다**

`tests/test_ci_shape.sh` 에 추가:
```bash
t_ci_ubuntu()      { assert_contains "$(cat "$CI" 2>/dev/null)" "ubuntu-latest" "ubuntu 러너"; }
t_ci_linux_tests() { assert_contains "$(cat "$CI" 2>/dev/null)" "test_platform_linux.sh" "리눅스 전용 테스트 실행"; }
```
`run_tests` 에 `t_ci_ubuntu t_ci_linux_tests` 를 추가한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_ci_shape.sh`
Expected: FAIL — `ubuntu-latest` 를 찾지 못함

- [ ] **Step 3: 워크플로를 수정한다**

`test-linux` 잡을 추가한다: `runs-on: ubuntu-latest`, `make test`, `HC_SKIP_AUTOSTART=1 HC_SKIP_OPEN=1 bash tests/smoke.sh`. **`test_platform_macos.sh` 는 리눅스에서 실행되지 않아야 한다** — `tests/run.sh` 가 OS별 파일을 건너뛰도록, 파일 상단에서 `hc_os` 를 확인해 다르면 `exit 0` 하게 한다(두 플랫폼 테스트 파일 공통).

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `bash tests/test_ci_shape.sh && make test`
Expected: 통과
```bash
git add .github/workflows/ci.yml tests/test_ci_shape.sh tests/test_platform_macos.sh tests/test_platform_linux.sh tests/run.sh
git commit -m "ci: run Linux tests and smoke on ubuntu-latest"
```

---

### Task 6: 실제 Linux 스모크

**Files:**
- Modify: `tests/smoke.sh`(필요 시), `docs/architecture.md`

**Interfaces:**
- Consumes: P1의 `tests/smoke.sh` 전체
- Produces: 우분투에서 통과한 실제 스모크 기록

- [ ] **Step 1: ubuntu 에서 실제 스모크를 돌린다**

Run: `HC_SMOKE_REAL=1 bash tests/smoke.sh`
Expected: `SMOKE OK` — 설치 → 시드 확인 → 멱등 → 업데이트 → 제거.
**macOS 전용 가정이 드러나면 고친다.** 특히 `platform/macos.sh` 를 직접 참조하는 곳, `open` 명령, `shasum`(리눅스에는 `sha256sum`), `df -g`(리눅스는 `-g` 없음)를 확인한다.

- [ ] **Step 2: 발견한 차이를 `docs/architecture.md` 에 기록한다**

- [ ] **Step 3: 커밋**

```bash
git add -A
git commit -m "fix(linux): make the end-to-end smoke pass on ubuntu"
```

---

### Task 7: Linux 사용자 안내

**Files:**
- Create: `docs/linux.md`
- Modify: `entry/사용방법.html`(Linux 절 추가), `README.md`

**Interfaces:**
- Produces: 사용자가 따라 할 수 있는 한국어 안내

- [ ] **Step 1: 안내를 쓴다**

반드시 포함할 것: (a) 한 줄 설치 명령, (b) 서버(헤드리스)에서는 브라우저가 안 열리고 URL만 나온다는 설명, (c) `systemctl --user status hermes-paperclip` 로 상태 보는 법, (d) 제거 방법, (e) 지원 배포판(Ubuntu 22.04+/Debian 12+)과 그 외에서는 중단된다는 사실.

- [ ] **Step 2: 확인하고 커밋한다**

Run: `bash -n entry/bootstrap.sh && make test`
Expected: 통과
```bash
git add docs/linux.md entry/사용방법.html README.md
git commit -m "docs: add Linux installation guide"
```

---

## P2 완료 조건

- `make test` 가 통과한다(macOS 로컬 + ubuntu CI 양쪽).
- **ubuntu-latest 에서 `HC_SMOKE_REAL=1 bash tests/smoke.sh` 가 통과**한다 — 이게 P2의 진짜 완료 조건이다.
- 헤드리스 우분투에서 설치가 끝나고 URL 이 출력된다(브라우저 열기 실패가 오류가 아니다).
- systemd user 가 없는 환경(컨테이너)에서 백그라운드 러너로 폴백해 시드까지 동작한다.
- P2가 끝나면 **P3(Windows) 계획을 새로 쓴다.**
