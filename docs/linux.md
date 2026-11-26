# Linux 설치

## 한 줄 설치

```bash
curl -fsSL https://github.com/giljae/hermes-paperclip-native/releases/latest/download/bootstrap.sh | bash
```

관리자 권한(sudo)은 **필요 없습니다.** 모든 것이 사용자 홈 안에 설치됩니다.

## 지원 환경

| | |
|---|---|
| 배포판 | **Ubuntu 22.04+ / Debian 12+** (glibc 2.35 이상) |
| 아키텍처 | x64, arm64 |
| 자동 시작 | systemd user (없으면 백그라운드 실행으로 폴백) |

glibc가 2.35보다 낮으면 설치를 시작하지 않고 이유를 한국어로 알려줍니다.
root로 실행하면 거부합니다 — 설치한 것을 일반 사용자만 쓸 수 있게 되기 때문입니다.

## 설치 후

| | |
|---|---|
| 위치 | `~/.local/bin` (paperclipai, hermes, uv) · `~/.local/node` · `~/.paperclip` |
| 로그 | `~/.hermes-paperclip-native/logs/` |
| 관리 파일 | `~/HermesPaperclip/` (시작·중지·상태·AI연결·업데이트·제거) |
| 대시보드 | `http://127.0.0.1:3100` (포트가 쓰이면 다른 포트) |

설치가 끝나면 **AI 연결**을 실행하세요. **웹 설정 화면**(http://127.0.0.1:9119)이 브라우저에
열립니다(헤드리스면 URL만 출력). `~/HermesPaperclip/AI연결` 또는:

```bash
curl -fsSL https://github.com/giljae/hermes-paperclip-native/releases/latest/download/bootstrap.sh | bash -s connect
```

## 서버(헤드리스)에서

GUI가 없으면 브라우저를 열지 않고 **주소만 출력**합니다. 그 주소를 다른 컴퓨터의
브라우저에서 열려면 SSH 터널을 쓰세요(AI 연결 화면은 9119, Paperclip 대시보드는 3100):

```bash
# AI 연결(Hermes 설정 화면)
ssh -L 9119:127.0.0.1:9119 사용자@서버
# 그 뒤 내 컴퓨터에서 http://127.0.0.1:9119

# Paperclip 대시보드
ssh -L 3100:127.0.0.1:3100 사용자@서버
# 그 뒤 내 컴퓨터에서 http://127.0.0.1:3100
```

## 상태 확인과 제어

```bash
systemctl --user status hermes-paperclip    # 자동 시작 상태
systemctl --user restart hermes-paperclip   # 재시작
journalctl --user -u hermes-paperclip -f    # 로그 따라가기 (systemd 를 쓰는 경우)
```

또는 `~/HermesPaperclip/상태` 를 실행하세요.

systemd가 없는 환경(컨테이너, WSL)에서는 자동 시작을 등록하지 못하고
백그라운드 프로세스로 실행합니다. 로그아웃하면 멈추므로, 그런 환경에서는
`~/HermesPaperclip/시작` 으로 다시 켜면 됩니다.

## 제거

```bash
~/HermesPaperclip/제거
```

설치 전부터 쓰던 Hermes 설정(`~/.hermes`)이 있으면 **그대로 둡니다.**

## 문제가 생겼을 때

| 증상 | 확인 |
|---|---|
| "glibc ... 너무 오래되었습니다" | Ubuntu 22.04+ / Debian 12+ 로 올리거나 다른 머신을 쓰세요 |
| "root 로 실행하지 마세요" | 일반 사용자 계정으로 다시 실행하세요 |
| 설치는 됐는데 새 터미널에서 `hermes` 가 없음 | `~/.profile` / `~/.bashrc` 의 `# hermes-paperclip: PATH` 줄 확인, 그 뒤 셸을 새로 열기 |
| 서버가 안 뜸 | `~/.hermes-paperclip-native/logs/server.log` 확인 |
| 설치가 실패함 | `~/.hermes-paperclip-native/logs/install.log` 를 전달해 주세요 |
