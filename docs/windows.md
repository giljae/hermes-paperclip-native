# Windows 설치

## 한 줄 설치

PowerShell 창(시작 메뉴에서 `PowerShell` 검색)을 열고 아래 한 줄을 붙여 넣습니다.

```powershell
irm https://github.com/giljae/hermes-paperclip-native/releases/latest/download/bootstrap.ps1 | iex
```

**관리자 권한은 필요 없습니다.** 모든 것이 사용자 폴더(`%LOCALAPPDATA%`, `%USERPROFILE%`) 안에
설치됩니다. `Set-ExecutionPolicy` 로 막히면 다음 한 줄을 먼저 실행하세요.

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

> **관리자 권한에서도 동작합니다.** 설치기가 승격된 토큰을 감지하면 Paperclip 서버를
> 제한 권한(Basic User)으로 실행합니다 — 내장 PostgreSQL 이 관리자 토큰에서 기동을
> 거부하기 때문입니다. 다만 특별한 이유가 없으면 일반(비관리자) PowerShell 창에서
> 실행하는 편이 가장 단순합니다.

## 지원 환경

| | |
|---|---|
| 운영체제 | **Windows 10 21H2+ / Windows 11** (64비트) |
| PowerShell | 기본 내장된 **Windows PowerShell 5.1** (별도 설치 불필요) |
| 아키텍처 | x64, arm64 |
| 자동 시작 | 작업 스케줄러(로그온 시). 등록할 수 없으면 백그라운드 실행으로 폴백 |

설치는 `%LOCALAPPDATA%\hermes-paperclip-native` 아래에서만 이루어지고,
시스템 PATH는 건드리지 않습니다(사용자 PATH 뒤에 **없을 때만** 덧붙입니다).

## 설치 후

| | |
|---|---|
| 실행 파일 | `%LOCALAPPDATA%\hermes-paperclip-native\bin` (paperclipai, hermes, uv) |
| Node.js | `%LOCALAPPDATA%\hermes-paperclip-native\node` |
| Paperclip 데이터 | `%USERPROFILE%\.paperclip` |
| 설치 상태·로그 | `%LOCALAPPDATA%\hermes-paperclip-native` (`logs\install.log`) |
| 관리용 파일 | `%USERPROFILE%\HermesPaperclip` (시작·중지·상태·AI연결·업데이트·제거) |
| 대시보드 | `http://127.0.0.1:3100` (포트가 쓰이면 다른 포트) |

관리용 파일은 더블클릭하면 됩니다. 각 파일은 `manifest.env` 에서 설치된 버전을 읽어
앱 위치를 찾으므로, 업데이트 후에도 그대로 동작합니다.

설치가 끝나면 `AI연결.cmd` 를 실행해 모델을 연결하세요(Nous Portal 로그인 또는 API 키).
아래 한 줄로도 됩니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\hermes-paperclip-native\app\<버전>\win\commands.ps1" connect
```

## Windows Defender 안내

Defender가 `uv.exe` 를 바이러스로 잘못 인식해 격리할 수 있습니다(알려진 오탐).
설치 중 파일이 사라지거나 `uv` 를 찾을 수 없다는 오류가 나면:

1. **Windows 보안 → 바이러스 및 위협 방지 → 설정 관리 → 제외 → 제외 추가**
2. 폴더 제외로 `%LOCALAPPDATA%\hermes-paperclip-native` 를 추가
3. 설치를 다시 실행

## 자동 시작 (작업 스케줄러)

로그인할 때 자동으로 켜지도록 **작업 스케줄러**에 등록됩니다.

```powershell
schtasks /Query /TN hermes-paperclip
```

권한 문제로 등록이 안 되면 설치기는 실패하지 않고 **백그라운드 실행**으로 대체합니다.
그 경우 `시작.cmd` / `중지.cmd` 로 직접 제어하세요.

## 상태 확인과 제어

```powershell
schtasks /Query /TN hermes-paperclip     # 자동 시작 상태
Get-Content "$env:LOCALAPPDATA\hermes-paperclip-native\logs\server.log" -Tail 20
```

또는 `%USERPROFILE%\HermesPaperclip\상태.cmd` 를 실행하세요.

## 제거

`%USERPROFILE%\HermesPaperclip\제거.cmd` 를 더블클릭하거나:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\hermes-paperclip-native\app\<버전>\win\commands.ps1" uninstall
```

설치 전부터 쓰던 Hermes 설정(`%USERPROFILE%\.hermes`)이 있으면 **그대로 둡니다.**

## 문제가 생겼을 때

| 증상 | 확인 |
|---|---|
| 스크립트가 실행되지 않음(실행 정책) | `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` |
| `uv` 를 찾을 수 없음 / 설치 중 파일이 사라짐 | Windows Defender 제외 폴더 추가(위 절차) |
| 한글이 깨져 보임 | Windows PowerShell 5.1 + UTF-8 콘솔 문제입니다. 최신 설치기로 다시 실행하세요 |
| 새 터미널에서 `hermes` 가 없음 | 사용자 PATH 확인 후 터미널을 새로 열기(설치기는 기존 PATH를 보존합니다) |
| 서버가 안 뜸 | `%LOCALAPPDATA%\hermes-paperclip-native\logs\server.log` 확인 |
| 관리자 권한으로 실행함 | 설치기가 서버를 제한 권한으로 대신 실행합니다. 문제가 있으면 일반(비관리자) 창에서 다시 실행하세요 |
| 설치가 실패함 | `%LOCALAPPDATA%\hermes-paperclip-native\logs\install.log` 를 전달해 주세요 |
