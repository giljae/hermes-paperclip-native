SHELL := /usr/bin/env bash
VERSION := $(shell cat VERSION)
DIST := dist
MACOS_NAME := HermesPaperclip-macOS-$(VERSION)
GENERIC_NAME := hermes-paperclip-$(VERSION)

.PHONY: test dist release clean

test:
	bash tests/run.sh
	@if command -v pwsh >/dev/null 2>&1; then \
		pwsh -NoProfile -File tests/win/run.ps1; \
	else \
		echo 'pwsh 가 없어 PowerShell 테스트를 건너뜁니다'; \
	fi

# 배포물을 만든다.
#   dist/HermesPaperclip-macOS-<ver>.zip  — 더블클릭용(macOS)
#   dist/hermes-paperclip-<ver>.zip       — bootstrap 이 내려받는 알맹이(모든 OS)
#   dist/checksums.txt                    — sha256
#
# macOS 전용이다(ditto 사용). 릴리스는 개발자의 Mac 에서 만든다.
#
# ditto 를 쓰는 이유: zip 에 실행 권한(+x)이 보존되어야 한다. 권한이 사라지면
# 설치.command 를 더블클릭해도 실행되지 않는다(실제로 확인해야 하는 위험).
dist:
	rm -rf "$(DIST)/$(MACOS_NAME)" "$(DIST)/$(GENERIC_NAME)" "$(DIST)/pkg"
	mkdir -p "$(DIST)/$(MACOS_NAME)" "$(DIST)/pkg"
	cp -R core platform entry VERSION pins.env "$(DIST)/$(MACOS_NAME)/"
	cp -R core platform entry win VERSION pins.env "$(DIST)/pkg/"
	chmod +x "$(DIST)/$(MACOS_NAME)/entry/설치.command" "$(DIST)/$(MACOS_NAME)/entry/bootstrap.sh"
	chmod +x "$(DIST)/pkg/entry/bootstrap.sh"
	find "$(DIST)/pkg" -name '*.sh' -exec chmod +x {} \;
	ditto -c -k --sequesterRsrc --keepParent "$(DIST)/$(MACOS_NAME)" "$(DIST)/$(MACOS_NAME).zip"
	( cd "$(DIST)/pkg" && ditto -c -k --sequesterRsrc . "../$(GENERIC_NAME).zip" )
	rm -rf "$(DIST)/pkg" "$(DIST)/$(MACOS_NAME)"
	( cd "$(DIST)" && shasum -a 256 *.zip > checksums.txt )
	@echo "만들었습니다:"
	@ls -1 "$(DIST)"

release: dist
	gh release create "v$(VERSION)" \
	  "$(DIST)/$(MACOS_NAME).zip" "$(DIST)/$(GENERIC_NAME).zip" \
	  "$(DIST)/checksums.txt" VERSION \
	  entry/bootstrap.sh win/bootstrap.ps1 \
	  --title "Hermes + Paperclip v$(VERSION)" \
	  --notes "macOS 설치 안내는 내려받은 zip 안의 사용방법.html 을 보세요. Windows 는 docs/windows.md 를 보세요."

clean:
	rm -rf "$(DIST)"
