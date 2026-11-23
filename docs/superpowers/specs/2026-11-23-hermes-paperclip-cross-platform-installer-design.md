# Hermes + Paperclip 크로스플랫폼 설치기 — 설계

작성일: 2026-11-23
상태: 검토 대기 (승인 전 구현 금지)
버전: v3 (macOS 전용 → macOS / Linux / Windows 3종으로 확대)

---

## 1. 의도 (왜)

**터미널에 익숙하지 않은 사람**이 Hermes Agent + Paperclip을 자기 컴퓨터에 설치하고 쓸 수 있게 한다.
설치·업데이트·자동 시작·제거를 하나의 도구가 한국어로 처리한다.

지원 대상 3종: **macOS / Linux / Windows**

성공의 정의: 컴퓨터를 잘 모르는 사람이 **명령 한 줄(macOS는 더블클릭도 가능)** 로 시작해서
15분 뒤 브라우저에서 자기 AI 팀을 본다. 그리고 그 뒤로는 **아무것도 관리하지 않아도** 돌아간다.

### 1.1 우리가 만드는 것 / 만들지 않는 것

**Hermes↔Paperclip 연동은 이미 Paperclip의 내장 기능이다.** 이 프로젝트는 그것을 다시 만들지 않는다.

| | |
|---|---|
| 이미 있음 (Paperclip) | `hermes_local` 내장 어댑터(플러그인 불필요), `hermes_gateway`(원격, 내장), 세션 지속(`--resume`), 스킬 통합(`~/.hermes/skills/`), 토큰·비용 파싱, 트랜스크립트 UI, 환경 테스트, worktree·체크포인트 |
| ❌ 만들지 않음 | 연동 로직, 어댑터, 프로토콜, 스킬 시스템 |
| ✅ 만듦 | 두 프로그램을 **일반인이 설치하게 하는 것** (Node·Python·Hermes·Paperclip 자동 설치, 무sudo) |
| ✅ 만듦 | 어댑터를 골라주는 것 — seed 단계의 `"adapterType": "hermes_local"` 한 줄 |
| ✅ 만듦 | 자동 시작 / 업데이트 / 롤백 / 제거 / 한국어 UX / 배포 포장 |

즉 이 프로젝트는 **"Paperclip 기능 개발"이 아니라 "설치·운영 UX 제품"** 이다.
따라서 리스크는 연동이 아니라 **설치와 배포**에 있다(17절).

## 2. 목표

- **입력 최소.** macOS는 더블클릭, Linux/Windows는 한 줄 복붙. 그 외에는 아무것도 타이핑하지 않는다.
- **관리자 권한 0회.** 모든 설치가 사용자 홈 안에서 끝난다. 시스템을 건드리지 않는다.
- **한국어.** 화면·오류·안내가 전부 한국어이고 전문용어를 쓰지 않는다.
- **자동 시작.** 로그인하면 알아서 떠 있다.
- **업데이트 포함.** 설치기 자신 + Paperclip + Hermes를 한 명령으로 갱신하고, 실패하면 되돌린다.
- **되돌리기.** 제거 하나로 설치 전 상태로 돌아간다.
- **멱등.** 여러 번 실행해도 안전하고, 이미 된 단계는 건너뛴다.

## 3. 비목표 / 안티골

비목표:
- 서명·공증된 네이티브 앱(.app/.msi/.pkg). 승격 절차만 문서로 남긴다.
- GUI 앱(별도 프로젝트).
- 서버·다중 사용자·원격 배포.
- 모바일.

안티골:
- 관리자 권한을 요구하거나 시스템 디렉터리를 수정하는 것.
- 사용자가 이미 쓰던 Hermes 설정(`~/.hermes`, `%LOCALAPPDATA%\hermes`)을 덮어쓰거나 지우는 것.
- 실패했는데 창이 닫혀서 사용자가 아무것도 모르게 되는 것.
- 실패 원인이 영어 스택트레이스로만 보이는 것.
- 검증하지 않은 OS를 "지원한다"고 표기하는 것.

## 4. 제약 (실측 + 공식 문서)

| 항목 | 값 | 영향 |
|---|---|---|
| 개발/검증 환경 | macOS 26.7.3 / Apple Silicon | **macOS만 직접 검증 가능.** Linux/Windows는 CI 필요 |
| `hermes-agent` | 0.19.0, `requires_python >=3.11,<3.14` | Python **3.13** 핀. 휠이 `py3-none-any` → 컴파일 불필요 |
| launchd 기본 PATH | 비어 있음 | 자동 시작이 `node`/`hermes`를 못 찾음 → PATH를 명시해야 함 |
| `/usr/local/bin` | root 소유 | sudo 없이는 못 씀 → 쓰지 않음 |
| Paperclip 서비스 | macOS/Linux만 | **Windows는 서비스 없음** → `paperclipai run`을 직접 관리 |
| Paperclip 요구 | Node.js 24.11+ | Node를 설치기가 직접 넣어야 함 |
| Windows Defender | `uv.exe` 오탐 이력 (Hermes 문서 명시) | Windows 설치 안내에 예외 처리 절차 필요 |
| GitHub repo | 공개 | Releases로 배포 가능 |

## 5. 접근법 (결정 이력)

| 결정 | 선택 | 기각한 것 |
|---|---|---|
| 설치 방식 | **터미널/더블클릭 스크립트** | 완전한 GUI 앱 (별도 프로젝트) |
| 배포 | **서명 없음 + 경고 안내** | .app/.pkg/.msi 서명 ($99/년 + 빌드 파이프라인) |
| 지원 범위 | **macOS + Linux + Windows** | macOS만 / macOS+Linux |
| 진입점 vs 툴 | **코어 1개 + OS별 얇은 진입점** | OS별 설치 툴 (유지비 3배, 얻는 것 적음) |
| 구현 언어 | **POSIX sh(mac/Linux) + PowerShell(Windows)** | 단일 바이너리(Go/Rust): 툴체인·크로스컴파일·Windows 서명 문제 |

구현 언어를 sh + PowerShell로 고른 이유: 구현체가 2개뿐이고, 툴체인이 필요 없고,
**사용자가 스크립트를 읽고 검증할 수 있다**(한 줄 설치에서 중요). 업데이트는 바이너리 없이도
매니페스트 + zip 교체로 충분하다.

## 6. 아키텍처

```
entry/       ← 사용자가 만나는 것. 최소한의 부트스트랩만
  bootstrap.sh          curl | bash (macOS/Linux)
  bootstrap.ps1         irm | iex    (Windows)
  설치.command           macOS 더블클릭 (bootstrap을 로컬에서 호출)

core/        ← OS 중립 로직 (POSIX sh)
  run.sh                진입점: install | update | start | stop | status | uninstall
  manifest.sh           설치 상태 기록/판정
  fetch.sh              다운로드 + sha256 검증 + 압축 해제
  steps/*.sh            10-preflight … 90-verify
  ui.sh                 한국어 출력, 박스, 단계 표시

platform/    ← 여기만 OS별
  macos.sh  linux.sh  windows.ps1

tests/       ← CI 매트릭스에서 실행
```

**핵심 규칙**: `core/`는 `platform/`이 제공하는 함수만 호출한다. `core/` 안에 `launchctl`이나
`systemd` 같은 단어가 나오면 잘못 짠 것이다.

### 배포물 (GitHub Releases)

```
bootstrap.sh                     # 진입점 (curl용)
bootstrap.ps1                    # 진입점 (Windows)
HermesPaperclip-macOS-<ver>.zip  # 더블클릭 번들 (bootstrap.sh + 설치.command + 사용방법.html)
hermes-paperclip-<ver>.zip       # 코어+플랫폼 (bootstrap이 내려받는 실제 알맹이)
hermes-paperclip.zip             # 위와 같은 내용의 "최신" 고정 이름
VERSION                          # 최신 버전 문자열
checksums.txt                    # sha256
```

**이름 규칙**: 부트스트랩은 `releases/latest/download/VERSION`을 먼저 읽어 버전을 알아낸 뒤
`hermes-paperclip-<ver>.zip`을 받는다. 동시에 `hermes-paperclip.zip`이라는 **버전 없는 이름**도
같이 올려, 부트스트랩이 단순하게 동작할 수 있는 길을 남긴다.

## 7. 플랫폼 인터페이스 (계약)

각 `platform/*` 파일은 아래를 구현한다. 이름과 의미는 3종 모두 동일하다.

| 함수 | 하는 일 |
|---|---|
| `p_detect` | OS·아키텍처 판별, 결과를 전역 변수로 |
| `p_preflight` | OS 최소 버전, 디스크 여유, 네트워크, 기존 설치 감지 |
| `p_bin_dir` | 실행 파일을 둘 디렉터리 (`~/.local/bin` / Windows `%LOCALAPPDATA%\bin`) |
| `p_data_dir` | Paperclip 데이터 위치 (`~/.paperclip`) |
| `p_app_dir` | 우리 상태·로그 위치 (`~/.hermes-paperclip-native`) |
| `p_install_node` | Node 24 확보 (없으면 설치) |
| `p_install_uv` | uv 확보 |
| `p_install_hermes` | `uv tool install hermes-agent==<pin>` |
| `p_install_paperclip` | managed install |
| `p_persist_path` | 새 셸에서도 `bin`이 잡히게 등록 |
| `p_autostart_install` | 자동 시작 등록 + 시작 |
| `p_autostart_remove` | 자동 시작 해제 |
| `p_autostart_status` | 실행 중 여부 |
| `p_server_url` | 실제 대시보드 주소 (설정에서 포트를 읽음) |
| `p_open_browser` | 브라우저 열기 (헤드리스면 건너뛰고 URL만 출력) |
| `p_tail_log` | 로그 최근 N줄 |
| `p_has_display` | GUI 세션 여부 (Linux 헤드리스 판별) |

## 8. OS별 동작

| | macOS | Linux | Windows |
|---|---|---|---|
| 기본 진입점 | 더블클릭 + 한 줄 | 한 줄 | 한 줄 |
| 자동 시작 | LaunchAgent (직접 작성, PATH 명시) | systemd user (+linger) | Task Scheduler |
| 브라우저 | `open` | `xdg-open` (없으면 URL 출력) | `start` |
| Node 배포본 | `darwin-arm64` / `darwin-x64` | `linux-x64` / `linux-arm64` | `win-x64.zip` |
| PATH 등록 | 셸 프로필 + (자동 시작 plist의 PATH) | 셸 프로필 | `setx` |
| 더블클릭 | ✅ `.command` | ❌ 파일 관리자가 편집기로 엶 → 한 줄 | ❌ `.ps1`은 실행 안 됨 → 한 줄 |
| 서명 경고 | Gatekeeper "확인되지 않은 개발자" | 없음 | SmartScreen |
| 특이사항 | — | 배포판/glibc 차이, 헤드리스 대응 | Defender `uv.exe` 오탐 안내 |

**자동 시작을 직접 구현하는 이유**: launchd는 PATH가 비어 있어 어댑터가 `hermes`를 못 찾는다.
plist에 PATH를 박아 넣어야 한다. 같은 이유로 Windows Task Scheduler에도 PATH를 명시한다.

## 9. 저장소 구조

```
hermes-paperclip-native/
├── VERSION
├── Makefile                     # dist | test | ci | release | clean
├── README.md                    # 개발자용
├── entry/
│   ├── bootstrap.sh
│   ├── bootstrap.ps1
│   ├── 설치.command
│   └── 사용방법.html
├── core/
│   ├── run.sh
│   ├── ui.sh
│   ├── manifest.sh
│   ├── fetch.sh
│   └── steps/
│       ├── 10-preflight.sh  ├── 20-node.sh      ├── 30-paperclip.sh
│       ├── 40-hermes.sh     ├── 50-onboard.sh   ├── 60-autostart.sh
│       ├── 70-seed.sh       ├── 75-shortcuts.sh ├── 80-open.sh
│       ├── 90-verify.sh     ├── update.sh       └── uninstall.sh
├── platform/
│   ├── macos.sh
│   ├── linux.sh
│   ├── windows.ps1
│   └── launchagent.plist.template
├── tests/
│   ├── smoke.sh                 # mac/Linux: 실제 설치→검증→업데이트→제거
│   ├── smoke.ps1                # Windows: 동일
│   └── helpers.sh
├── .github/workflows/ci.yml     # 3-OS 매트릭스
├── docs/
│   ├── architecture.md
│   ├── troubleshooting.md
│   ├── signing.md               # 나중에 서명으로 승격하는 절차
│   └── superpowers/specs/2026-11-23-hermes-paperclip-cross-platform-installer-design.md
└── dist/                        # 빌드 산출물 (gitignore)
```

## 10. 사용자 여정

### 10.1 macOS (더블클릭)

zip 다운로드 → 압축 해제 → `사용방법.html` 확인 → `설치.command` **우클릭 → 열기** →
한국어 진행 8단계 → 브라우저 자동 오픈 → `~/HermesPaperclip/` 폴더에 관리용 파일 생성.

### 10.2 macOS / Linux (한 줄)

```bash
curl -fsSL https://github.com/giljae/hermes-paperclip-native/releases/latest/download/bootstrap.sh | bash
```

Gatekeeper를 아예 거치지 않는다. `.command`보다 마찰이 적다.

### 10.3 Windows (한 줄)

```powershell
irm https://github.com/giljae/hermes-paperclip-native/releases/latest/download/bootstrap.ps1 | iex
```

SmartScreen 경고 시 "추가 정보 → 실행"을 안내하고, Defender의 `uv.exe` 오탐 대응도 함께 안내한다.

### 10.4 진행 화면 (3종 공통, macOS 예시)

```
╭──────────────────────────────────────────────╮
│  Hermes + Paperclip 설치                     │
│  이 창은 그대로 두세요. 자동으로 진행됩니다. │
╰──────────────────────────────────────────────╯

[1/8] 이 컴퓨터를 확인하는 중...
      ✓ macOS 26.7.3 (Apple Silicon)
      ✓ 저장 공간 12.4GB 여유
      ✓ 인터넷 연결 정상

[2/8] Node.js를 설치하는 중... (약 1분)
      ✓ Node.js v24.20.0
...
[8/8] 브라우저를 엽니다...
      ✓ http://localhost:3100

╭──────────────────────────────────────────────╮
│  설치가 끝났습니다!                          │
│  브라우저에서 대시보드가 열렸습니다.         │
│  이 창은 닫아도 됩니다.                      │
│                                              │
│  마지막으로 AI를 연결해 주세요:              │
│  'AI연결'을 실행하세요.                      │
╰──────────────────────────────────────────────╯
```

### 10.5 AI 연결 (별도 단계)

진입 방법은 OS마다 같지 않다:

- macOS: `~/HermesPaperclip/AI연결.command` (더블클릭)
- macOS/Linux: `curl -fsSL .../bootstrap.sh | bash -s connect`
- Windows: `irm .../bootstrap.ps1 | iex` 후 안내에 따라 `connect`

```
  1) Nous Portal로 간편 로그인  (추천 · 카드 등록 한 번, API 키 불필요)
  2) 내 API 키 사용 (Anthropic / OpenAI / OpenRouter)
  3) 나중에 하기
```

연결이 끝나면 **Paperclip의 "Test your agent"와 같은 확인**을 우리가 대신 실행해
"연결 성공" 또는 실패 원인을 한국어로 보여준다.

그리고 예산을 한 번 제안한다(Paperclip은 설정 흐름에서 예산을 안 잡으므로, 우리가 안전망을 대신 제안):

```
  지출 폭주를 막기 위해 월 예산을 걸어둘까요?
  Paperclip은 CEO에게 월 $30~50을 권장합니다.

  1) 월 $30으로 설정 (권장)
  2) 직접 입력
  3) 설정하지 않음
```

### 10.6 평소 / 업데이트 / 제거

- 로그인하면 자동으로 떠 있다.
- `상태` → 실행 여부, 대시보드 주소, 버전, 최근 로그, "브라우저 열기".
- `업데이트` → 설치기 + Paperclip + Hermes 갱신 → 자동 재시작 → 실패 시 롤백.
- `제거` → 무엇이 지워지는지 나열 → 확인 1회 → 자동 시작 해제 → 파일 삭제.
  **설치 전부터 있던 Hermes는 보존**한다.

## 11. 설치 단계

| 단계 | 하는 일 | 실패 시 |
|---|---|---|
| 1 preflight | OS/아키텍처, 디스크 3GB, 네트워크, 기존 설치 감지, `hermes_existed` 기록 | 중단 + 이유 |
| 2 node | Node 24 확보 → `p_bin_dir`에 노출 | 다운로드 1회 재시도 |
| 3 paperclip | managed install (`paperclipai@<pin>`) | 재시도 안내 |
| 4 hermes | uv → `uv python install 3.13` → `uv tool install hermes-agent==0.19.0` | 로그 안내 |
| 5 onboard | `PAPERCLIP_NO_BROWSER=1 paperclipai onboard --yes` | doctor 출력 |
| 6 autostart | 자동 시작 등록 + 헬스 폴링 | plist/작업 이름 안내 |
| 7 seed | `company create` → `agent create`(`hermes_local`) | 회사 없이도 성공 처리, 재실행 안내 |
| 8 shortcuts | macOS: `~/HermesPaperclip/`에 관리 파일 복사 | 다운로드 폴더 유지 안내 |
| 9 open | `p_open_browser <실제 주소>` | URL 직접 출력 |

규칙:
- 모든 `paperclipai` 호출은 `PAPERCLIP_HOME`을 **명시적으로** export 한다(CLI가 다른 인스턴스를 보는 사고 방지).
- 6·9단계는 **설정에 기록된 실제 포트**를 읽는다(3100이 점유되면 대체 포트가 쓰임).

### 시드되는 에이전트

**Paperclip의 관례를 따른다** (확인된 사실):
- 첫 에이전트는 **항상 CEO** (역할을 고르지 않음)
- **timed heartbeat은 기본 꺼짐** ("New agents start with their timed heartbeat switched off")
- 설정 흐름은 **예산 상한을 잡지 않는다**. 대신 CEO에게 월 $30~50을 권장
- 이름과 회사 이름은 Paperclip이 **사용자에게 직접 묻는다**. 우리는 "질문 0개"라 기본값을 넣고
  UI에서 바꿀 수 있게 한다

```json
{
  "name": "CEO",
  "role": "ceo",
  "adapterType": "hermes_local",
  "adapterConfig": { "persistSession": true, "timeoutSec": 1800, "quiet": true },
  "runtimeConfig": { "heartbeat": { "enabled": false } },
  "instructionsBundle": { "files": { "AGENTS.md": "You are the CEO agent of this Paperclip company. Plan strategy, break it into tasks, and delegate. Keep reports short." } }
}
```

- **`budgetMonthlyCents`를 넣지 않는다** — Paperclip과 동일. heartbeat가 꺼져 있어 지출이 0이다.
  예산 안전망은 설치가 아니라 `AI연결` 단계에서 한 번 제안한다(권장 $30 — Paperclip의 $30~50 범위).
- 회사 기본 이름은 `내 AI 회사`(UI에서 변경 가능).
- 모델은 비워 둔다 → Hermes가 자기 설정(`~/.hermes/config.yaml`)의 모델을 쓴다.
- `paperclipai test-drive`를 쓰지 않는 이유: 문서가 **"evaluation and demos, not for a company you
  intend to keep"** 이라고 못박았고 일회용 데이터 디렉터리를 쓴다. **내용만 따르고 경로는
  durable한 `onboard` + `run`을 쓴다.**

## 12. 매니페스트와 자체 업데이트

`~/.hermes-paperclip-native/install.json` (3 OS 공통 경로 — 코드 단순화를 위한 의도적 선택)

```json
{
  "schemaVersion": 1,
  "installerVersion": "0.1.0",
  "installedAt": "2026-11-23T12:00:00Z",
  "platform": "macos-arm64",
  "hermesExisted": false,
  "node": { "version": "24.20.0" },
  "paperclip": { "version": "2026.1117.0" },
  "hermes": { "version": "0.19.0" },
  "python": { "version": "3.13" },
  "autostart": "ing.hermes-paperclip.agent"
}
```

업데이트 절차:
1. 최신 `VERSION`과 `checksums.txt` 확인
2. 바뀐 게 없으면 "이미 최신입니다"로 종료
3. 새 `hermes-paperclip-<ver>.zip` 다운로드 → sha256 검증 → `app/<ver>/`에 해제
4. `paperclipai update`, `hermes update` 실행
5. 자동 시작 재시작 → 헬스 확인
6. **실패하면 이전 `app/<old>/`로 되돌리고** 그 사실을 한국어로 알림
7. 성공 시 `install.json` 갱신

## 13. 검증 전략

| 검사 | 방법 |
|---|---|
| 3 OS에서 실제로 설치되는가 | GitHub Actions 매트릭스 (ubuntu / macos / windows)에서 `tests/smoke` |
| 멱등한가 | 같은 러너에서 2회 실행 → 2회차는 전부 skip |
| 제거가 원상복구하는가 | 설치 → 제거 → 홈에 잔여물 0 |
| 업데이트가 되는가 | 이전 버전 설치 → 최신으로 업데이트 → 버전 확인 |
| 실패 처리가 되나 | 잘못된 URL/네트워크 차단으로 강제 실패 → 창 유지 + 한국어 조치 |
| 자동 시작이 되나 | CI에서는 `--no-autostart`로 건너뛰고, macOS에서 수동 1회 검증 |
| 어댑터가 Hermes를 찾나 | `paperclipai agent get <id>` + 수동 `smoke`(과금, opt-in) |

CI에서 무거운 다운로드를 줄이려면 캐시를 쓰고, 실패 시 로그를 아티팩트로 올린다.
`--no-autostart`, `--no-open`, `--dry-run` 플래그를 코어에 둔다.

## 14. 수용 기준

1. macOS에서 더블클릭만으로, Linux/Windows에서 한 줄만으로 설치가 끝난다.
2. 관리자 권한을 한 번도 요구하지 않는다.
3. 설치 후 브라우저(또는 헤드리스면 출력된 URL)에서 대시보드가 열린다.
4. `agent list`에 `hermes_local` 에이전트가 있다.
5. **API 키가 하나도 없어도** 설치가 성공 종료한다.
6. 시드된 에이전트가 **Paperclip 관례와 일치**한다: 이름 `CEO`, role `ceo`, timed heartbeat 꺼짐,
   예산 미설정.
7. 재로그인 후에도 서버가 자동으로 떠 있다(macOS/Linux/Windows 각각).
8. 두 번 실행하면 전부 skip되고 부작용이 없다.
9. 제거 후 홈에 잔여물이 없다(원래 있던 Hermes는 보존).
10. 모든 사용자 노출 문구가 한국어다.
11. 강제 실패 시 창이 닫히지 않고 한국어 조치와 로그 경로를 보여준다.
12. **CI 매트릭스 3종이 모두 통과**한다.
13. 업데이트 후 버전이 실제로 올라가고, 실패 시 롤백된다.

## 15. 구현 순서

| 단계 | 내용 | 완료 기준 |
|---|---|---|
| **P1** | core + platform/macos + entry + tests | 이 Mac에서 설치→검증→업데이트→제거 성공 |
| **P2** | platform/linux + CI(ubuntu) | ubuntu 러너에서 smoke 통과 |
| **P3** | platform/windows.ps1 + CI(windows) + bootstrap.ps1 | windows 러너에서 smoke 통과 |
| **P4** | 배포물/문서/사용방법.html/스크린샷 | 릴리스 zip 생성, 사람이 읽고 따라할 수 있음 |

각 단계는 **별도의 계획 문서**로 만든다. P1이 끝나야 P2를 계획한다.

## 16. Builder에게 남기는 것

- `p_install_node`의 구현 방식(포터블 tarball vs OS 패키지) — 무sudo 우선.
- **릴리스 파일 이름 규칙과 `VERSION` 파싱 방식**(6절 규칙을 구현으로 확정).
- preflight의 최소 OS 버전 기준(macOS 13? Ubuntu 22.04? Windows 10 21H2?).
- Linux 배포판 지원 범위(glibc 요구사항 실측).
- `hermes_local` 어댑터가 `hermes`를 찾는 방식(PATH vs 절대경로) — PATH로 가정했으나 실측 필요.
- 회사 이름(기본 `내 AI 회사`)·`issuePrefix`, 에이전트 이름(기본 `CEO`)·AGENTS.md 문구.
  Paperclip 관례(첫 에이전트는 CEO, heartbeat off, 예산 미설정)를 유지할 것.
- macOS `사용방법.html`의 문구와 스크린샷.
- 로그 로테이션(최근 5MB 유지 등).
- CI 캐시 전략과 아티팩트 보존 기간.

## 17. 미확인 리스크 (구현 초반에 실측)

1. **Gatekeeper(macOS)**: zip으로 받아 압축 푼 `.command`의 더블클릭이 macOS 26에서 어떻게
   동작하는지, 우클릭→열기가 통하는지. 안 통하면 한 줄 설치를 기본으로 안내한다.
2. **`onboard --yes`의 블로킹 여부**: 포그라운드 서버를 띄우면 자동 시작 등록과 충돌한다.
3. **uv 설치 Python 3.13에서 hermes-agent 0.19.0의 120개 의존성이 전부 휠로 해결되는지**
   (컴파일이 필요하면 관리자 권한이 필요해져 안티골 위반).
4. **자동 시작 환경에서 `paperclipai run`이 뜨는지** (managed install shim이 node를 찾는지).
5. **Windows에서의 Paperclip**: 서비스가 없으므로 Task Scheduler 등록 방식과
   `paperclipai run`의 장기 실행 안정성.
6. **Windows Defender의 `uv.exe` 오탐** 빈도와, 설치기가 안내해야 할 정확한 절차.
7. **Linux 헤드리스**(GUI 없음)에서의 동작: 브라우저 열기를 건너뛰고 URL만 출력.
8. **PowerShell의 한국어 출력 인코딩**: Windows PowerShell 5.1은 기본 인코딩 때문에 한글이
   깨질 수 있다. `.ps1`을 UTF-8(BOM)으로 저장하고 `[Console]::OutputEncoding`을 설정해야 한다.
   기능이 아니라 "글자가 깨지는" 문제라 수용 기준 9번이 조용히 깨질 수 있다.
