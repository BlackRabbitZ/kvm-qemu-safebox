#!/usr/bin/env python3
"""Fail-closed gate: SafeBox storage must reside on real LUKS2 device.

This is encryption at rest, not per-session crypto-erase or a guarantee that
memory/swap/crash dumps contain no plaintext. Independent physical isolation
is still required for high-risk malware.
"""
from __future__ import annotations
import os, subprocess, sys

def run(*cmd):
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL, timeout=8).strip()

def main():
    if os.geteuid()!=0 or len(sys.argv)!=2: raise RuntimeError('Nur root; STORAGE_PATH erforderlich')
    directory=sys.argv[1]
    if not os.path.isdir(directory): raise RuntimeError('Speicherordner fehlt')
    device=run('findmnt','-T',directory,'-n','-o','SOURCE').split('[')[0]
    if not device.startswith('/dev/'):
        raise RuntimeError('Nicht auf einem verifizierbaren LUKS2-Blockgerät (tmpfs/overlay/unbekannt)')
    ancestry=run('lsblk','-s','-n','-r','-p','-o','NAME,TYPE',device)
    cryptdevs=[]
    for line in ancestry.splitlines():
        parts=line.split()
        if len(parts)>=2 and parts[1]=='crypt' and parts[0].startswith('/dev/'):
            cryptdevs.append(parts[0])
    if not cryptdevs: raise RuntimeError('Speicher nicht auf dm-crypt: '+device)
    for cryptdev in cryptdevs:
        status=run('cryptsetup','status',cryptdev)
        if any(line.strip().lower()=='type: luks2' for line in status.splitlines()):
            print('[PASS] LUKS2-Unterbau bestätigt: '+cryptdev)
            return
    raise RuntimeError('dm-crypt ohne bestätigtes LUKS2 (Plain/LUKS1 nicht ausreichend)')

if __name__=='__main__':
    try: main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as e:
        print('[FAIL] Storage-Verschlüsselung nicht attestiert: '+str(e),file=sys.stderr)
        raise SystemExit(1)
