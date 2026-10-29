.PHONY: setup open format licenses build test-build test snapshot verify

SIMULATOR ?= $(shell scripts/find-simulator.sh)
XCBEAUTIFY = $(shell command -v xcbeautify)
BEAUTIFY = $(if $(XCBEAUTIFY),| xcbeautify)
XCODEBUILD = xcodebuild -workspace ios/__App__.xcworkspace -scheme __App__
ANY_SIMULATOR = -destination 'generic/platform=iOS Simulator'
ON_SIMULATOR = -destination 'id=$(SIMULATOR)'
CLAUDE_CONFIG ?= $(HOME)/Applications/AI/claude-config
SNAPSHOT ?=
CHECKOUT = $(if $(BRANCH),$(shell git worktree list --porcelain | awk '/^worktree / { path = substr($$0, 10) } $$0 == "branch refs/heads/$(BRANCH)" { print path }'),.)

setup:
	brew bundle
	mint bootstrap
	pre-commit install

open:
	@test -n "$(CHECKOUT)" || { echo "$(BRANCH) のワークツリーが無い"; exit 1; }
	open "$(CHECKOUT)/ios/__App__.xcworkspace"

format:
	mint run swiftformat .

licenses:
	cd ios && mint run --mintfile ../Mintfile LicensePlist --xcworkspace-path __App__.xcworkspace --config-path license_plist.yml --output-path __App__/Settings.bundle --add-version-numbers --add-sources --suppress-opening-directory --fail-if-missing-license --force
	rm -f ios/__App__/Settings.bundle/com.mono0926.LicensePlist.latest_result.txt

build:
	set -o pipefail; $(XCODEBUILD) $(ANY_SIMULATOR) build $(BEAUTIFY)

test-build:
	@test -n "$(SIMULATOR)" || { echo "NG iPhone のシミュレーターが無い。SIMULATOR に UDID を渡す"; exit 1; }
	set -o pipefail; $(XCODEBUILD) -testPlan __App__ $(ON_SIMULATOR) build-for-testing $(BEAUTIFY)

test:
	@test -n "$(SIMULATOR)" || { echo "NG iPhone のシミュレーターが無い。SIMULATOR に UDID を渡す"; exit 1; }
	set -o pipefail; $(XCODEBUILD) -testPlan __App__ $(ON_SIMULATOR) -collect-test-diagnostics never test $(BEAUTIFY)

snapshot:
	@test -n "$(SNAPSHOT)" || { echo "NG SNAPSHOT に .claude/snapshots/ の下のセットの名前を渡す"; exit 1; }
	$(CLAUDE_CONFIG)/skills/ui-snapshot/scripts/render-snapshots.sh ios/Packages/__App__App .claude/snapshots/$(SNAPSHOT) .build/snapshots/$(SNAPSHOT)

verify:
	scripts/verify.sh kit-test swift test --package-path ios/Packages/__App__Kit
	scripts/verify.sh app-build $(XCODEBUILD) $(ANY_SIMULATOR) build
