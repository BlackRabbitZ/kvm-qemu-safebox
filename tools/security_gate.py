#!/usr/bin/env python3
"""RC5 boot-bound hardware acceptance gate. Root-owned evidence, NOT a VM-escape proof.

No command-line option to bypass qualification or supply alternative evidence paths.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import time

VERSION = "0.5.1-rc5"
# All components that matter to acceptance must be immutable to unprivileged users.
FILES = (
    "/etc/safebox/defaults.conf", "/etc/libvirt/qemu.conf",
    "/usr/local/libexec/safebox/runtime.xml.in",
    "/usr/local/libexec/safebox/security_gate.py",
    "/usr/local/libexec/safebox/hardware-acceptance.py",
    "/usr/local/libexec/safebox/runtime-verify.sh",
    "/usr/local/libexec/safebox/storage-verify.sh",
    "/usr/local/libexec/safebox/kill-domain.sh",
    "/usr/local/libexec/safebox/runtime-watch.sh",
    "/usr/local/libexec/safebox/domain-pid.sh",
    "/usr/local/libexec/safebox/proc-absence.py",
    "/usr/local/libexec/safebox/xml-policy-check.py",
    "/usr/local/libexec/safebox/qemu-security-check.sh",
    "/usr/local/libexec/safebox/storage-crypto-check.py",
    "/usr/local/libexec/safebox/check-host-qemu-config.py",
    "/etc/systemd/system/safebox-kill@.service",
    "/usr/bin/qemu-system-x86_64",
)
TTL_SECONDS = 12 * 3600

class GateError(RuntimeError):
    pass

def cmd(*args: str) -> str:
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=20).strip()
    except (OSError, subprocess.SubprocessError) as e:
        raise GateError(f"Prüfung fehlgeschlagen: {args[0]}: {e}") from e

def assert_root_regular(path: Path) -> None:
    try:
        s = path.lstat()
    except OSError as e:
        raise GateError(f"Nicht lesbar: {path}: {e}") from e
    if not stat.S_ISREG(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022:
        raise GateError(f"Unsichere Datei (Besitzer, Symlink oder Schreibrechte): {path}")

def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()

def host_fingerprint(storage: Path) -> dict:
    if os.geteuid() != 0:
        raise GateError('Nur root darf den Hardware-Nachweis prüfen')
    # No alternate evidence file, config file or device can be provided by a user.
    fingerprints = {}
    for name in FILES:
        p = Path(name)
        assert_root_regular(p)
        fingerprints[name] = sha(p)
    base_meta = storage / 'debian13-xfce-base.meta.json'
    base_hash = storage / 'debian13-xfce-base.qcow2.sha256'
    for p in (base_meta, base_hash):
        assert_root_regular(p)
        fingerprints[str(p)] = sha(p)
    return {
        'version': VERSION,
        'boot_id': Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
        'machine_id': Path('/etc/machine-id').read_text().strip(),
        'kernel': os.uname().release,
        'qemu': cmd('/usr/bin/qemu-system-x86_64','--version').splitlines()[0],
        'libvirt': cmd('/usr/bin/virsh', '-c','qemu:///system','version'),
        'components': fingerprints,
    }

def record_path(storage: Path) -> Path:
    return storage / 'qualification' / 'acceptance.json'

def check(storage: Path) -> dict:
    path = record_path(storage)
    parent = path.parent
    ps = parent.lstat()
    if not stat.S_ISDIR(ps.st_mode) or ps.st_uid != 0 or ps.st_mode & 0o077:
        raise GateError('Attestierungsverzeichnis besitzt keine sicheren Rechte')
    assert_root_regular(path)
    if path.stat().st_mode & 0o077:
        raise GateError('Abnahmeprotokoll muss ausschließlich root lesbar sein')
    with path.open(encoding='utf-8') as f:
        evidence = json.load(f)
    validate_evidence(evidence, host_fingerprint(storage), time.monotonic())
    return evidence

def validate_evidence(evidence: dict, expected_host: dict, now: float) -> None:
    """Strict validity rules; pure function, unit-tested with malicious/stale reports."""
    if evidence.get('schema') != 1 or evidence.get('status') != 'PASS' or evidence.get('scope') != 'benign-offline-kvm-smoke':
        raise GateError('Keine gültige Live-Test-Abnahme vorhanden')
    then = evidence.get('monotonic')
    if not isinstance(then, (int,float)) or now < then or now - then > TTL_SECONDS:
        raise GateError('Hardware-Abnahme ist abgelaufen oder Zeitbezug ist ungültig (12h)')
    if evidence.get('host') != expected_host:
        raise GateError('Host, Boot, Kernel, QEMU/libvirt oder geschützte Komponenten geändert')
    if not (isinstance(evidence.get('checks'), list) and len(evidence['checks']) >= 6 and
            all(isinstance(x, str) and x for x in evidence['checks'])):
        raise GateError('Unvollständige Testnachweise')


def save_success(storage: Path, checks: list[str]) -> None:
    """Only call after hardware-acceptance.py has executed live checks successfully."""
    target = record_path(storage)
    directory = target.parent
    directory.mkdir(mode=0o700, exist_ok=True)
    ps = directory.lstat()
    if not stat.S_ISDIR(ps.st_mode) or ps.st_uid != 0 or ps.st_mode & 0o077:
        raise GateError('Attestierungsverzeichnis unsicher')
    payload = {'schema':1, 'status':'PASS', 'scope':'benign-offline-kvm-smoke',
               'monotonic':time.monotonic(), 'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
               'host':host_fingerprint(storage), 'checks':checks}
    tmp = directory / f'.acceptance.{os.getpid()}.tmp'
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(payload, f, indent=2, sort_keys=True)
            f.write('\n')
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, target)
        os.chmod(target, 0o600)
        syncfd=os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
        try: os.fsync(syncfd)
        finally: os.close(syncfd)
    finally:
        if tmp.exists(): tmp.unlink()

if __name__ == '__main__':
    try:
        if len(sys.argv) != 2 or sys.argv[1] != 'check':
            raise GateError('Benutzung: security_gate.py check')
        # Do NOT source shell config in Python. The installed fixed storage is the
        # only supported target; changes to the value in defaults.conf are blocked
        # by start_vm and independently guarded in preflight.
        proof = check(Path('/var/lib/safebox'))
        print('[PASS] RC5 Security Gate: Live-Abnahme gültig; Host unverändert; 12h/Boot-Bindung.')
        print('       Keine Garantie gegen unbekannte KVM-/QEMU-/Kernel-Schwachstellen.')
    except (GateError, OSError, ValueError, KeyError, json.JSONDecodeError) as e:
        print(f'[FAIL] RC5 Security Gate: {e}. Start gesperrt.', file=sys.stderr)
        sys.exit(1)
