.PHONY: verify

verify:
	python3 -I scripts/config-audit.py
	bash tests/config-audit.sh
	bash tests/hooks.sh
	bash tests/pr-scripts.sh
	bash tests/config-install.sh
