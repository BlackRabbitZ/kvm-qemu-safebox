#!/usr/bin/env python3
"""Independent, read-only /proc inventory for SafeBox QEMU processes.

Exit codes: 0 = no matching process, 1 = matching process remains,
2 = process inventory could not be verified. Run as root on the host.
This is a guard, not a substitute for libvirt state or a VM-escape guarantee.
"""
import os
import re
import sys

NAME = re.compile(r'^safebox-[A-Za-z0-9._-]+$')


def main() -> int:
    if len(sys.argv) != 2 or (sys.argv[1] != '--all' and not NAME.fullmatch(sys.argv[1])):
        print('usage: proc-absence.py --all|safebox-DOMAIN', file=sys.stderr)
        return 2
    target = sys.argv[1]
    try:
        entries = list(os.scandir('/proc'))
    except OSError as error:
        print(f'[UNKNOWN] /proc nicht lesbar: {error}', file=sys.stderr)
        return 2
    found = []
    unknown = []
    for entry in entries:
        if not entry.name.isdecimal():
            continue
        pid = entry.name
        try:
            # Skip other applications without depending on a potentially spoofed comm.
            exe = os.readlink(f'/proc/{pid}/exe')
        except FileNotFoundError:
            continue
        except (PermissionError, OSError):
            try:
                with open(f'/proc/{pid}/comm', encoding='utf-8') as fh:
                    comm = fh.read().strip()
            except FileNotFoundError:
                continue
            except OSError:
                unknown.append(pid)
                continue
            if comm.startswith('qemu-system-'):
                unknown.append(pid)
            continue
        if not re.search(r'/qemu-system-(?:x86_64|[\w-]+)(?: \(deleted\))?$', exe):
            continue
        try:
            with open(f'/proc/{pid}/cmdline', 'rb') as fh:
                args = [a.decode('utf-8', errors='replace') for a in fh.read().split(b'\x00') if a]
        except FileNotFoundError:
            continue
        except OSError:
            unknown.append(pid)
            continue
        # libvirt starts qemu using '-name guest=NAME,...'. Don't rely on pgrep
        # or only one filename: the root-owned identity may have been lost.
        named = []
        for i, arg in enumerate(args):
            if arg == '-name' and i + 1 < len(args):
                named.append(args[i + 1])
            if arg.startswith('guest=safebox-'):
                named.append(arg)
        domain_names = [x.split(',', 1)[0][len('guest='):]
                        for x in named if x.startswith('guest=safebox-')]
        if target == '--all' and any(NAME.fullmatch(d) for d in domain_names):
            found.append((pid, domain_names))
        elif target != '--all' and target in domain_names:
            found.append((pid, domain_names))
    if unknown:
        print(f'[UNKNOWN] QEMU-Prozesse nicht vollständig einsehbar: {", ".join(unknown)}', file=sys.stderr)
        return 2
    if found:
        print(f'[ACTIVE] QEMU-Prozess(e): {found}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
