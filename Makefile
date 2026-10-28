.PHONY: verify

verify:
	python3 -I scripts/config-audit.py
	bash tests/config-audit.sh
	bash tests/hooks.sh
