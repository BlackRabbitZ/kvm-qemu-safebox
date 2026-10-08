.PHONY: check release-check sbom release lint
check:
	bash -n safebox install/*.sh host/*.sh network/*.sh guest/*.sh tools/*.sh tests/*.sh
	python3 -m py_compile tools/*.py
	bash tests/shellcheck-directives.sh
	bash tests/static-policy.sh
	bash tests/network-policy.sh
	bash tests/render-smoke.sh
	bash tests/qemu-cve-policy.sh
	bash tests/resource-policy.sh
	bash tests/profile-policy.sh
	bash tests/mutated-xml.sh
	bash tests/watchdog-failclosed.sh
	bash tests/regressions-v051.sh
	bash tests/regressions-v051-rc2.sh
	bash tests/audit-regressions.sh
	bash tests/rc4-malware-isolation.sh
	python3 tests/rc5-security-gate.py

release-check: check
	bash tests/release-check.sh
	bash tests/release-artifacts.sh
	bash tests/release-signature.sh

sbom:
	bash tools/generate-sbom.sh

release:
	bash tools/build-release.sh

# Requires ShellCheck: install it locally before pushing changes to CI.
lint:
	@command -v shellcheck >/dev/null || { echo "[FAIL] shellcheck is required (apt install shellcheck)" >&2; exit 127; }
	shellcheck safebox install/*.sh host/*.sh network/*.sh guest/*.sh tools/*.sh tests/*.sh
