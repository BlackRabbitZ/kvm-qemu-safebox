SHELL := /bin/bash

.PHONY: check release-check syntax xml policy network-policy render shellcheck

check: syntax xml policy network-policy render shellcheck

release-check: check
	bash ./tests/release-check.sh

syntax:
	bash -n safebox install/*.sh network/*.sh guest/*.sh tests/*.sh tools/*.sh

xml:
	@if command -v xmllint >/dev/null 2>&1; then \
		xmllint --noout network/safebox-net.xml vm/templates/*.xml.in; \
	else \
		python3 -c 'import glob,xml.etree.ElementTree as E; [E.parse(f) for f in ["network/safebox-net.xml",*glob.glob("vm/templates/*.xml.in")]]'; \
	fi

policy:
	bash ./tests/static-policy.sh

network-policy:
	bash ./tests/network-policy.sh

render:
	bash ./tests/render-smoke.sh

shellcheck:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck safebox install/*.sh network/*.sh guest/*.sh tests/*.sh tools/*.sh; \
	else \
		echo "[WARN] shellcheck nicht installiert – in GitHub Actions wird es ausgeführt."; \
	fi
