# hermes-paperclip-native

Hermes Agent와 Paperclip을 **일반 사용자**가 설치하고 쓸 수 있게 해 주는 설치기입니다.
Docker가 필요 없고, 관리자 권한도 필요 없습니다.

- **macOS / Linux** — 한 줄 명령
- **Windows** — 아직 미지원 (계획만 있음)

Paperclip의 `hermes_local` 어댑터는 **이미 내장 기능**입니다. 이 저장소는 그 연동을 만드는 것이
아니라, **두 프로그램을 설치·자동 시작·업데이트·제거하는 UX**를 만듭니다.

## 설치

```bash
curl -fsSL https://github.com/giljae/hermes-paperclip-native/releases/latest/download/bootstrap.sh | bash
```

macOS에서는 릴리스의 `HermesPaperclip-macOS.zip` 을 더블클릭하는 방법도 있지만,
최신 macOS는 서명 없는 스크립트를 막습니다 — **한 줄 명령을 권장합니다.**

설치 후 `AI연결` 을 실행해 모델을 연결하세요(Nous Portal 로그인 또는 직접 API 키).

자세한 안내: [macOS·Linux 사용 안내](entry/사용방법.html) · [Linux 설치](docs/linux.md)

## 무엇이 설치되나

| | |
|---|---|
| 실행 파일 | `~/.local/bin` (paperclipai, hermes, uv) |
| Node.js | `~/.local/node` (공식 포터블 tarball, 무sudo) |
| Python | uv가 관리하는 3.13 |
| Paperclip 데이터 | `~/.paperclip` |
| 설치 상태·로그 | `~/.hermes-paperclip-native` |
| 관리용 파일 | `~/HermesPaperclip` (시작·중지·상태·AI연결·업데이트·제거) |
| 자동 시작 | macOS: LaunchAgent · Linux: systemd user (없으면 백그라운드) |

## 개발

```bash
make test      # 단위 테스트 (138+)
make dist      # 배포물 생성 (macOS 전용, ditto 사용)
make release   # GitHub Releases 에 게시 (gh)
HC_SMOKE_REAL=1 bash tests/smoke.sh   # 실제 설치 E2E (무겁다. 약 4GB 다운로드)
```

구조: `core/`(OS 중립) + `platform/common.sh` + `platform/<os>.sh` + `entry/`.
`core/` 에 OS 이름이 나오면 잘못 짠 것입니다.

- 구조 노트: [docs/architecture.md](docs/architecture.md)
- 설계 문서: `docs/superpowers/specs/`
- 구현 계획: `docs/superpowers/plans/` (P1 macOS 완료, P2 Linux 진행 중, P3 Windows 미착수)

### CI

`macos-latest` 와 `ubuntu-latest` 에서 단위 테스트 + DRY_RUN 스모크를 돌립니다.
실제 설치 스모크는 무거워서 `workflow_dispatch` 전용입니다:

```bash
gh workflow run CI --ref main
```

## 라이선스

Apache-2.0 ([LICENSE](LICENSE))
