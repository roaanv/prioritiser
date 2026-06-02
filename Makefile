# Prioritiser — build automation.
# Primary entry points (per project conventions): `make build`, `make run`.

SCHEME       := Prioritiser
PRODUCT_NAME := Prioritiser
PROJECT      := Prioritiser.xcodeproj
CONFIG       ?= Debug
DERIVED      := build
ARCHS        := arm64
DESTINATION  := platform=macOS,arch=$(ARCHS)
APP          := $(DERIVED)/Build/Products/$(CONFIG)/Prioritiser.app
# Release pipeline output (Apple Silicon app, signed + notarized in CI).
RELEASE_APP  := $(DERIVED)/Build/Products/Release/$(PRODUCT_NAME).app
ENTITLEMENTS := Prioritiser.entitlements

.DEFAULT_GOAL := build

.PHONY: setup
setup: ## Install tooling if needed and generate the Xcode project
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "xcodegen not found — installing via Homebrew..."; \
		brew install xcodegen; }
	xcodegen generate
	@echo "Project generated. Next: make build"

.PHONY: generate
generate: ## (Re)generate the Xcode project from project.yml
	xcodegen generate

$(PROJECT): project.yml
	xcodegen generate

# Pipe through xcbeautify when available, otherwise raw xcodebuild output.
PRETTY := $(shell command -v xcbeautify >/dev/null 2>&1 && echo "| xcbeautify")

.PHONY: build
build: $(PROJECT) ## Build the app
	set -o pipefail && xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		ARCHS="$(ARCHS)" \
		CODE_SIGNING_ALLOWED=NO $(PRETTY)

.PHONY: run
run: build ## Build then launch the app
	@echo "Launching $(APP)..."
	open "$(APP)"

.PHONY: install
install: $(PROJECT) ## Build an Apple Silicon Release app and copy it to ~/Applications
	@echo "Building $(PRODUCT_NAME) (Release, Apple Silicon)..."
	set -o pipefail && xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(DERIVED) \
		ARCHS="$(ARCHS)" \
		CODE_SIGNING_ALLOWED=NO $(PRETTY)
	@mkdir -p "$$HOME/Applications"
	@rm -rf "$$HOME/Applications/$(PRODUCT_NAME).app"
	@cp -R "$(RELEASE_APP)" "$$HOME/Applications/"
	@echo "Installed ~/Applications/$(PRODUCT_NAME).app — launch it from Spotlight or the Dock."

.PHONY: test
test: $(PROJECT) ## Run the unit test suite
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		ARCHS="$(ARCHS)" \
		CODE_SIGNING_ALLOWED=NO

.PHONY: deploy
deploy: $(PROJECT) ## Build a Release archive (signing/notarization done separately)
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-archivePath $(DERIVED)/Prioritiser.xcarchive \
		ARCHS="$(ARCHS)" \
		CODE_SIGNING_ALLOWED=NO
	@echo "Archive at $(DERIVED)/Prioritiser.xcarchive"
	@echo "For signed/notarized distribution use the release pipeline below (see RELEASE.md)."

# ── Release pipeline ─────────────────────────────────
# Produces a signed, notarized, Apple Silicon .app for distribution outside the
# Mac App Store. CI drives these in order (.github/workflows/release.yml); see
# RELEASE.md for the secret setup.
#
#   make release                                              # unsigned arm64 build
#   make sign        SIGNING_IDENTITY="Developer ID Application: …"
#   make notarize-app                  API_KEY_PATH=… API_KEY_ID=… API_ISSUER_ID=…
#   make dmg         TAG=v1.0.0                               # package stapled .app as .dmg
#   make notarize-dmg NOTARIZE_PATH=…  API_KEY_PATH=… API_KEY_ID=… API_ISSUER_ID=…
#   make archive     TAG=v1.0.0                               # package stapled .app as .zip

.PHONY: release
release: $(PROJECT) ## Build an unsigned Apple Silicon Release .app
	@echo "Building $(PRODUCT_NAME) (Release, Apple Silicon)..."
	set -o pipefail && xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(DERIVED) \
		ARCHS="$(ARCHS)" \
		ONLY_ACTIVE_ARCH=NO \
		CODE_SIGNING_ALLOWED=NO $(PRETTY)
	@echo "Built $(RELEASE_APP)"

.PHONY: sign
sign: ## Developer ID sign the release .app (requires SIGNING_IDENTITY)
	@if [ -z "$(SIGNING_IDENTITY)" ]; then echo "Error: SIGNING_IDENTITY is required"; exit 1; fi
	@echo "Signing $(RELEASE_APP)..."
	codesign --force --sign "$(SIGNING_IDENTITY)" \
		--entitlements "$(ENTITLEMENTS)" \
		--options runtime \
		--timestamp \
		"$(RELEASE_APP)"
	@echo "Verifying signature..."
	codesign --verify --deep --strict --verbose=2 "$(RELEASE_APP)"

# Notarize the .app: submit a temporary ZIP wrapper to Apple's notary service,
# wait for acceptance, then staple the ticket directly onto the .app so every
# downstream package (.dmg/.zip) carries an already-stapled bundle.
.PHONY: notarize-app
notarize-app: ## Notarize + staple the signed .app (requires API_KEY_PATH/ID/ISSUER)
	@if [ -z "$(API_KEY_PATH)" ]; then echo "Error: API_KEY_PATH is required"; exit 1; fi
	@if [ -z "$(API_KEY_ID)" ]; then echo "Error: API_KEY_ID is required"; exit 1; fi
	@if [ -z "$(API_ISSUER_ID)" ]; then echo "Error: API_ISSUER_ID is required"; exit 1; fi
	@echo "Creating temporary ZIP for notary submission..."
	@rm -f "$(DERIVED)/notarize-submission.zip"
	ditto -c -k --sequesterRsrc --keepParent "$(RELEASE_APP)" "$(DERIVED)/notarize-submission.zip"
	@echo "Submitting .app to Apple notary service..."
	xcrun notarytool submit "$(DERIVED)/notarize-submission.zip" \
		--key "$(API_KEY_PATH)" \
		--key-id "$(API_KEY_ID)" \
		--issuer "$(API_ISSUER_ID)" \
		--wait
	@rm -f "$(DERIVED)/notarize-submission.zip"
	@echo "Stapling ticket onto .app..."
	xcrun stapler staple "$(RELEASE_APP)"
	xcrun stapler validate "$(RELEASE_APP)"

.PHONY: dmg
dmg: ## Package the (stapled) .app as a .dmg (requires TAG)
	@if [ -z "$(TAG)" ]; then echo "Error: TAG is required (e.g. make dmg TAG=v1.0.0)"; exit 1; fi
	@echo "Creating DMG..."
	@rm -rf "$(DERIVED)/dmg-staging"
	@mkdir -p "$(DERIVED)/dmg-staging"
	@cp -R "$(RELEASE_APP)" "$(DERIVED)/dmg-staging/"
	@ln -s /Applications "$(DERIVED)/dmg-staging/Applications"
	hdiutil create \
		-volname "$(PRODUCT_NAME)" \
		-srcfolder "$(DERIVED)/dmg-staging" \
		-ov -format UDZO \
		"$(DERIVED)/$(PRODUCT_NAME)-$(TAG)-arm64.dmg"
	@rm -rf "$(DERIVED)/dmg-staging"
	@echo "Created $(DERIVED)/$(PRODUCT_NAME)-$(TAG)-arm64.dmg"

# Notarize a DMG that already contains a stapled .app — the DMG gets its own
# ticket (tied to its outer hash). Run after `make notarize-app && make dmg`.
.PHONY: notarize-dmg
notarize-dmg: ## Notarize + staple a DMG (requires NOTARIZE_PATH + API_KEY_PATH/ID/ISSUER)
	@if [ -z "$(NOTARIZE_PATH)" ]; then echo "Error: NOTARIZE_PATH is required"; exit 1; fi
	@if [ -z "$(API_KEY_PATH)" ]; then echo "Error: API_KEY_PATH is required"; exit 1; fi
	@if [ -z "$(API_KEY_ID)" ]; then echo "Error: API_KEY_ID is required"; exit 1; fi
	@if [ -z "$(API_ISSUER_ID)" ]; then echo "Error: API_ISSUER_ID is required"; exit 1; fi
	@echo "Submitting $(NOTARIZE_PATH) for notarization..."
	xcrun notarytool submit "$(NOTARIZE_PATH)" \
		--key "$(API_KEY_PATH)" \
		--key-id "$(API_KEY_ID)" \
		--issuer "$(API_ISSUER_ID)" \
		--wait
	@echo "Stapling DMG..."
	xcrun stapler staple "$(NOTARIZE_PATH)"
	xcrun stapler validate "$(NOTARIZE_PATH)"

# ZIP is just a container for the stapled .app — ZIPs can't be stapled directly,
# so no separate notarization is needed.
.PHONY: archive
archive: ## Package the (stapled) .app as a .zip (requires TAG)
	@if [ -z "$(TAG)" ]; then echo "Error: TAG is required (e.g. make archive TAG=v1.0.0)"; exit 1; fi
	@echo "Archiving $(PRODUCT_NAME)-$(TAG)-arm64.zip..."
	ditto -c -k --sequesterRsrc --keepParent \
		"$(RELEASE_APP)" \
		"$(DERIVED)/$(PRODUCT_NAME)-$(TAG)-arm64.zip"
	@echo "Created $(DERIVED)/$(PRODUCT_NAME)-$(TAG)-arm64.zip"

.PHONY: gh-secrets
gh-secrets: ## Push release secrets from the macOS Keychain to the GitHub repo
	@command -v gh >/dev/null 2>&1 || { echo "Error: gh CLI not found. Install with: brew install gh"; exit 1; }
	@gh auth status >/dev/null 2>&1 || { echo "Error: gh CLI is not authenticated. Run: gh auth login"; exit 1; }
	@if ! gh repo view --json nameWithOwner -q .nameWithOwner >/dev/null 2>&1; then \
		echo "Skipping gh-secrets: this repository doesn't exist on GitHub yet."; \
		echo "Create it first with: gh repo create --source . --private --push"; \
		exit 0; \
	fi
	@./scripts/set-gh-release-secrets.sh

.PHONY: release-patch
release-patch: ## Bump patch MARKETING_VERSION, tag, and push (triggers a release)
	@./scripts/bump-release.sh patch

.PHONY: release-minor
release-minor: ## Bump minor MARKETING_VERSION, tag, and push (triggers a release)
	@./scripts/bump-release.sh minor

.PHONY: icon
icon: ## Regenerate the app icon asset set from tools/make_icon.swift
	@ICONSET="Sources/Resources/Assets.xcassets/AppIcon.appiconset"; \
	swift tools/make_icon.swift "$$ICONSET/icon_1024.png"; \
	for sz in 16 32 64 128 256 512; do \
		sips -z $$sz $$sz "$$ICONSET/icon_1024.png" --out "$$ICONSET/icon_$${sz}.png" >/dev/null; \
	done; \
	echo "Icon regenerated in $$ICONSET"

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf $(DERIVED)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) >/dev/null 2>&1 || true

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
