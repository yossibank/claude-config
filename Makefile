.PHONY: verify audit test

verify: audit test

audit:
	python3 -I scripts/config-audit.py

test:
	@for test in tests/*.sh; do echo "bash $$test"; bash "$$test" || exit 1; done
