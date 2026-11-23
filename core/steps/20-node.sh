#!/usr/bin/env bash
# 2단계: Node.js 확보.

step_node() {
  local want; want="${NODE_VERSION:-$(hc_pin NODE_VERSION)}"
  p_install_node || return 1
  # 새 셸에서도 hermes/paperclipai 를 찾을 수 있게 등록한다. 이걸 빠뜨리면
  # 설치 직후에는 동작하지만(우리가 PATH 를 앞에 붙였으므로) 터미널을 새로 열면
  # "명령을 찾을 수 없다"가 된다.
  p_persist_path || true
  mf_set NODE_VERSION "$want"
  return 0
}
