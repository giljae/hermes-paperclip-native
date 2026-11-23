#!/usr/bin/env bash
# 8단계: 홈에 관리용 파일을 만든다. 다운로드 폴더를 지워도 계속 쓸 수 있게 하기 위함이다.
#
# 각 파일은 매니페스트에서 설치된 버전을 읽어 앱 디렉터리를 찾는다. 그래서
# 업데이트 후에도(버전이 바뀌어도) 그대로 동작한다.

HC_SHORTCUTS="시작:start:시작|중지:stop:중지|상태:status:상태 확인|AI연결:connect:AI 연결|업데이트:update:업데이트|제거:uninstall:제거"

shortcut_dir() { printf '%s/HermesPaperclip' "$HOME"; }

shortcut_render() {
  local cmd="$1" title="$2"
  sed -e "s|@@CMD@@|$cmd|g" -e "s|@@TITLE@@|$title|g" <<'SCRIPT'
#!/bin/bash
printf '\033]0;%s\007' "Hermes + Paperclip — @@TITLE@@"
HC_HOME="${HC_HOME:-$HOME/.hermes-paperclip-native}"
VER="$(sed -n 's/^INSTALLER_VERSION=//p' "$HC_HOME/manifest.env")"
"$HC_HOME/app/$VER/core/run.sh" @@CMD@@
printf '\n'
read -r -p '계속하려면 Enter 키를 누르세요...' _
SCRIPT
}

step_shortcuts() {
  local dir entry name rest cmd title
  dir="$(shortcut_dir)"
  mkdir -p "$dir" || return 0

  local IFS='|'
  for entry in $HC_SHORTCUTS; do
    name="${entry%%:*}"
    rest="${entry#*:}"
    cmd="${rest%%:*}"
    title="${rest#*:}"
    shortcut_render "$cmd" "$title" > "$dir/$name.command"
    chmod +x "$dir/$name.command"
  done

  # 사용방법.html 은 Task 21 에서 만들어진다. 있으면 함께 복사한다.
  local html; html="$(hc_root)/entry/사용방법.html"
  [ -f "$html" ] && cp "$html" "$dir/사용방법.html"

  return 0
}
