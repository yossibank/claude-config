ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

TESTS := $(wildcard $(ROOT)tests/hooks/*.sh $(ROOT)tests/scripts/*.sh $(ROOT)tests/skills/*.sh)

.PHONY: verify audit test

verify: audit test

audit:
	python3 -I $(ROOT)scripts/config-audit.py

test:
	@failed=0; \
	for test in $(TESTS); do echo "bash $$test"; bash "$$test" || failed=$$((failed + 1)); done; \
	[ $$failed -eq 0 ] || { echo "NG 落ちたテスト: $$failed 本"; exit 1; }

test-%:
	@found=0; \
	for test in $(filter %/$*.sh,$(TESTS)); do found=1; echo "bash $$test"; bash "$$test" || exit 1; done; \
	[ $$found -eq 1 ] || { echo "NG テストが無い: $*"; exit 1; }
