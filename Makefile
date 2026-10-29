ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: verify audit test

verify: audit test

audit:
	python3 -I $(ROOT)scripts/config-audit.py

test:
	@failed=0; \
	for test in $(ROOT)tests/*.sh; do echo "bash $$test"; bash "$$test" || failed=$$((failed + 1)); done; \
	[ $$failed -eq 0 ] || { echo "NG 落ちたテスト: $$failed 本"; exit 1; }

test-%: $(ROOT)tests/%.sh
	bash $(ROOT)tests/$*.sh
