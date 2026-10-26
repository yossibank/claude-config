.PHONY: setup open format licenses build test-build test verify

SIMULATOR ?= $(shell xcrun simctl list devices available iPhone | awk -F '[()]' '/iPhone/ { print $$2; exit }')
XCBEAUTIFY = $(shell command -v xcbeautify)
BEAUTIFY = $(if $(XCBEAUTIFY),| xcbeautify)
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
	set -o pipefail; xcodebuild -workspace ios/__App__.xcworkspace -scheme __App__ -destination 'generic/platform=iOS Simulator' build $(BEAUTIFY)

test-build:
	set -o pipefail; xcodebuild -workspace ios/__App__.xcworkspace -scheme __App__ -testPlan __App__ -destination 'id=$(SIMULATOR)' build-for-testing $(BEAUTIFY)

test:
	set -o pipefail; xcodebuild -workspace ios/__App__.xcworkspace -scheme __App__ -testPlan __App__ -destination 'id=$(SIMULATOR)' test $(BEAUTIFY)

verify:
	scripts/verify.sh swift test --package-path ios/Packages/__App__Kit
	scripts/verify.sh xcodebuild -workspace ios/__App__.xcworkspace -scheme __App__ -destination 'generic/platform=iOS Simulator' build
