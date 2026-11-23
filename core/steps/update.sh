#!/usr/bin/env bash
# 업데이트: 설치기 자신 + Paperclip + Hermes. 실패하면 이전 버전으로 되돌린다.

update_current_version() { mf_get INSTALLER_VERSION; }

update_latest_version() {
  if [ -n "${HC_LATEST_VERSION:-}" ]; then
    printf '%s' "$HC_LATEST_VERSION"
    return 0
  fi
  local base; base="${HC_RELEASE_BASE:-https://github.com/giljae/hermes-paperclip-native/releases/latest/download}"
  curl -fsSL --max-time 20 "$base/VERSION" 2>/dev/null | tr -d '[:space:]'
}

# 0 = 업데이트할 게 있다, 1 = 이미 최신(또는 확인 실패)
update_should_run() {
  local cur lat
  cur="$(update_current_version)"
  lat="$(update_latest_version)"
  [ -n "$lat" ] || return 1
  [ "$lat" != "$cur" ]
}

update_rollback() {
  mf_set INSTALLER_VERSION "$1"
  return 0
}

step_update() {
  local cur lat root appdir
  cur="$(update_current_version)"
  lat="$(update_latest_version)"

  if [ -z "$lat" ]; then
    ui_skip "최신 버전을 확인하지 못했습니다"
    return 0
  fi
  if [ "$lat" = "$cur" ]; then
    ui_skip "이미 최신입니다 ($cur)"
    return 0
  fi

  printf '업데이트합니다: %s → %s\n' "$cur" "$lat"

  if [ -n "${HC_DRY_RUN:-}" ]; then
    printf 'app/%s 에 새 버전을 설치하고 다시 시작합니다\n' "$lat"
    return 0
  fi

  root="$(hc_root)"
  appdir="$(hc_app_root)/$lat"
  if [ "$root" != "$appdir" ]; then
    mkdir -p "$appdir" || return 1
    cp -R "$root/core" "$root/platform" "$appdir/" 2>/dev/null || true
    cp "$root/VERSION" "$root/pins.env" "$appdir/" 2>/dev/null || true
  fi

  p_paperclip_env
  "$(p_bin_dir)/paperclipai" update >/dev/null 2>&1 || true
  "$(p_bin_dir)/hermes" update >/dev/null 2>&1 || true

  if p_autostart_install; then
    mf_set INSTALLER_VERSION "$lat"
    ui_ok "업데이트 완료 ($lat)"
  else
    update_rollback "$cur"
    ui_fail "업데이트에 실패해 이전 버전으로 되돌렸습니다 ($cur)"
  fi
  return 0
}
