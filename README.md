# hermes-paperclip-native

Hermes Agent와 Paperclip을 **일반 사용자**가 설치하고 쓸 수 있게 해 주는 설치기입니다.
Docker가 필요 없고, 관리자 권한도 필요 없습니다.

- **macOS / Linux** — 한 줄 명령
- **Windows** — 한 줄 PowerShell 명령

Paperclip의 `hermes_local` 어댑터는 **이미 내장 기능**입니다. 이 저장소는 그 연동을 만드는 것이
아니라, **두 프로그램을 설치·자동 시작·업데이트·제거하는 UX**를 만듭니다.

> **비공식 도구입니다.** Hermes Agent 와 Paperclip 의 제작자와 제휴·보증 관계가 없습니다.
> 두 이름은 각 프로젝트/소유자의 것이며, 이 저장소는 그들을 설치·구성해 주는 서드파티
> 설치기입니다. 취약점 제보는 [SECURITY.md](SECURITY.md) 를 보세요.

## 빠른 시작

처음이라면 이 순서만 기억하세요.

1. **설치** — 아래 한 줄 명령을 붙여 넣습니다. (인터넷 속도에 따라 10~20분, 관리자 권한 불필요)
2. **AI 연결** — 홈의 `HermesPaperclip` 폴더에서 **`AI연결`** 을 실행해 모델·API 키를 넣습니다.
3. **사용** — 브라우저에서 대시보드 `http://127.0.0.1:3100` 을 엽니다.

> 각 기능이 **무엇을·어떻게·왜** 하는지는 아래 [기능](#기능) 절에 하나씩 쉬운 말로 정리해 두었습니다.

## 설치

macOS · Linux:

```bash
curl -fsSL https://github.com/giljae/hermes-paperclip-native/releases/latest/download/bootstrap.sh | bash
```

Windows (PowerShell):

```powershell
irm https://github.com/giljae/hermes-paperclip-native/releases/latest/download/bootstrap.ps1 | iex
```

macOS에서는 릴리스의 `HermesPaperclip-macOS.zip` 을 더블클릭하는 방법도 있지만,
최신 macOS는 서명 없는 스크립트를 막습니다 — **한 줄 명령을 권장합니다.**

설치 후 `AI연결` 을 실행하면 **웹 설정 화면**(http://127.0.0.1:9119)이 브라우저에 열립니다. 거기서 모델·API 키를 연결하세요.

자세한 안내: [macOS·Linux 사용 안내](entry/사용방법.html) · [Linux 설치](docs/linux.md) · [Windows 설치](docs/windows.md)

## 무엇이 설치되나

| | |
|---|---|
| 실행 파일 | `~/.local/bin` (paperclipai, hermes, uv) |
| Node.js | `~/.local/node` (공식 포터블 tarball, 무sudo) |
| Python | uv가 관리하는 3.13 |
| Paperclip 데이터 | `~/.paperclip` |
| 설치 상태·로그 | `~/.hermes-paperclip-native` |
| 관리용 파일 | `~/HermesPaperclip` (시작·중지·상태·AI연결·업데이트·제거) |
| 자동 시작 | macOS: LaunchAgent · Linux: systemd user (없으면 백그라운드) · Windows: 작업 스케줄러 (없으면 백그라운드) |

Windows 경로는 홈이 아니라 사용자 폴더를 쓴다: 실행 파일 `%LOCALAPPDATA%\hermes-paperclip-native\bin`,
데이터 `%USERPROFILE%\.paperclip`, 관리용 파일 `%USERPROFILE%\HermesPaperclip`. 자세한 내용은
[Windows 설치](docs/windows.md) 참고.

## 기능

각 기능이 **무엇을 하는지**, **어떻게 쓰는지**, **왜 이렇게 만들었는지**를 쉽게 설명합니다.

### 1. 설치 — 한 줄 명령

macOS·Linux 는 터미널에, Windows 는 PowerShell 에 **한 줄**만 붙여 넣으면 됩니다.
**관리자 권한(sudo·“관리자로 실행”)이 필요 없습니다.** 모든 것을 사용자 폴더 안에만 설치합니다.

설치 중에는 아래 9단계가 차례로 진행되고, 화면에 `[3/9] …` 처럼 표시됩니다.

| 단계 | 하는 일 |
|---|---|
| 1 | 이 컴퓨터 확인 (운영체제·버전·CPU) |
| 2 | Node.js 설치 (공식 포터블 배포본, 시스템에 영향 없음) |
| 3 | Paperclip 설치 (`paperclipai`) |
| 4 | Hermes 설치 (Python + uv 관리) |
| 5 | 초기 설정 (Paperclip 설정 파일 + 내장 데이터베이스 준비) |
| 6 | 자동 시작 등록 |
| 7 | AI 팀 만들기 (회사 + CEO 에이전트 자동 생성) |
| 8 | 관리용 파일 만들기 |
| 9 | 대시보드 브라우저로 열기 |

### 2. 다시 실행해도 안전 (멱등)

**같은 한 줄 명령을 몇 번을 다시 실행해도 안전합니다.** 이미 끝난 단계는
`· Node.js를 설치하는 중... (건너뜀)` 처럼 건너뜁니다. 그래서 설치가 중간에 실패했거나
궁금할 때 그냥 다시 실행하면 이어서 진행됩니다.

### 3. AI 연결 — 웹 설정 화면

**설치만으로는 AI 가 연결되지 않습니다.** `AI연결` 을 실행하면 **Hermes 웹 설정 화면**
(`http://127.0.0.1:9119`)이 브라우저에 열립니다. 거기서 두 가지를 합니다.

- **모델** 화면: provider 와 모델 선택 (Nous Portal 로그인 또는 직접 API 키)
- **설정** 화면: API 키 입력 (Anthropic / OpenAI / OpenRouter 등)

API 키를 어디에 넣는지, 어떤 모델을 쓸지 같은 것을 **터미널 명령이 아니라 화면에서**
클릭으로 정합니다. 브라우저가 없는 서버(헤드리스)에서는 브라우저를 열지 않고 **주소만
출력**하니, 다른 컴퓨터에서 SSH 터널로 접속해 그 주소를 열면 됩니다. 화면을 띄우지
못하면 자동으로 기존 터미널 설정으로 넘어갑니다.

### 4. 관리용 파일 (더블클릭)

설치가 끝나면 홈에 **`HermesPaperclip`** 폴더가 생기고, 그 안에 파일 6개가 들어 있습니다.
**터미널을 몰라도 더블클릭**하면 됩니다.

| 파일 | 하는 일 |
|---|---|
| `시작` | 서버를 켭니다 |
| `중지` | 서버를 끕니다 |
| `상태` | 자동 시작 여부·주소·설치 버전을 보여줍니다 |
| `AI연결` | 모델·API 키를 넣는 웹 설정 화면을 엽니다 |
| `업데이트` | 최신 버전으로 올립니다 |
| `제거` | 깨끗하게 지웁니다 |

각 파일은 설치된 **버전을 스스로 찾아** 동작하므로, 업데이트로 버전이 바뀌어도 그대로
쓸 수 있습니다.

### 5. 자동 시작

로그인할 때 AI 서버가 **자동으로 켜지도록** 등록합니다. 운영체제별로:

- **macOS**: LaunchAgent
- **Linux**: systemd user 서비스 (없으면 백그라운드 실행)
- **Windows**: 작업 스케줄러 (권한이 없으면 백그라운드 실행)

권한 문제로 등록에 실패해도 **설치가 실패하지 않고** 백그라운드 실행으로 대체합니다.

### 6. 상태 확인

`상태` 를 실행하면 한눈에 보여줍니다: 자동 시작이 켜져 있는지, 서버 주소(`http://127.0.0.1:3100`),
설치된 Node.js / Paperclip / Hermes 버전.

### 7. 업데이트

`업데이트` 는 최신 버전을 확인하고, 설치기 자신과 Paperclip·Hermes 를 새 버전으로
올립니다. 이미 최신이면 아무 것도 하지 않습니다. **도중에 실패하면 이전 버전으로
되돌립니다**(롤백).

### 8. 제거

`제거` 는 자동 시작 등록을 풀고, 서버·데이터·앱·로그를 지웁니다. 실행 전에 무엇이
지워지는지 보여주고 확인을 받습니다.

> **중요:** 설치 **전부터** 쓰던 Hermes 설정(`~/.hermes`)이 있으면 **건드리지 않습니다.**
> 우리가 새로 만든 것만 지웁니다.

### 9. 로그 (문제 생겼을 때)

모든 기록은 `~/.hermes-paperclip-native/logs/` 에 있습니다(`install.log`, `server.log` 등).
문제가 생기면 이 폴더의 파일을 전달해 주세요.

### 10. 안전·프라이버시

- **관리자 권한을 쓰지 않습니다.** 시스템 폴더(`/usr/local`, `/Library` 등)를 건드리지 않고
  사용자 폴더에만 설치합니다.
- **PATH 를 덮어쓰지 않습니다.** 기존 PATH 뒤에 **없을 때만** 덧붙입니다.
- **로컬 전용.** 서버(`127.0.0.1:3100`)와 설정 화면(`127.0.0.1:9119`)은 내 컴퓨터에서만
  접근됩니다(외부 공개 안 함).
- **검증된 다운로드.** 릴리스 파일은 공식 출처에서 받고 `checksums.txt`(sha256)로 확인한 뒤 실행합니다.
- 버전은 `pins.env` 한 곳에서 고정합니다.

### 11. 플랫폼별 참고

- **macOS** — 서명 없는 스크립트는 Gatekeeper 가 막습니다. 그래서 **한 줄 명령을 권장**합니다
  (파일 더블클릭은 경고로 막혀 우회 절차가 필요합니다).
- **Windows** — 관리자 권한으로 실행해도 서버는 **제한 권한으로 자동 실행**됩니다(내장
  PostgreSQL 이 관리자 권한에서 뜨지 않기 때문). Defender 가 `uv.exe` 를 오탐으로 격리할 수
  있으니 [Windows 설치](docs/windows.md) 의 제외 폴더 안내를 참고하세요.
- **Linux** — systemd 가 없거나 컨테이너/WSL 이면 백그라운드로 대체합니다. GUI 가 없으면
  브라우저 대신 주소만 출력합니다.

## 개발

```bash
make test      # 단위 테스트 (셸 + PowerShell)
make dist      # 배포물 생성 (macOS 전용, ditto 사용)
make release   # GitHub Releases 에 게시 (gh)
HC_SMOKE_REAL=1 bash tests/smoke.sh        # 실제 설치 E2E · macOS/Linux (무겁다)
HC_SMOKE_REAL=1 pwsh -File tests/win/smoke.ps1   # 실제 설치 E2E · Windows
```

구조: `core/`(OS 중립) + `platform/common.sh` + `platform/<os>.sh` + `entry/` (bash),
`win/` (Windows PowerShell — `core.ps1` 가 OS 중립, `platform.ps1` 이 Windows 전용).
`core/` 에 OS 이름이 나오면 잘못 짠 것입니다.

- 구조 노트: [docs/architecture.md](docs/architecture.md)
- 설계 문서: `docs/superpowers/specs/`
- 구현 계획: `docs/superpowers/plans/` (P1 macOS, P2 Linux, P3 Windows 완료)

### CI

`macos-latest`, `ubuntu-latest`, `windows-latest` 에서 단위 테스트 + DRY_RUN 스모크를 돌립니다.
Windows 단위 테스트는 PowerShell 7 과 Windows PowerShell 5.1 양쪽에서 돌립니다.
실제 설치 스모크는 무거워서 `workflow_dispatch` 전용입니다:

```bash
gh workflow run CI --ref main
```

## 라이선스

Apache-2.0 ([LICENSE](LICENSE))
