# 구조 노트

## 왜 Paperclip 자체 `service` 대신 우리 LaunchAgent 인가

launchd 는 사용자 에이전트에게 PATH 를 거의 비워 둔 채 실행한다(실측: `launchctl getenv PATH` 가 비어 있음).
Paperclip 서버는 Hermes 어댑터로 `hermes` 자식 프로세스를 띄우는데, PATH 에 `~/.local/bin` 이 없으면
`hermes` 를 찾지 못한다. 그래서 `platform/launchagent.plist.template` 의 `EnvironmentVariables/PATH` 에
`~/.local/bin` 과 `~/.local/node/bin` 을 명시하고, 서비스를 직접 관리한다.

## `onboard --yes` 의 블로킹 여부 (미확정)

Task 14 에서 실측을 시도했다. 임시 HOME 에서 `npx paperclipai@2026.1117.0 onboard --yes --no-install-service`
를 백그라운드로 돌리고 config 생성/헬스 응답을 관찰했으나, **5분(270초) 동안 `config.json` 이 생기지 않았고
`/api/health` 도 응답하지 않았다.** npx 캐시가 3.5GB 까지 커진 것으로 보아 **관리 페이로드 다운로드가 관측 창을
지배**했고, 포그라운드 서버로 전환했는지 여부는 판정하지 못했다.

그래서 `step_onboard` 를 **양쪽 경우 모두에서 동작**하도록 구현했다: 백그라운드 실행 → `config.json` 대기(최대
10분) → 남아 있는 프로세스는 SIGTERM 으로 정리(서버는 다음 단계의 LaunchAgent 가 소유). 판정이 필요하면
캐시가 더운 상태에서 재실측한다.

### 부수 발견 (설치 UX 에 영향)

Paperclip 설치 페이로드가 **3.5GB** 규모다. 화면에 "약 2분"이라 적는 것은 현실과 맞지 않는다 — 진행 표시를
단계별로 두고, 오래 걸린다는 안내를 넣는다.
