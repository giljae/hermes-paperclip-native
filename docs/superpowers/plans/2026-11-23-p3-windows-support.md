# P3: Windows 지원 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 같은 설치기를 Windows에서도 동작하게 한다 — 한 줄 PowerShell 명령으로 Node·Paperclip·Hermes를 관리자 권한 없이 설치하고, 로그인 시 자동 시작하고, 대시보드를 연다.

**Architecture:** Windows에는 bash가 없으므로 **`core/`의 셸 구현을 재사용할 수 없다.** `win/` 아래에 PowerShell로 병렬 구현한다. 다만 **설계는 그대로 따른다**: 오케스트레이션(`core.ps1`)과 OS 전용(`platform.ps1`)을 분리하고, 설치 단계 순서·매니페스트 키·한국어 문구·`HC_*`에 해당하는 환경 변수 이름을 macOS/Linux와 동일하게 맞춘다. 그래야 문서와 테스트가 두 구현에 함께 적용된다.

**Tech Stack:** **Windows PowerShell 5.1**(Windows 10/11 기본 내장 — 설치 불필요), `Invoke-WebRequest`, `Expand-Archive`, `schtasks`, `Start-Process`, Node 공식 `win-x64.zip`, uv, `paperclipai`, `hermes-agent`

**Spec:** `docs/superpowers/specs/2026-11-23-hermes-paperclip-cross-platform-installer-design.md` (8절 Windows 열, 15절 P3)

## Global Constraints

P1/P2의 제약을 Windows에 맞게 옮긴다. 추가·변경:

- **PowerShell 5.1에서 동작해야 한다.** 7+ 전용 문법(`??`, 삼항 연산자, `ForEach-Object -Parallel`)을 쓰지 않는다. 기본 내장이라 사용자가 아무것도 설치하지 않아도 되기 때문이다.
- **`.ps1` 파일은 UTF-8 BOM으로 저장한다.** BOM이 없으면 PowerShell 5.1이 한국어를 시스템 코드페이지로 읽어 문구가 깨진다(실제로 겪은 종류의 사고).
- **스크립트 시작 시 인코딩을 고정한다**: `[Console]::OutputEncoding = [Text.Encoding]::UTF8`, `$OutputEncoding = [Text.Encoding]::UTF8`.
- **관리자 권한을 요구하지 않는다.** `%LOCALAPPDATA%`, `%USERPROFILE%` 안에서만 설치한다. `schtasks`가 권한을 요구하면 자동 시작을 포기하고 백그라운드 러너로 폴백한다(오류로 만들지 않는다).
- **사용자 PATH를 덮어쓰지 않는다.** 기존 값 뒤에 **없을 때만** 덧붙인다.
- **`core/`의 계약을 이름까지 맞춘다**: 매니페스트 키(`INSTALLER_VERSION`, `NODE_VERSION`, `HERMES_EXISTED`, `PLATFORM` …), 단계 순서(1~9), 한국어 라벨 문구.
- 경로는 항상 `-LiteralPath`/큰따옴표로 다룬다. 한글 사용자명(`C:\Users\김철수`)과 공백을 전제로 한다.
- 환경 변수 스위치 이름도 동일하게: `HC_HOME`, `HC_SKIP_AUTOSTART`, `HC_SKIP_OPEN`, `HC_DRY_RUN`, `HC_LATEST_VERSION`, `HC_SMOKE_REAL`.

## Review Focus

스펙이 명시하지 않았지만 실제 사용자에게 물릴 것이 확실한 입력/상황들이다. 각 항목은 지정된 태스크의 테스트로 고정한다.

1. **PowerShell 5.1에서 한국어가 깨지는 문제.** BOM 없는 `.ps1` + 코드페이지 → 설치 안내가 외계어가 된다. → Task 1
2. **사용자 PATH 덮어쓰기.** 기존 PATH를 잃으면 사용자의 다른 프로그램이 전부 깨진다. 복구가 어렵다. → Task 3
3. **`schtasks`가 관리자 권한을 요구하는 환경.** 설치가 실패하면 안 되고 백그라운드로 폴백해야 한다. → Task 5
4. **Windows Defender가 `uv.exe`를 격리**(Hermes 문서에 명시된 오탐). 설치 중 파일이 사라지면 원인을 알 수 없다. → Task 6
5. **한글 사용자명·공백 경로**(`C:\Users\김 철수\.paperclip`). → Task 2

---

## File Structure

| 파일 | 책임 |
|---|---|
| `win/bootstrap.ps1` | `irm \| iex` 진입점. 릴리스에서 zip을 받아 `core.ps1` 실행 |
| `win/ui.ps1` | 한국어 출력 (`Write-Ok`, `Write-Step`, `Write-Fail`, `Read-Pause`) |
| `win/platform.ps1` | Windows 전용: 감지, 경로, Node/uv/Hermes/Paperclip 설치, PATH, 자동 시작, 브라우저, 백그라운드 러너 |
| `win/core.ps1` | 단계 목록·실행·매니페스트·로그. **OS 전용 호출은 `platform.ps1`의 함수만** |
| `win/manifest.ps1` | `manifest.env` 읽기/쓰기 (macOS/Linux와 같은 key=value 형식) |
| `win/commands.ps1` | `install`/`update`/`start`/`stop`/`status`/`connect`/`uninstall` 디스패치 + 제어 파일 생성 |
| `win/사용방법.html` | Windows 사용자 안내(한 줄 명령 중심) |
| `tests/win/run.ps1` | 테스트 러너 |
| `tests/win/*.Tests.ps1` | 단위 테스트 |
| `tests/win/smoke.ps1` | 가짜 홈에서 설치 → 멱등 → 업데이트 → 제거 |
| `.github/workflows/ci.yml` | `windows-latest` 잡 추가 |

**재사용하는 것**: `pins.env`(버전 핀), `VERSION`, 릴리스 zip 구조, 매니페스트 형식, 단계 순서와 한국어 문구, `docs/`.

**재사용하지 않는 것**: `core/`, `platform/`, `entry/` 의 셸 스크립트 전부.

---

### Task 1: Windows 테스트 하네스 + CI 잡

**Files:**
- Create: `tests/win/run.ps1`, `tests/win/Assert.ps1`, `tests/win/Encoding.Tests.ps1`
- Modify: `.github/workflows/ci.yml`, `tests/test_ci_shape.sh`

**Interfaces:**
- Produces: `Assert-Equal <expected> <actual> <label>`, `Assert-Contains <haystack> <needle> <label>`, `Assert-True <condition> <label>`, `Invoke-Tests <scriptblock[]>`, `$script:TestsRun`/`$script:TestsFailed`. 러너는 `pass=N fail=N` 을 출력하고 실패가 있으면 exit 1.

- [ ] **Step 1: 인코딩 테스트를 쓴다 (한국어가 실제로 나오는지)**

`tests/win/Encoding.Tests.ps1`:
```powershell
. "$PSScriptRoot\Assert.ps1"

$script:Tests = @(
  @{ Name = "한국어 문자열이 그대로 나온다"; Body = {
      $s = "저장 공간이 부족합니다"
      Assert-Equal "저장 공간이 부족합니다" $s "한국어 왕복"
  } },
  @{ Name = "이 파일에 BOM 이 있다"; Body = {
      $bytes = [IO.File]::ReadAllBytes($PSCommandPath)[0..2]
      Assert-True ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) "BOM 존재"
  } },
  @{ Name = "콘솔 출력 인코딩이 UTF-8"; Body = {
      Assert-Equal "utf-8" ([Console]::OutputEncoding.WebName) "OutputEncoding"
  } }
)
```

- [ ] **Step 2: 실패를 확인한다**

Run: `pwsh -File tests/win/run.ps1` (또는 `powershell -File ...`)
Expected: FAIL — `Assert.ps1` 없음

- [ ] **Step 3: 하네스를 구현한다**

`tests/win/Assert.ps1` — 카운터를 `$script:` 로 유지하고, 실패 시 `✗ <label>` 과 기대/실제를 출력한다.
`tests/win/run.ps1` — `$PSScriptRoot\*.Tests.ps1` 를 이름순으로 실행하고, 각 파일의 `$script:Tests` 를 돌린 뒤 `pass=N fail=N` 을 출력한다. 마지막에 `[Console]::OutputEncoding = [Text.Encoding]::UTF8` 를 설정한다.
모든 `.ps1` 을 **UTF-8 BOM** 으로 저장한다(편집기 설정이 아니라 스크립트로 보장: Task 1 에서 `tests/win/` 파일을 만드는 방법을 README 에 적는다).

- [ ] **Step 4: CI 잡을 추가한다**

`.github/workflows/ci.yml` 에 `test-windows` 잡(`runs-on: windows-latest`, `shell: pwsh`)을 추가해 `tests/win/run.ps1` 을 돌린다. `tests/test_ci_shape.sh` 에 `t_ci_windows` 를 추가해 `windows-latest` 를 확인한다.

- [ ] **Step 5: 통과를 확인하고 커밋한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: `pass=3 fail=0`
```bash
git add tests/win .github/workflows/ci.yml tests/test_ci_shape.sh
git commit -m "test(win): add a PowerShell test harness and a windows CI job"
```

---

### Task 2: `win/platform.ps1` — 감지·경로·브라우저·로그

**Files:**
- Create: `win/platform.ps1`, `tests/win/Platform.Tests.ps1`

**Interfaces:**
- Produces: `Get-HcAppDir`, `Get-HcPlatform`(→ `@{ OS='windows'; Arch='x64'|'arm64'; Version=<string> }`), `Get-HcBinDir`, `Get-HcNodeDir`, `Get-HcDataDir`, `Test-HcHasDisplay`(항상 `$true`), `Get-HcNodeArchiveUrl <version>`, `Get-HcServerUrl`, `Open-HcBrowser <url>`, `Get-HcTailLog <n>`, `Write-HcLog <message>`, `Test-HcRequireSupported`

- [ ] **Step 1: 실패 테스트를 쓴다 (한글 사용자명 포함)**

```powershell
@{ Name = "경로는 LOCALAPPDATA 아래다"; Body = {
    Assert-Equal "$env:LOCALAPPDATA\hermes-paperclip-native" (Get-HcAppDir) "app dir"
    Assert-Equal "$env:USERPROFILE\.paperclip" (Get-HcDataDir) "data dir"
} },
@{ Name = "한글·공백 경로에서도 로그를 쓴다"; Body = {
    $d = Join-Path $env:TEMP "김 철수 테스트"
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    $env:HC_HOME = $d
    Write-HcLog "테스트"
    Assert-True (Test-Path (Join-Path $d "logs\install.log")) "로그 파일"
    Assert-Contains (Get-Content -LiteralPath (Join-Path $d "logs\install.log") -Raw) "테스트" "로그 내용"
} },
@{ Name = "Node URL"; Body = {
    Assert-Equal "https://nodejs.org/dist/v24.20.0/node-v24.20.0-win-x64.zip" (Get-HcNodeArchiveUrl "24.20.0") "url"
} },
@{ Name = "서버 주소 기본값"; Body = { Assert-Equal "http://127.0.0.1:3100" (Get-HcServerUrl) "기본 포트" } }
```

- [ ] **Step 2: 실패를 확인한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: FAIL — `win/platform.ps1` 없음

- [ ] **Step 3: 구현한다**

`$env:HC_HOME` 이 있으면 그것을, 없으면 `$env:LOCALAPPDATA\hermes-paperclip-native` 를 앱 디렉터리로 쓴다. `Get-HcServerUrl` 은 `Get-HcDataDir\instances\default\config.json` 에서 `"port"` 를 정규식으로 읽고, 실패하면 3100 을 쓴다(셸 구현과 같은 계약). `Test-HcRequireSupported` 는 64비트가 아니면 중단하고, 관리자 권한으로 실행 중이면 **경고만** 한다(설치는 사용자 범위라 동작한다).

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: `pass=7 fail=0`
```bash
git add win/platform.ps1 tests/win/Platform.Tests.ps1
git commit -m "feat(win): add detection, paths, server URL, and logging"
```

---

### Task 3: `win/platform.ps1` — Node 설치와 사용자 PATH 등록

**Files:**
- Modify: `win/platform.ps1`, `tests/win/Platform.Tests.ps1`

**Interfaces:**
- Produces: `Test-HcNodePresent`, `Install-HcNode`, `Add-HcToUserPath`

- [ ] **Step 1: 실패 테스트를 쓴다 (PATH 보존이 핵심)**

```powershell
@{ Name = "PATH 뒤에 덧붙이고 기존 값을 보존한다"; Body = {
    $before = [Environment]::GetEnvironmentVariable("Path", "User")
    Add-HcToUserPath
    $after = [Environment]::GetEnvironmentVariable("Path", "User")
    Assert-True ($after -like "*$env:LOCALAPPDATA\hermes-paperclip-native\bin*") "bin 이 추가됨"
    if ($before) { Assert-True ($after.Contains($before)) "기존 PATH 가 보존됨" }
    Assert-True ($after.Split(';').Count -le ($(if ($before) { $before.Split(';').Count } else { 0 }) + 1)) "중복 추가 없음"
} },
@{ Name = "두 번 실행해도 한 번만 추가한다"; Body = {
    Add-HcToUserPath; Add-HcToUserPath
    $p = [Environment]::GetEnvironmentVariable("Path", "User")
    $n = ($p.Split(';') | Where-Object { $_ -like "*hermes-paperclip-native\bin*" }).Count
    Assert-Equal 1 $n "중복 없음"
} }
```

- [ ] **Step 2: 실패를 확인한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: FAIL — `Add-HcToUserPath` 없음

- [ ] **Step 3: 구현한다**

`Add-HcToUserPath` 는 **사용자 범위**(`"User"`)만 건드린다. 기존 값을 읽어 `;` 로 나눈 뒤, 우리 경로가 **정확히 일치하는 항목으로 없을 때만** 덧붙이고 다시 쓴다. 시스템 PATH는 절대 건드리지 않는다. 현재 프로세스에는 `$env:Path = "$bin;$env:Path"` 로 즉시 반영한다.

`Install-HcNode` 는 `win-x64.zip` 을 받아 `Get-HcNodeDir` 에 풀고, `node.exe`/`npm.cmd`/`npx.cmd` 가 있는 디렉터리를 PATH에 넣는다(우리 bin 디렉터리에 `.cmd` 심을 만들거나 node 디렉터리를 PATH에 추가).

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: `pass=9 fail=0`
```bash
git add win/platform.ps1 tests/win/Platform.Tests.ps1
git commit -m "feat(win): install portable Node and append to the user PATH"
```

---

### Task 4: `win/core.ps1` + 설치 단계 (Node → Paperclip → Hermes)

**Files:**
- Create: `win/core.ps1`, `win/manifest.ps1`, `tests/win/Core.Tests.ps1`

**Interfaces:**
- Consumes: Task 2·3의 `Get-Hc*`/`Install-HcNode`
- Produces: `Read-HcManifest`/`Get-HcManifest`/`Set-HcManifest`/`Get-HcManifestPath`(key=value, 셸 구현과 같은 키), `Invoke-HcStep <n> <total> <scriptblock> <label> [<soft>]`, `Get-HcInstallSteps`(1~9 라벨이 셸과 동일), `Install-HcUv`, `Install-HcHermes`, `Install-HcPaperclip`, `Invoke-HcRun`(DRY_RUN 지원)

- [ ] **Step 1: 실패 테스트를 쓴다 (매니페스트 호환 + 단계 실패 전파)**

```powershell
@{ Name = "매니페스트는 셸 구현과 같은 형식"; Body = {
    $env:HC_HOME = Join-Path $env:TEMP ("hc-" + [guid]::NewGuid())
    Set-HcManifest "NODE_VERSION" "24.20.0"
    Assert-Equal "24.20.0" (Get-HcManifest "NODE_VERSION") "저장 후 조회"
    Assert-Equal "NODE_VERSION=24.20.0" ((Get-Content -LiteralPath (Get-HcManifestPath)) -eq "NODE_VERSION=24.20.0" | Where-Object {$_} | Select-Object -First 1) "형식"
} },
@{ Name = "단계 실패는 전체를 실패시킨다"; Body = {
    $ok = Invoke-HcStep 1 9 { return $false } "실패단계"
    Assert-True (-not $ok) "false 반환"
} },
@{ Name = "soft 단계는 실패해도 계속한다"; Body = {
    $ok = Invoke-HcStep 1 9 { return $false } "무른단계" $true
    Assert-True $ok "true 반환"
} },
@{ Name = "단계 라벨이 셸 구현과 같다"; Body = {
    $labels = (Get-HcInstallSteps).Label
    Assert-Equal 9 $labels.Count "9 단계"
    Assert-Equal "이 컴퓨터를 확인하는 중..." $labels[0] "1단계 라벨"
} }
```

- [ ] **Step 2: 실패를 확인한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: FAIL — `win/core.ps1` 없음

- [ ] **Step 3: 구현한다**

핵심은 **셸 구현과 어긋나지 않는 것**이다. 라벨 9개를 `core/steps` 의 `hc_install_steps` 에서 그대로 옮긴다. `Invoke-HcRun` 은 `$env:HC_DRY_RUN` 이 있으면 명령 문자열만 출력한다.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: `pass=13 fail=0`
```bash
git add win/core.ps1 win/manifest.ps1 tests/win/Core.Tests.ps1
git commit -m "feat(win): add manifest, step runner, and tool installers"
```

---

### Task 5: `win/platform.ps1` — 자동 시작(Task Scheduler)과 백그라운드 러너

**Files:**
- Modify: `win/platform.ps1`, `tests/win/Platform.Tests.ps1`

**Interfaces:**
- Produces: `Install-HcAutostart`, `Remove-HcAutostart`, `Get-HcAutostartStatus`, `Start-HcServerBackground`, `Stop-HcServerBackground`, `Test-HcServerRunning`

- [ ] **Step 1: 실패 테스트를 쓴다**

```powershell
@{ Name = "schtasks 를 쓸 수 없으면 1 을 반환한다(예외 아님)"; Body = {
    $orig = Get-Command schtasks -ErrorAction SilentlyContinue
    function global:schtasks { throw "unavailable" }
    $r = Install-HcAutostart -AssumeNoScheduler
    Assert-Equal $false $r "폴백 신호"
} },
@{ Name = "백그라운드 pidfile 수명주기"; Body = {
    $env:HC_HOME = Join-Path $env:TEMP ("hc-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $env:HC_HOME | Out-Null
    Assert-Equal $false (Test-HcServerRunning) "처음엔 아님"
} }
```

- [ ] **Step 2: 실패를 확인한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: FAIL — 함수 없음

- [ ] **Step 3: 구현한다**

`Install-HcAutostart` 는 `schtasks /Create /SC ONLOGON /TN hermes-paperclip /TR "<명령>" /F` 를 시도하고, **실패하면 예외를 던지지 않고 `$false` 를 반환**한다(코어가 백그라운드 러너로 폴백). 백그라운드 러너는 `Start-Process -WindowStyle Hidden` + pidfile(`$env:HC_HOME\server.pid`)이며 셸 구현과 같은 계약.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: `pass=15 fail=0`
```bash
git add win/platform.ps1 tests/win/Platform.Tests.ps1
git commit -m "feat(win): Task Scheduler autostart with background fallback"
```

---

### Task 6: 설치 오케스트레이션·시드·제어 파일

**Files:**
- Create: `win/commands.ps1`, `win/bootstrap.ps1`, `win/사용방법.html`
- Modify: `tests/win/Core.Tests.ps1`

**Interfaces:**
- Consumes: Task 2~5 전부
- Produces: `Invoke-HcDispatch <command>`, `Invoke-HcInstall`, `Invoke-HcConnect`, `Invoke-HcUninstall`, `New-HcControlFiles`(→ `~/HermesPaperclip/*.cmd`), `bootstrap.ps1` 이 릴리스에서 zip을 받아 실행

- [ ] **Step 1: 실패 테스트를 쓴다**

```powershell
@{ Name = "제어 파일은 self-locating 이다"; Body = {
    $env:HC_HOME = Join-Path $env:TEMP ("hc-" + [guid]::NewGuid())
    $env:USERPROFILE = Join-Path $env:TEMP ("up-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $env:USERPROFILE | Out-Null
    Set-HcManifest "INSTALLER_VERSION" "0.1.2"
    New-HcControlFiles
    $f = Join-Path $env:USERPROFILE "HermesPaperclip\상태.cmd"
    Assert-True (Test-Path -LiteralPath $f) "상태.cmd 존재"
    $c = Get-Content -LiteralPath $f -Raw
    Assert-Contains $c "manifest.env" "매니페스트에서 버전을 읽는다"
    Assert-Contains $c "commands.ps1" "명령 스크립트를 부른다"
} }
```

- [ ] **Step 2: 실패를 확인한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: FAIL — `New-HcControlFiles` 없음

- [ ] **Step 3: 구현한다**

`bootstrap.ps1` 은 `HC_SOURCE_DIR` 가 있으면 그것을, 없으면 `releases/latest/download/VERSION` → `hermes-paperclip-<ver>.zip` + `checksums.txt` 를 받아 검증하고 `%LOCALAPPDATA%\hermes-paperclip-native\app\<ver>` 에 푼다. **Defender가 파일을 지운 경우를 감지**해(설치 직후 파일 존재 확인) 한국어로 안내한다(Review Focus 4).

제어 파일은 `.cmd` 로 만든다(`.ps1` 은 더블클릭이 안 되고, `.cmd` 는 실행 정책의 영향을 덜 받는다):
```bat
@echo off
chcp 65001 >nul
set "HC_HOME=%LOCALAPPDATA%\hermes-paperclip-native"
for /f "tokens=2 delims==" %%v in ('findstr /b "INSTALLER_VERSION=" "%HC_HOME%\manifest.env"') do set "VER=%%v"
powershell -NoProfile -ExecutionPolicy Bypass -File "%HC_HOME%\app\%VER%\win\commands.ps1" status
pause
```

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: `pass=16 fail=0`
```bash
git add win/ tests/win/Core.Tests.ps1
git commit -m "feat(win): add entry, control files, and install orchestration"
```

---

### Task 7: 업데이트·제거

**Files:**
- Modify: `win/commands.ps1`, `tests/win/Core.Tests.ps1`

**Interfaces:**
- Produces: `Invoke-HcUpdate`, `Test-HcUpdateNeeded`, `Invoke-HcUninstall`

- [ ] **Step 1: 실패 테스트를 쓴다**

```powershell
@{ Name = "제거는 기존 Hermes 설정을 보존한다"; Body = {
    $env:HC_HOME = Join-Path $env:TEMP ("hc-" + [guid]::NewGuid())
    $env:USERPROFILE = Join-Path $env:TEMP ("up-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path (Join-Path $env:USERPROFILE ".hermes") | Out-Null
    Set-HcManifest "HERMES_EXISTED" "true"
    Invoke-HcUninstall -Yes
    Assert-True (Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".hermes")) "기존 Hermes 보존"
} },
@{ Name = "업데이트는 같은 버전이면 건너뛴다"; Body = {
    Set-HcManifest "INSTALLER_VERSION" "0.1.2"
    $env:HC_LATEST_VERSION = "0.1.2"
    Assert-Equal $false (Test-HcUpdateNeeded) "건너뛴다"
} }
```

- [ ] **Step 2: 실패를 확인한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: FAIL — 함수 없음

- [ ] **Step 3: 구현한다**

셸 구현의 `step_uninstall` 과 같은 순서·같은 보존 규칙. 삭제 전에 `HERMES_EXISTED` 를 먼저 읽는다(매니페스트가 사라지기 때문).

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: `pass=18 fail=0`
```bash
git add win/commands.ps1 tests/win/Core.Tests.ps1
git commit -m "feat(win): add update and uninstall"
```

---

### Task 8: Windows 실제 설치 스모크 (CI)

**Files:**
- Create: `tests/win/smoke.ps1`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: `windows-latest` 에서 실제 설치를 검증하는 잡

- [ ] **Step 1: 스모크를 쓴다**

`tests/win/smoke.ps1` — 가짜 `HC_HOME`/`USERPROFILE` 에서 설치 → 시드 확인 → 멱등 → 업데이트 → 제거. `HC_SMOKE_REAL` 이 없으면 `HC_DRY_RUN=1`. 실패 시 임시 디렉터리를 보존하고 경로를 출력한다(셸 버전과 같은 동작).

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `pwsh -File tests/win/smoke.ps1`
Expected: FAIL (아직 빈 경로가 있음) → 나오는 문제를 고친다

- [ ] **Step 3: CI 에 잡을 추가한다**

`.github/workflows/ci.yml` 에 `smoke-real-windows` 잡(`runs-on: windows-latest`, `workflow_dispatch` 전용).

- [ ] **Step 4: 실제로 돌려 통과시킨다**

Run: `gh workflow run CI --ref main` 후 `smoke-real-windows` 결과 확인
Expected: 통과. **이것이 P3 의 완료 조건이다.**

- [ ] **Step 5: 커밋**

```bash
git add tests/win/smoke.ps1 .github/workflows/ci.yml
git commit -m "test(win): add an end-to-end install smoke for windows CI"
```

---

### Task 9: Windows 사용자 안내

**Files:**
- Create: `docs/windows.md`
- Modify: `README.md`, `entry/사용방법.html`

- [ ] **Step 1: 안내를 쓴다**

반드시 포함할 것: (a) 한 줄 명령(`irm ... | iex`), (b) Defender가 `uv.exe`를 격리할 때의 예외 처리, (c) 자동 시작이 Task Scheduler에 등록된다는 사실과 `schtasks /Query /TN hermes-paperclip` 로 확인하는 법, (d) 제거, (e) 지원 버전(Windows 10 21H2+ / 11).

- [ ] **Step 2: 확인하고 커밋한다**

Run: `pwsh -File tests/win/run.ps1`
Expected: 통과
```bash
git add docs/windows.md README.md entry/사용방법.html
git commit -m "docs: add Windows installation guide"
```

---

## P3 완료 조건

- `tests/win/run.ps1` 이 통과한다(로컬 PowerShell + windows CI 양쪽).
- **windows-latest 에서 실제 설치 스모크가 통과**한다 — P3 의 진짜 완료 조건.
- 관리자 권한 없이 설치가 끝나고, 사용자 PATH가 보존된다.
- Task Scheduler 등록이 불가한 환경에서 백그라운드 러너로 폴백한다.
- 한국어 문구가 깨지지 않는다(BOM + 콘솔 인코딩).
- P3가 끝나면 세 OS 지원이 완성된다 — 릴리스에 Windows 안내와 스크립트를 포함한다.
