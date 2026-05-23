# Prioritiser — build automation.
# Primary entry points (per project conventions): `make build`, `make run`.

SCHEME       := Prioritiser
PROJECT      := Prioritiser.xcodeproj
CONFIG       ?= Debug
DERIVED      := build
DESTINATION  := platform=macOS
APP          := $(DERIVED)/Build/Products/$(CONFIG)/Prioritiser.app

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
		CODE_SIGNING_ALLOWED=NO $(PRETTY)

.PHONY: run
run: build ## Build then launch the app
	@echo "Launching $(APP)..."
	open "$(APP)"

.PHONY: test
test: $(PROJECT) ## Run the unit test suite
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		CODE_SIGNING_ALLOWED=NO

.PHONY: deploy
deploy: $(PROJECT) ## Build a Release archive (signing/notarization done separately)
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-archivePath $(DERIVED)/Prioritiser.xcarchive \
		CODE_SIGNING_ALLOWED=NO
	@echo "Archive at $(DERIVED)/Prioritiser.xcarchive"
	@echo "To distribute: sign + notarize the exported .app (not yet automated)."

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf $(DERIVED)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) >/dev/null 2>&1 || true

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
