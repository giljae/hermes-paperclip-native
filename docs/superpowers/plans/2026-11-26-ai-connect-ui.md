# AI 연결 UI (Hermes 대시보드) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 설치기의 `AI연결`이 터미널 위저드 대신 Hermes 웹 대시보드(127.0.0.1:9119, `/models`·`/config`)를 띄워 브라우저로 연다. 실패하면 URL을 출력하고, 그래도 실패하면 기존 `hermes setup`으로 폴백한다.

**Architecture:** 대시보드 시작/확인 로직은 OS 중립(`platform/common.sh`, `win/platform.ps1`)에 두고, `AI연결` 명령(`core/steps/connect.sh`, `win/commands.ps1`)이 그것을 호출해 브라우저를 연다. 브라우저 열기는 기존 `p_open_browser`/`Open-HcBrowser`를 재사용한다.

**Tech Stack:** Bash 3.2(셸), Windows PowerShell 5.1, `hermes dashboard`, `curl`/`Invoke-WebRequest`, 기존 테스트 하네스(`tests/helpers.sh`, `tests/win/run.ps1`).

**Spec:** `docs/superpowers/specs/2026-11-26-ai-connect-ui-design.md`

## Global Constraints

- **sudo 금지, 사용자 범위**(`~/.hermes-paperclip-native`, `~/.paperclip`)만 쓴다.
- **Bash 3.2 호환**: `declare -A`/`mapfile`/`${var^^}`/`[[ -v ]]` 금지.
- **PowerShell 5.1**: 7+ 전용 문법 금지. `.ps1`은 **UTF-8 BOM**.
- **모든 사용자 문구는 한국어**, 경로는 항상 인용.
- 대시보드 URL 기본값은 `http://127.0.0.1:9119` (`p_hermes_dashboard_url` 한 곳에서만 정의).
- `HC_DRY_RUN`이면 실제로 시작/네트워크하지 않고 명령만 출력한다. 비TTY에서 멈추면 안 된다.
- `HC_SKIP_OPEN`이면 브라우저를 열지 않고 URL만 출력한다.
- 테스트는 `HC_HOME`을 임시로 덮어 실제 홈을 건드리지 않는다.

## Review Focus

1. **헤드리스/브라우저 없음** — `p_has_display`가 false거나 `open`/`xdg-open`이 실패해도 죽지 않고 URL을 출력해야 한다. → Task 1, Task 2
2. **대시보드 시작 실패**(hermes 미설치/포트 충돌/빌드 실패) — `hermes setup`으로 폴백하고 멈추지 않는다. → Task 1, Task 2
3. **비TTY/`HC_DRY_RUN`** — 프롬프트로 멈추지 않는다(`ui_pause`가 no-op). → Task 1, Task 2
4. **이미 떠 있는 대시보드** — 두 번 시작하지 않는다(URL 응답으로 판단). → Task 1, Task 2
5. **`HC_SKIP_OPEN`** — 브라우저를 열지 않는다. → Task 1, Task 2

---

### Task 1: 셸 — Hermes 대시보드 시작/열기

**Files:**
- Modify: `platform/common.sh` (파일 끝에 함수 3개 추가)
- Modify: `core/steps/connect.sh` (전체 재작성)
- Test: `tests/test_connect.sh` (재작성)

**Interfaces:**
- Produces (common.sh, `p_*` OS 중립):
  - `p_hermes_dashboard_url() -> string` — `http://127.0.0.1:9119`
  - `p_hermes_dashboard_running() -> exit 0|1` — URL이 응답하면 0
  - `p_hermes_dashboard_start() -> exit 0|1` — 준비되면 0. `HC_DRY_RUN`이면 `hermes dashboard --no-open`을 출력하고 0
- Produces (connect.sh):
  - `connect_run() -> exit 0` — 기존 유지: `HC_DRY_RUN`에서 `hermes setup --portal`/`hermes setup`을 출력
  - `cmd_connect() -> exit 0` — 대시보드 시작 → 브라우저 열기(또는 URL 출력) → 실패 시 `hermes setup` 폴백
- 소비: `p_bin_dir`, `p_activate_tools`, `hc_log_dir`, `p_open_browser`, `p_has_display`, `ui_warn`, `ui_pause`, `p_run`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_connect.sh` 를 아래로 교체한다(기존 `connect_menu`/예산 테스트 제거):

```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers.sh"
. "$HERE/../core/lib.sh"
. "$HERE/../core/ui.sh"
. "$HERE/../core/manifest.sh"
hc_load_platform
. "$HERE/../core/steps/70-seed.sh"
. "$HERE/../core/steps/connect.sh"
export HC_NO_COLOR=1

t_dashboard_url()    { assert_eq "http://127.0.0.1:9119" "$(p_hermes_dashboard_url)" "대시보드 URL"; }
t_dashboard_dryrun() { local out; out="$(HC_DRY_RUN=1 p_hermes_dashboard_start)"; assert_contains "$out" "hermes dashboard --no-open" "DRY_RUN 은 명령만 출력"; }
t_connect_opens()    { local out; out="$(HC_DRY_RUN=1 HC_SKIP_OPEN=1 cmd_connect 2>&1)"; assert_contains "$out" "9119" "AI연결이 대시보드 URL 을 안내"; }
t_connect_fallback() {
  p_hermes_dashboard_start() { return 1; }
  local out; out="$(HC_DRY_RUN=1 HC_SKIP_OPEN=1 cmd_connect 2>&1)"
  assert_contains "$out" "hermes setup" "대시보드 실패 시 위저드로 폴백"
}
run_tests t_dashboard_url t_dashboard_dryrun t_connect_opens t_connect_fallback
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash tests/test_connect.sh`
Expected: FAIL — `p_hermes_dashboard_url: command not found` 등

- [ ] **Step 3: `platform/common.sh` 에 함수 3개를 추가한다**

파일 끝(`p_tail_log` 뒤)에 추가. `p_hermes_dashboard_url` 은 기본 URL을 반환. `p_hermes_dashboard_running` 은 `curl -fsS -m 2 "$url"` 로 확인. `p_hermes_dashboard_start` 는:
- `HC_DRY_RUN`이면 `printf '%s\n' "hermes dashboard --no-open"` 하고 `return 0`.
- 이미 running이면 `return 0`.
- 아니면 `mkdir -p "$(hc_log_dir)"`, `p_activate_tools`, `nohup "$(p_bin_dir)/hermes" dashboard --no-open >>"$(hc_log_dir)/hermes-dashboard.log" 2>&1 &`.
- 최대 30초 동안 1초 간격으로 `p_hermes_dashboard_running` 이 0이 되면 `return 0`, 끝까지 안 되면 `return 1`.

- [ ] **Step 4: `core/steps/connect.sh` 를 재작성한다**

`connect_run` 은 기존 그대로 유지(폴백용, 시그니처 `connect_run() <- exit 0`, `HC_DRY_RUN`에서 명령 출력). `connect_menu`·`connect_budget_set`·`connect_budget_prompt` 는 제거. `cmd_connect` 는:

```bash
cmd_connect() {
  local url
  if p_hermes_dashboard_start; then
    url="$(p_hermes_dashboard_url)"
    printf 'AI 연결 화면: %s\n' "$url"
    if [ -z "${HC_SKIP_OPEN:-}" ] && p_has_display; then
      p_open_browser "$url" || ui_warn "브라우저를 자동으로 열지 못했습니다. 위 주소를 직접 열어 주세요."
    fi
    ui_pause
    return 0
  fi
  ui_warn "AI 연결 화면을 열지 못했습니다. 터미널 설정으로 진행합니다."
  connect_run 1 || true
  ui_pause
  return 0
}
```

(`connect_run 1` 은 `hermes setup --portal`. 폴백은 위저드 전체가 아니라 포털 경로로 단순화한다. `HC_DRY_RUN`에서는 "hermes setup --portal"이 출력된다.)

- [ ] **Step 5: 통과를 확인한다**

Run: `bash tests/test_connect.sh`
Expected: 모든 테스트 ✓

- [ ] **Step 6: 전체 셸 회귀를 확인한다**

Run: `bash tests/run.sh`
Expected: `모든 테스트 파일 통과`

- [ ] **Step 7: 커밋**

```bash
git add platform/common.sh core/steps/connect.sh tests/test_connect.sh
git commit -m "feat: AI 연결이 Hermes 웹 대시보드를 연다 (셸)"
```

---

### Task 2: PowerShell — Hermes 대시보드 시작/열기

**Files:**
- Modify: `win/platform.ps1` (`Get-HcPlatform` 근처에 함수 3개 추가)
- Modify: `win/commands.ps1` (`Invoke-HcConnect` 재작성, `win/commands.ps1` 의 `Invoke-HcConnect`)
- Test: `tests/win/Platform.Tests.ps1`

**Interfaces:**
- Produces (`win/platform.ps1`):
  - `Get-HcHermesDashboardUrl() -> string` — `http://127.0.0.1:9119`
  - `Test-HcHermesDashboardRunning() -> [bool]` — `Invoke-WebRequest` 로 확인(실패하면 `$false`)
  - `Start-HcHermesDashboard() -> [bool]` — 준비되면 `$true`. `HC_DRY_RUN`이면 `Write-Host "hermes dashboard --no-open"` 하고 `$true`
- Produces (`win/commands.ps1`):
  - `Invoke-HcConnect() -> [bool]` — 대시보드 시작 → `Open-HcBrowser` (또는 URL 출력) → 실패 시 `Invoke-HcRun hermes @("setup")`
- 소비: `Get-HcBinDir`, `Open-HcBrowser`, `Test-HcHasDisplay`, `Write-HcWarn`, `Invoke-HcRun`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/win/Platform.Tests.ps1` 의 `$script:Tests = @( ... )` 끝(마지막 `}` 뒤)에 테스트 2개를 추가한다:

```powershell
    @{ Name = "Hermes 대시보드 URL 은 9119"; Body = {
        Assert-Equal "http://127.0.0.1:9119" (Get-HcHermesDashboardUrl) "URL"
    } },
    @{ Name = "DRY_RUN 에서 대시보드 시작은 부작용 없이 true"; Body = {
        $env:HC_DRY_RUN = "1"
        $ok = Start-HcHermesDashboard
        Remove-Item Env:\HC_DRY_RUN -ErrorAction SilentlyContinue
        Assert-True $ok "true 반환"
    } }
```

- [ ] **Step 2: 실패를 확인한다**

Run: `pwsh -NoProfile -File tests/win/run.ps1`
Expected: FAIL — `Get-HcHermesDashboardUrl`/`Start-HcHermesDashboard` 을 찾지 못함

- [ ] **Step 3: `win/platform.ps1` 에 함수 3개를 추가한다**

`Test-HcHermesDashboardRunning`(Invoke-WebRequest 실패 시 `$false`), `Get-HcHermesDashboardUrl`(기본 URL), `Start-HcHermesDashboard`(DRY_RUN은 명령 출력+`$true`; 이미 running이면 `$true`; 아니면 `Start-Process -FilePath (Join-Path (Get-HcBinDir) "hermes.exe") -ArgumentList "dashboard","--no-open" -WindowStyle Hidden`, 최대 30초 폴링 후 `$true`/`$false`) 를 구현한다.

- [ ] **Step 4: `win/commands.ps1` 의 `Invoke-HcConnect` 를 재작성한다**

```powershell
function Invoke-HcConnect {
    $url = Get-HcHermesDashboardUrl
    if (Start-HcHermesDashboard) {
        Write-Host "AI 연결 화면: $url"
        if (-not $env:HC_SKIP_OPEN -and (Test-HcHasDisplay)) {
            try { Open-HcBrowser $url } catch { Write-HcWarn "브라우저를 자동으로 열지 못했습니다. 위 주소를 직접 열어 주세요." }
        }
        return $true
    }
    Write-HcWarn "AI 연결 화면을 열지 못했습니다. 터미널 설정으로 진행합니다."
    $hermes = Join-Path (Get-HcBinDir) "hermes.exe"
    if (-not (Test-Path -LiteralPath $hermes)) { $hermes = "hermes" }
    Invoke-HcRun $hermes @("setup") | Out-Null
    return $true
}
```

- [ ] **Step 5: 통과와 회귀를 확인한다**

Run: `pwsh -NoProfile -File tests/win/run.ps1`
Expected: 총계 `fail=0` (기존+신규 테스트)

- [ ] **Step 6: 커밋**

```bash
git add win/platform.ps1 win/commands.ps1 tests/win/Platform.Tests.ps1
git commit -m "feat: AI 연결이 Hermes 웹 대시보드를 연다 (Windows)"
```

---

### Task 3: 문서 갱신 + 실제 확인

**Files:**
- Modify: `README.md:29`, `entry/사용방법.html:88-95`, `docs/windows.md:49`, `docs/linux.md:31-34`

**Interfaces:**
- 소비: 없음(문서)

- [ ] **Step 1: 문서를 UI 기준으로 갱신한다**

네 곳의 "AI연결 = 터미널 위저드" 설명을 "AI연결을 실행하면 **웹 설정 화면**(127.0.0.1:9119)이 브라우저에 열리고, 거기서 모델·API 키를 연결한다"로 바꾼다. 예산 관련 언급이 있으면 제거한다.

- [ ] **Step 2: 실제 확인 (macOS)**

Run: `HC_DRY_RUN=1 HC_SKIP_OPEN=1 bash entry/bootstrap.sh connect`
Expected: `hermes dashboard --no-open` 과 `http://127.0.0.1:9119` 가 출력되고 멈추지 않는다.

- [ ] **Step 3: 실제 대시보드가 뜨는지 확인 (macOS, 네트워크 불필요)**

Run: `bash entry/bootstrap.sh connect < /dev/null` (브라우저가 열리고 URL이 출력된다) 후
`curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9119/`
Expected: `200`

- [ ] **Step 4: 커밋**

```bash
git add README.md entry/사용방법.html docs/windows.md docs/linux.md
git commit -m "docs: AI 연결은 웹 대시보드에서 한다"
```

---

## Self-Review

- **Spec coverage:** 대시보드 시작/열기(목표) → Task 1·2. URL 출력·폴백(목표/Review Focus) → Task 1·2. 예산 프롬프트 제거(설계 결정) → Task 1. 문서(구현자에게 남긴 것) → Task 3. 자체 UI 안 만듦(비목표) → 해당 없음.
- **Type consistency:** 셸 `p_hermes_dashboard_*` 와 PS `(Get|Test|Start)-HcHermesDashboard*` 이름을 두 태스크에서 동일하게 쓴다. `cmd_connect`/`Invoke-HcConnect` 시그니처 유지.
- **Review Focus 매핑:** 헤드리스 → Task1 `t_connect_opens`(HC_SKIP_OPEN) / Task2 URL 출력; 실패 폴백 → Task1 `t_connect_fallback` / Task2; 비TTY·DRY_RUN → Task1 `t_dashboard_dryrun` / Task2 DRY_RUN 테스트; 중복 시작 → `p_hermes_dashboard_running`/`Test-HcHermesDashboardRunning` 로직(구현자가 시작 전 확인); `HC_SKIP_OPEN` → Task1 테스트.
- **Proportion:** 스펙과 비슷한 길이. 본문은 시그니처·테스트 위주.
