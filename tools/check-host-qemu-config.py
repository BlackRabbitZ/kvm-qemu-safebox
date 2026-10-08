#!/usr/bin/env python3
"""Fail-closed parser for the effective, active qemu.conf SafeBox settings.

A duplicate active key, commented-only setting, or malformed value is a failure.
"""
from pathlib import Path
import re
import sys

EXPECTED = {
    'security_driver': '"apparmor"',
    'security_default_confined': '1',
    'security_require_confined': '1',
    'seccomp_sandbox': '1',
    'max_core': '0',
    'dump_guest_core': '0',
    'namespaces': '[ "mount" ]',
}


def main():
    settings = {}
    for num, line in enumerate(Path(sys.argv[1]).read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        # Comments outside of quotes only.
        in_quote = False
        cleaned = ''
        for c in line:
            if c == '"':
                in_quote = not in_quote
            if c == '#' and not in_quote:
                break
            cleaned += c
        match = re.fullmatch(r'([A-Za-z_][A-Za-z_0-9]*)\s*=\s*(.*?)\s*', cleaned)
        if not match or match.group(1) not in EXPECTED:
            continue
        key, val = match.groups()
        if key in settings:
            raise ValueError(f'{key}: doppelte aktive Definition ({settings[key][0]}, {num})')
        settings[key] = (num, val)
    for key, expected in EXPECTED.items():
        if key not in settings:
            raise ValueError(f'{key}: aktive Einstellung fehlt')
        if re.sub(r'\s+', '', settings[key][1]) != re.sub(r'\s+', '', expected):
            raise ValueError(f'{key}: falscher Wert {settings[key][1]!r}')
    print('[PASS] Aktive qemu.conf-Einstellungen sind eindeutig und korrekt.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, IndexError) as exc:
        print(f'[FAIL] qemu.conf: {exc}', file=sys.stderr)
        sys.exit(1)
