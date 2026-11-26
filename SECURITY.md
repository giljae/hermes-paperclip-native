# 보안 정책

## 이 프로젝트가 하는 일 (위협 모델)

이 저장소는 **설치기**입니다. 구체적으로:

- 공식 배포본에서 도구를 내려받아 설치합니다 — Node.js(nodejs.org), uv(astral.sh),
  `paperclipai`(npm), `hermes-agent`(PyPI). 버전은 `pins.env` 한 곳에서 고정합니다.
- 모든 것을 **사용자 범위**에만 설치하고 **관리자 권한(sudo)을 쓰지 않습니다**:
  `~/.local`, `~/.hermes-paperclip-native`, `~/.paperclip`(macOS·Linux),
  `%LOCALAPPDATA%`, `%USERPROFILE%`(Windows).
- 로컬 서버를 띄우고(Paperclip `127.0.0.1:3100`, Hermes 대시보드 `127.0.0.1:9119`)
  로그온 시 자동 시작을 등록합니다(LaunchAgent / systemd user / 작업 스케줄러).
- 릴리스 번들은 `checksums.txt`(sha256)로 검증한 뒤 실행합니다.

## 취약점 제보

**공개 이슈에 취약점을 올리지 마세요.** 저장소의 **GitHub Security Advisories**
(Security → "Report a vulnerability")로 비공개 제보해 주세요. 가능하면 재현 절차·영향
받는 버전·영향을 포함해 주세요.

## 범위

**이 저장소의 코드가 대상입니다:**
- 셸 설치기(`core/`, `platform/`, `entry/`), Windows PowerShell 설치기(`win/`)
- 부트스트랩 다운로드·검증, 릴리스 번들과 체크섬
- 자동 시작 등록, 업데이트, 제거

**대상이 아닙니다 (업스트림에 제보하세요):**
- Hermes Agent — 해당 프로젝트
- Paperclip(`paperclipai`) — 해당 프로젝트
- Node.js, uv, 그리고 그들의 종속 패키지

이 저장소는 그 코드를 설치·구성할 뿐, 소유하거나 보증하지 않습니다.

## 지원 범위

- 최신 릴리스와 `main` 브랜치를 대상으로 합니다.
- 개인 프로젝트라 응답은 **최선 노력(best effort)** 입니다.

## 고지

이 프로젝트는 Hermes Agent·Paperclip 의 제작자와 제휴·보증 관계가 없는 **비공식
서드파티 설치기**입니다. 두 이름은 각 프로젝트/소유자의 것입니다.
