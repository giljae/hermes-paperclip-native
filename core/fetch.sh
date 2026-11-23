#!/usr/bin/env bash
# 다운로드, sha256 검증, 압축 해제.
#
# macOS 에는 sha256sum 이 없으므로 shasum -a 256 을 쓴다.

ft_download() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")" 2>/dev/null || true
  curl -fsSL --retry 2 --connect-timeout 15 --max-time 600 -o "$dest" "$url" || return 1
}

ft_sha256() {
  local f="$1"
  [ -f "$f" ] || return 1
  shasum -a 256 "$f" | awk '{print $1}'
}

ft_verify() {
  local f="$1" expected="$2"
  [ -f "$f" ] || return 1
  [ "$(ft_sha256 "$f")" = "$expected" ]
}

ft_extract() {
  local archive="$1" dest="$2"
  mkdir -p "$dest" 2>/dev/null || true
  case "$archive" in
    *.zip)
      command -v unzip >/dev/null 2>&1 || hc_die "unzip 명령을 찾을 수 없습니다."
      unzip -q -o "$archive" -d "$dest"
      ;;
    *.tar.gz|*.tgz)
      command -v tar >/dev/null 2>&1 || hc_die "tar 명령을 찾을 수 없습니다."
      tar -xzf "$archive" -C "$dest"
      ;;
    *)
      hc_die "알 수 없는 압축 형식입니다: $archive"
      ;;
  esac
}

ft_fetch_and_verify() {
  local url="$1" dest="$2" expected="$3"
  ft_download "$url" "$dest" || hc_die "다운로드에 실패했습니다: $url"
  ft_verify "$dest" "$expected" || hc_die "내려받은 파일이 손상되었습니다(체크섬 불일치): $(basename "$dest")"
}
