# P3 Windows — 작업 인계 (handoff)

> 이 문서는 다른 PC에서 이어서 작업하기 위한 요약입니다. 원장(ledger)은
> `.superpowers/sdd/2026-11-23-p3-windows-support/progress.md` 에 있지만 **git 에
> 커밋되지 않습니다**(scratch). 이 파일이 저장소에 남는 기록입니다.

## ✅ 완료 (2026-11-25)

**P3 는 끝났습니다.** Windows 실제 설치 스모크가 CI 에서 통과합니다(main, run 45654912113).
macOS/Linux/Windows 실제 스모크 + 모든 유닛 테스트 통과.

막혔던 지점과 수정(전부 커밋됨):

1. **`initdb` 실패** — GitHub 러너의 `D:`(`RUNNER_TEMP`)에서 **이미 존재하는 디렉터리**일 때만 `chmod` 가
   `EACCES` 로 실패. `C:` 에서는 (기존 디렉터리여도) 성공. 스모크 가짜 홈을 `LOCALAPPDATA`(C:)로 옮김.
2. **PS 5.1 JSON 인자** — raw 는 따옴표가 벗겨지고(`Expected property name`), `\"` 는 공백에서 쪼개짐
   (`too many arguments`). `Invoke-HcNative`(.NET `Process` + 수동 Windows 인용)로 교체.
3. **`--dangerously-allow-all-scripts` 는 무관** — `@embedded-postgres/windows-x64` 의 postinstall 은
   `pg-symlinks.json` 이 `[]` 라 no-op. 바이너리는 tarball 에 그대로 있었음.
4. **스모크 hang** — 설치 출력을 PowerShell 파이프로 받으면 백그라운드 서버가 파이프 핸들을 물고 있어
   닫히지 않음. 셸 파일 리다이렉트로 캡처(+UTF-8 로 읽기, `[Environment]::Exit` 로 종료).
5. **제거 중단** — stale PID 에 `taskkill` 의 stderr 가 `$ErrorActionPreference=Stop` 때문에 종료 오류가
   되어 제거가 실패. 호출 동안만 `Continue` 로 낮춤(실사용자 버그이기도 함).

**남은 제약(중요):** GitHub 러너는 **승격된 관리자(High integrity)** 라 `postgres.exe` 가
`Execution of PostgreSQL by a user with administrative permissions is not permitted` 로 기동을 거부합니다.
그래서 CI 스모크는 승격으로 돌고 **서버/시드 검증만 건너뜁니다**(설치·멱등·업데이트·제거는 검증).
실사용자는 기본 UAC(비승격)라 정상 동작하며, 설치기는 승격 감지 시 한국어로 경고합니다.
서버 기동 자체는 비승격 환경(제한 토큰 `runas /trustlevel:0x20000`)에서 postgres 가 뜨는 것을 프로브로 확인했습니다.
후속(선택): 설치기가 승격 환경에서 서버를 제한 토큰으로 자동 기동하면 CI 도 서버까지 검증할 수 있습니다.

## 지금 상태

- **P3 Task 1~9 는 모두 구현·커밋·push 완료** (`main`).
- 로컬(macOS + pwsh 7): `make test` 통과(셸 전체 + PowerShell 26 tests / 46 asserts), DRY_RUN 스모크 통과.
- **Windows 실제 설치 스모크(CI, `smoke-real-windows`)는 아직 실패 중**입니다. 이것이 P3 의 완료 조건입니다.
- 마지막 커밋: `677d997` (아래 "적용한 수정"의 최신 항목). CI 재실행은 아직 안 했습니다.

## 이어서 작업하는 법

```bash
git pull                      # main
make test                     # 셸 + PowerShell 단위 테스트 (26/46)
pwsh -File tests/win/smoke.ps1   # DRY_RUN 스모크 (가짜 홈, 네트워크 없음)

# 진짜 Windows 설치 스모크 (수동 전용, 약 15~20분, windows-latest)
gh workflow run CI --ref main
gh run list --workflow=CI --limit 3
gh run view <run-id> --log-failed          # 실패 로그
gh run download <run-id> -n win-smoke-home # 실패 시 업로드된 로그(숨김 포함)
```

스모크는 실패하면 **CI 로그에 로그 꼬리를 직접 출력**합니다(`tests/win/smoke.ps1` 의 `Fail`):
`onboard.log`, `onboard.log.err`, `seed.log`, `server.log`, `server.err.log`, `paperclip.log`.

## 계획/스펙

- 계획: `docs/superpowers/plans/2026-11-23-p3-windows-support.md`
- 스펙: `docs/superpowers/specs/2026-11-23-hermes-paperclip-cross-platform-installer-design.md` (8절 Windows, 15절 P3)

## 지금 실패하는 지점 (마지막 CI: run 45153420591)

`install` 의 1~9 단계는 모두 "성공"으로 보이지만, 실제로는 **서버가 뜨지 않아** 시드(7단계)가
회사를 만들지 못하고, 스모크 1b("회사를 찾지 못했다")에서 실패합니다. 로그의 핵심:

1. **내장 PostgreSQL 초기화 실패 (핵심 미해결)**
   `onboard --yes` 가 직접 띄운 서버가 임베디드 Postgres 초기화에 실패:
   ```
   INFO: Using embedded PostgreSQL ... port=54329
   ERROR: Embedded PostgreSQL failed ... {"phase":"initialise",
     "recentLogs":[...,"fixing permissions on existing directory .../db ..."]}
   err: "Postgres init script exited with code 1. ... The data directory might already exist."
   ```
   `initdb` 가 "fixing permissions on existing directory" 까지 출력한 뒤 exit 1.

   **유력 원인(확인 중):** npm 11.19 는 이제 **의존성 install 스크립트를 기본 차단**합니다.
   `npm install` 로그에:
   ```
   npm warn install-scripts 6 packages have install scripts not yet covered by allowScripts:
     @embedded-postgres/windows-x64@18.1.0-beta.16 (postinstall: node scripts/hydrate-symlinks.js)
     @paperclipai/server@... (postinstall: node scripts/install-copilot-assets.mjs)
   ```
   즉 `@embedded-postgres/windows-x64` 의 바이너리 하이드레이션 postinstall 이 **실행되지 않았습니다**.

2. **시드 JSON 인자가 깨짐**
   ```
   node.exe : Expected property name or '}' in JSON at position 1 (line 1 column 2)
   & $exe @pre company create --payload-json (Get-HcSeedCompanyJson)
   ```
   PowerShell 5.1 이 네이티브 실행 파일 인자 안의 `"` 를 이스케이프하지 않아 JSON 이 깨집니다.

## 적용한 수정 (모두 커밋됨, 최신 2개는 CI 미검증)

- `win/core.ps1` — `paperclipai install` 은 Windows 미지원(POSIX 전용)이라 **payload 를 직접 설치**:
  `npm install --prefix %HC_HOME%\paperclip paperclipai@<v>` + 우리 `bin\paperclipai.cmd` 심
  (`New-HcPaperclipShim`). `Install-HcPaperclip` 이 심 존재를 실제로 검증.
- `win/core.ps1` — `Invoke-HcRun` 이 네이티브 호출 동안 `$ErrorActionPreference` 를
  `Continue` 로 낮춤(PS 5.1 에서 npm/uv 의 stderr 경고가 종료 오류가 되는 문제). 로그로 tee 가능.
- `win/commands.ps1` — 자동 시작 단계에서 **서버를 실제로 띄우고 `/api/health` 를 기다림**
  (`Wait-HcServerHealth`). `onboard --yes` 가 띄운 서버를 **그대로 채택**(PID 를 pidfile 에 기록)해
  임베디드 Postgres 가 두 번 초기화되지 않게 함.
- `win/platform.ps1` — paperclipai 를 `node.exe <payload entry> ...` 로 실행(`Start-HcPaperclipProcess`,
  `Get-HcPaperclipCommand`)해 `.cmd`/공백·한글 경로 인용 문제 회피. `Stop-HcServerBackground` 는
  Windows 에서 `taskkill /T /F /PID` 로 자식(Postgres)까지 정리.
- `win/core.ps1` — **`npm install` 에 `--dangerously-allow-all-scripts` 추가** (npm 11.19 의
  install-script 기본 차단 우회). ← 이게 Postgres 초기화 실패를 고칠 것으로 기대하는 최신 수정.
- `win/commands.ps1` — `ConvertTo-HcJsonArg` 로 PS 5.1 에서 JSON 인자의 `"` 를 `\"` 로 이스케이프.
  ← 시드 JSON 깨짐에 대한 최신 수정.
- `tests/win/smoke.ps1` — 실패 시 로그 꼬리 출력, `onboard.log.err` 포함.
- `.github/workflows/ci.yml` — `test-windows` 가 pwsh 7 과 **Windows PowerShell 5.1** 양쪽 실행;
  `smoke-real-windows` 는 5.1 로 실행; 실패 아티팩트는 숨김 파일 포함.
- `Makefile` — `make test` 가 PowerShell 스위트도 실행. `make dist`/`release` 가 `win/` 을 포함하고
  `bootstrap.sh`/`bootstrap.ps1` 을 릴리스 자산으로 게시.

## 다음에 할 일

1. **CI 재실행** (`677d997` 이후):
   ```bash
   gh workflow run CI --ref main
   ```
2. **`smoke-real-windows` 결과 확인:**
   - 통과 → P3 완료. `docs/windows.md`/README 는 이미 있음. Task 8/9 원장 완료 처리.
   - 실패 → `Fail` 이 출력한 `onboard.log.err`/`server.err.log` 전체를 보고 다음을 판단:
     - 여전히 `initdb` 실패면: `--dangerously-allow-all-scripts` 가 실제로 postinstall 을 돌렸는지
       (`paperclip.log` 에 `install-scripts ... not yet covered` 가 사라졌는지) 확인.
       그래도 실패하면 `@embedded-postgres/windows-x64` 의 `hydrate-symlinks.js` 를 수동 실행하거나,
       `npm install` 에 `--foreground-scripts` 추가, 또는 `allow-scripts` 목록을 명시.
       최후에는 Windows 에서 embedded Postgres 자체가 막힌 것일 수 있음(업스트림 이슈) → 사용자와 상의.
     - 시드 JSON 이 또 깨지면: `ConvertTo-HcJsonArg` 이 5.1 에서 적용됐는지, `$pre` splatting 순서 확인.
3. 통과하면 `superpowers:finishing-a-development-branch` 로 마무리.

## 참고: 이미 통과한 것 (되돌리지 말 것)

- `tests/win/run.ps1` (단위) — 26 tests / 46 asserts, pwsh 7 + Windows PowerShell 5.1 양쪽 통과.
- DRY_RUN 스모크 — 9단계 오케스트레이션/매니페스트/제어 파일 생성 확인.
- macOS/Linux 실제 설치 스모크 — CI 통과.
- Windows 설치 1~6단계 — 실제 CI 에서 통과(노드·Paperclip payload·Hermes 설치, 대시보드 포트 등).

## 파일 지도 (P3 추가분)

```
win/bootstrap.ps1   win/commands.ps1   win/core.ps1   win/platform.ps1   win/manifest.ps1
win/사용방법.html
tests/win/{run,Assert,Core.Tests,Platform.Tests,Encoding.Tests}.ps1  tests/win/smoke.ps1
docs/windows.md
```
