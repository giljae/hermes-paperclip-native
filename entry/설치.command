#!/bin/bash
printf '\033]0;%s\007' "Hermes + Paperclip 설치"
cd "$(dirname "$0")" || exit 1
bash ./bootstrap.sh install
printf '\n'
read -r -p '계속하려면 Enter 키를 누르세요...' _
