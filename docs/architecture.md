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

## 배포물과 릴리스 (P4 일부 앞당김)

`make dist` 가 두 개의 zip 을 만든다.

| 파일 | 용도 |
|---|---|
| `HermesPaperclip-macOS-<ver>.zip` | 더블클릭용. `설치.command` + `사용방법.html` + 코어 |
| `hermes-paperclip-<ver>.zip` | `bootstrap.sh` 가 내려받는 알맹이(모든 OS). 루트에 `core/`, `platform/` |
| `checksums.txt` | sha256 |

**`ditto -c -k` 를 쓴다.** `zip` 명령이나 다른 도구는 실행 권한(`+x`)을 잃을 수 있고,
그러면 `설치.command` 를 더블클릭해도 실행되지 않는다. `tests/test_dist.sh` 가 이걸 실제로
검증한다(zip 을 풀어 `-x` 비트를 확인).

`make release` 는 `gh release create` 로 GitHub Releases 에 올린다. `bootstrap.sh` 는
`releases/latest/download/VERSION` 을 읽어 버전을 알아내므로, 릴리스에 `VERSION` 파일이
반드시 함께 올라가야 한다.

### 릴리스 다운로드 경로 (검증됨, v0.1.0)

`VERSION` 조회 → zip 다운로드 → `checksums.txt` 대조 → 압축 해제 → `core/run.sh` 존재 →
`bootstrap.sh` 실행 권한 유지까지 실제 릴리스에서 확인했다.

### 아직 사람이 확인해야 하는 것

macOS Gatekeeper: 인터넷에서 받아 압축을 푼 `설치.command` 를 **우클릭 → 열기**로 실행했을 때
경고를 통과할 수 있는지. `spctl --assess` 는 서명 없는 파일을 모두 거부하므로 판별에 쓸 수 없고,
실제 더블클릭은 GUI 상호작용이 필요해 자동화할 수 없다.
