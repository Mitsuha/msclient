VERSION ?= $(shell sed -n 's/^version:[[:space:]]*//p' pubspec.yaml)
MSI_VERSION ?= $(shell printf '%s\n' "$(VERSION)" | sed -E 's/^([0-9]+)\.([0-9]+)\.[0-9]+\+([0-9]+)$$/\1.\2.\3/')
OUT_DIR ?= dist

WINDOWS_BUNDLE ?= build/windows/x64/runner/Release
LINUX_BUNDLE ?= build/linux/x64/release/bundle
MACOS_APP ?= build/macos/Build/Products/Release/Mirrorstages.app
APP_ICON ?= assets/icon/app_icon_256.png

.PHONY: package-windows package-linux package-macos windows linux macos

package-windows:
	pwsh -File packaging/windows/build-msi.ps1 \
		-Version "$(VERSION)" \
		-MsiVersion "$(MSI_VERSION)" \
		-SourceDir "$(WINDOWS_BUNDLE)" \
		-OutDir "$(OUT_DIR)"

package-linux:
	bash packaging/linux/build-deb.sh \
		"$(VERSION)" \
		"$(LINUX_BUNDLE)" \
		"$(APP_ICON)" \
		"$(OUT_DIR)"

package-macos:
	bash packaging/macos/build-dmg.sh \
		"$(VERSION)" \
		"$(MACOS_APP)" \
		"$(OUT_DIR)"

windows: package-windows
linux: package-linux
macos: package-macos
