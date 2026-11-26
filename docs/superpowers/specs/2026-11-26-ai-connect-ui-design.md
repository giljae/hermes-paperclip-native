# AI 연결을 UI로 — Hermes 대시보드 활용 (설계)

날짜: 2026-11-26 · 상태: 승인 대기

## 의도 (왜)

일반 사용자가 터미널 위저드(`hermes setup`) 대신 **설정 화면(UI)** 에서 모델·LLM
프로바이더를 연결하도록 한다. 모델의 원천은 Hermes이므로(에이전트는 `hermes_local`),
Hermes가 이미 제공하는 **웹 대시보드**(`hermes dashboard`, 기본 `127.0.0.1:9119`)를
연결 화면으로 쓴다.

확인한 사실:
- 대시보드에는 `/models`(모델 선택)와 `/config`(API 키·설정) 화면이 있다(SPA, 임베디드 세션 토큰).
- 웹 자산(`hermes_cli/web_dist`)이 **미리 빌드돼 있어** 첫 실행도 즉시 뜬다(실측: `HERMES_DASHBOARD_READY`).
- 현재 `AI연결`은 터미널 메뉴 → `hermes setup --portal` / `hermes setup` 이다.

## 목표

- `AI연결`(macOS·Linux·Windows)이 Hermes 대시보드를 (필요하면 백그라운드로) 띄우고
  브라우저로 연다(`http://127.0.0.1:9119/`).
- 브라우저를 못 여는 환경(헤드리스)에서는 URL을 출력한다.
- 대시보드를 못 띄우면 기존 터미널 위저드(`hermes setup`)로 폴백한다.

## 비목표 / 안티골

- 자체 설정 UI를 새로 만들지 않는다(접근법 B 아님).
- 모델의 원천(Hermes 설정)이나 `hermes_local` 어댑터 구조를 바꾸지 않는다.
- 연결에 터미널을 요구하지 않는다.

## 제약

- sudo 없이 사용자 범위에서. 기존 설치 위치·제어 파일 규칙을 따른다.
- 셸 구현(Bash 3.2)과 PowerShell 5.1 두 곳을 같이 맞춘다.
- 포트 9119가 이미 쓰이면 Hermes가 고른 포트를 따른다(대시보드가 알려주는 URL을 쓴다).

## 접근법 (선택: A)

- **A (선택): Hermes 대시보드 활용.** 이미 있는 진짜 UI, Hermes 설정과 같은 원천, 우리가
  화면을 만들지 않는다.
- B (자체 한국어 설정 페이지): 통제·문구 이점은 있으나 새로 만드는 비용과
  `hermes` 비대화형 명령 유지보수 → 제외.
- C (Paperclip 대시보드로 통일): 모델이 Hermes에 있어 `hermes_local` 경로를 못 덮음 → 제외.

## 설계 (the how)

- `p_hermes_dashboard_start`(셸) / `Start-HcHermesDashboard`(PS): `hermes dashboard --no-open`을
  백그라운드로 띄우고 URL이 응답할 때까지 기다린다(이미 떠 있으면 건너뜀). 실패 시 false.
- `cmd_connect` / `Invoke-HcConnect`: 대시보드 시작 → 브라우저 열기 → 못 열면 URL 출력 →
  그래도 실패면 `hermes setup`으로 폴백. 안내 문구는 한국어.
- 라이프사이클: 대시보드는 `AI연결` 때만 띄운다(자동 시작 안 함). `중지`는 Paperclip 서버만
  멈추고 대시보드는 건드리지 않는다. — 내 판단: 설정 화면은 상시 켜 둘 필요가 없다.
- 기존 예산 프롬프트는 `AI연결`에서 제거한다. — 내 판단: 연결이 UI에서 비동기로 이뤄져
  프롬프트 타이밍이 맞지 않는다. 예산은 Paperclip 쪽에서 설정한다.

## 구현자에게 남기는 것

- 9119 외 포트/호스트가 설정된 경우 대시보드가 알려주는 URL을 파싱한다.
- Windows에서 대시보드가 콘솔 창을 띄우지 않게(숨김) 처리한다.
- 테스트: `AI연결`이 대시보드 URL을 여는지, 실패 시 위저드로 폴백하는지(셸·PS).
- 문서(README, `entry/사용방법.html`, `docs/windows.md`, `docs/linux.md`)의
  "AI연결 = 터미널 위저드" 설명을 UI 기준으로 갱신한다.
