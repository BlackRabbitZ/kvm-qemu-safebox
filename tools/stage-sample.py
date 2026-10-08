#!/usr/bin/env python3
"""Create a read-only ISO from one untrusted regular file, with no host mounts.

Root-only installed helper. Never executes, parses as binary, or mounts the sample.
"""
from __future__ import annotations
import hashlib
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile


def reject(message: str) -> None:
    raise SystemExit('[FAIL] Sample-Import: ' + message)


def main() -> None:
    if os.geteuid() != 0 or len(sys.argv) != 5:
        reject('Root und Argumente SOURCE DEST_ISO QEMU_GID MAX_MIB erforderlich')
    source, dest, gid_str, max_str = sys.argv[1:]
    if not gid_str.isdecimal() or not max_str.isdecimal():
        reject('GID und Grenze müssen numerisch sein')
    gid, max_bytes = int(gid_str), int(max_str) * 1024 * 1024
    if gid < 0 or not 1 <= max_bytes <= 512 * 1024 * 1024:
        reject('GID/Grenze ungültig (maximal 512 MiB)')
    if not os.path.isabs(dest) or not dest.endswith('.sample.iso'):
        reject('Ungültiger absoluter ISO-Zielpfad')
    parent = os.path.dirname(dest)
    if os.path.islink(parent) or not os.path.isdir(parent):
        reject('Zielordner muss real sein')
    pst = os.stat(parent)
    if pst.st_uid != 0 or pst.st_mode & 0o022:
        reject('Zielordner nicht root-owned/schreibgeschützt gegenüber Fremden')
    if os.path.lexists(dest) or os.path.lexists(dest + '.sha256'):
        reject('Sample-ISO/Hash bereits vorhanden (kein Überschreiben)')
    fd = os.open(source, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_size == 0 or st.st_size > max_bytes:
            reject('Nur nichtleere reguläre Dateien innerhalb der Größenbegrenzung erlaubt')
        with tempfile.TemporaryDirectory(prefix='.safebox-stage-', dir=parent) as tmpdir:
            sample = os.path.join(tmpdir, 'sample.bin')
            used = 0
            with open(sample, 'xb') as output:
                while True:
                    b = os.read(fd, min(1024 * 1024, max_bytes + 1 - used))
                    if not b:
                        break
                    used += len(b)
                    if used > max_bytes:
                        reject('Quelldatei ist beim Kopieren über die Grenze gewachsen')
                    output.write(b)
                output.flush()
                os.fsync(output.fileno())
            # Safe predictable ISO member name. No external filenames or command syntax.
            tmp_iso = os.path.join(tmpdir, 'generated.iso')
            proc = subprocess.run(
                ['genisoimage', '-quiet', '-r', '-J', '-V', 'SAFEBOX_SAMPLE',
                 '-graft-points', '-o', tmp_iso, f'sample.bin={sample}'],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE, timeout=120, check=False,
            )
            if proc.returncode != 0:
                reject('ISO-Erstellung fehlgeschlagen: ' + proc.stderr.decode(errors='replace')[:200])
            if os.stat(tmp_iso).st_size < 32768:
                reject('ISO-Ausgabe ungewöhnlich klein')
            digest = hashlib.sha256()
            with open(tmp_iso, 'rb') as f:
                for b in iter(lambda: f.read(1024 * 1024), b''):
                    digest.update(b)
            # Create both files exclusively; failures never overwrite an old sample.
            outfd = os.open(dest, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o400)
            try:
                with os.fdopen(outfd, 'wb') as outf, open(tmp_iso, 'rb') as inp:
                    shutil.copyfileobj(inp, outf, 1024 * 1024)
                    outf.flush()
                    os.fsync(outf.fileno())
                os.chown(dest, 0, gid)
                os.chmod(dest, 0o440)
                manifest = dest + '.sha256'
                mfd = os.open(manifest, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o400)
                with os.fdopen(mfd, 'w') as mf:
                    mf.write(digest.hexdigest() + '\n')
                    mf.flush()
                    os.fsync(mf.fileno())
                os.chown(manifest, 0, 0)
                os.chmod(manifest, 0o400)
            except BaseException:
                os.unlink(dest)
                raise
            print(f'[OK] Sample in readonly-ISO übernommen: {digest.hexdigest()} (SHA-256 ISO); {used} Byte Nutzdaten.')
    finally:
        os.close(fd)


if __name__ == '__main__':
    main()
