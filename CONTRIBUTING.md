# 기여 안내 (Contributing)

이 저장소는 Hermes Agent 와 Paperclip 을 **일반 사용자용으로 설치·관리하는 비공식 설치기**입니다.
기여를 환영합니다. (비공식 도구·상표 고지는 [README](README.md), 보안 제보는 [SECURITY.md](SECURITY.md).)

## 무엇이 대상인가

- **여기 대상:** 설치기 코드(`core/`, `platform/`, `entry/`, `win/`), 테스트, 문서, CI.
- **여기 대상 아님:** Hermes Agent·Paperclip **자체**의 기능/버그 → 각 프로젝트에 이슈/PR 하세요.

## 개발 환경

- **macOS·Linux:** bash 3.2 호환(맥 기본 bash). Windows 는 **PowerShell 5.1** + 7.
- 빌드/테스트: `make test` (셸 + PowerShell), `make dist` (macOS 전용, `ditto`).
- 실제 설치 E2E 는 무겁습니다(수동):
  ```bash
  HC_SMOKE_REAL=1 bash tests/smoke.sh            # macOS·Linux (가짜 홈)
  HC_SMOKE_REAL=1 pwsh -File tests/win/smoke.ps1 # Windows
  ```

## 반드시 지켜야 하는 규칙 (테스트가 강제합니다)

- **sudo 금지** — 시스템 디렉터리를 건드리지 않고 사용자 범위에만 설치합니다.
- **Bash 3.2 호환** — `declare -A`, `mapfile`, `${var^^}`, `[[ -v ]]` 를 쓰지 않습니다.
- **`core/` 에 OS 이름 금지** — OS 의존 코드는 `platform/<os>.sh` 에만 둡니다.
- **PowerShell 5.1 호환 + `.ps1` 은 UTF-8 BOM** — BOM 이 없으면 5.1 에서 한국어가 깨집니다.
- **모든 사용자 문구는 한국어**, 경로는 항상 따옴표로.
- **버전 핀은 `pins.env` 한 곳**에서만 정의합니다.
- 테스트는 `HC_HOME` 을 임시 디렉터리로 덮어 실제 홈을 건드리지 않습니다.

## 보내기 전에

- 새 기능/버그픽스는 **실패하는 테스트를 먼저** 쓰고(실패를 확인하고) 구현합니다.
- `make test` 가 통과해야 합니다.
- 커밋 메시지는 `type(scope): 요약` (`feat`/`fix`/`docs`/`test`/`ci`/`build`) 형태를 따릅니다.
- 동작 변경은 위 E2E 스모크까지 통과한 뒤 PR 로 보내 주세요.

## 구조

- 셸: `core/`(OS 중립) + `platform/common.sh` + `platform/<os>.sh` + `entry/`
- Windows: `win/` (`core.ps1` OS 중립, `platform.ps1` Windows 전용)
- 문서: 설계 `docs/superpowers/specs/`, 계획 `docs/superpowers/plans/`, 구조 노트 `docs/architecture.md`
