.PHONY: verify audit test

verify: audit test

audit:
	python3 -I scripts/config-audit.py

test:
	@failed=0; \
	for test in tests/*.sh; do echo "bash $$test"; bash "$$test" || failed=$$((failed + 1)); done; \
	[ $$failed -eq 0 ] || { echo "NG 落ちたテスト: $$failed 本"; exit 1; }

test-%: tests/%.sh
	bash tests/$*.sh
