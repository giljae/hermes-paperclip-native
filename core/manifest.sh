#!/usr/bin/env bash
# 설치 상태 매니페스트. key=value 형식이라 bash 와 PowerShell 양쪽에서
# 파서 의존성 없이 읽힌다(JSON 이었다면 jq 나 python3 가 필요하다).

mf_path() { printf '%s/manifest.env' "$(hc_home)"; }

mf_exists() { [ -f "$(mf_path)" ]; }

mf_get() {
  local key="$1" f; f="$(mf_path)"
  [ -f "$f" ] || return 0
  sed -n "s/^${key}=//p" "$f" | head -n 1
}

mf_set() {
  local key="$1" value="$2" f tmp
  f="$(mf_path)"
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  tmp="$(mktemp)"
  if [ -f "$f" ]; then
    grep -v "^${key}=" "$f" > "$tmp" || true
  fi
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$f"
}

mf_dump() {
  [ -f "$(mf_path)" ] && cat "$(mf_path)"
  return 0
}
