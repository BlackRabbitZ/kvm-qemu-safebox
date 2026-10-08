#!/usr/bin/env python3
"""RC5 live KVM acceptance with a clean, *benign* base image only.

Must run on the actual dedicated host. No malware is executed by this test.
A PASS only covers tested conditions; it is not a guarantee against VM escapes.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import pwd
import shlex
import stat
import subprocess
import sys
import time
import uuid
from security_gate import GateError, check, cmd, host_fingerprint, save_success

STORAGE = Path('/var/lib/safebox')
LIBEXEC = Path('/usr/local/libexec/safebox')
CONFIG = Path('/etc/safebox/defaults.conf')
BASE = STORAGE / 'debian13-xfce-base.qcow2'
SHELL = '/usr/bin/bash'
VIRSH = ('/usr/bin/virsh', '-c', 'qemu:///system')
REQUIRED_ENV = ('SAFEBOX_RAM_MIB', 'SAFEBOX_VCPUS', 'SAFEBOX_MEM_HARD_MIB',
                'SAFEBOX_IOTHREADS', 'SAFEBOX_CPU_PERIOD_US', 'SAFEBOX_CPU_MAX_PERCENT',
                'SAFEBOX_DISK_TOTAL_BYTES_SEC', 'SAFEBOX_DISK_TOTAL_IOPS_SEC',
                'SAFEBOX_NET_BACKEND', 'SAFEBOX_DISK_TARGET', 'SAFEBOX_DISK_BUS')

def run(*args, env=None, timeout=45) -> str:
    r = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, timeout=timeout, env=env, check=False)
    if r.returncode:
        raise GateError(f"{args[0]} {' '.join(map(str,args[1:4]))}: Exit={r.returncode}; {r.stderr.strip()[-650:]}")
    return r.stdout.strip()

def read_env() -> dict[str,str]:
    # Installed root-owned config is the only supported config; caller env ignored.
    raw = subprocess.check_output([SHELL, '-c',
       'set -ae; source /etc/safebox/defaults.conf; env -0'],
       env={'PATH':'/usr/sbin:/usr/bin:/sbin:/bin', 'HOME':'/root',
            'SAFEBOX_PROFILE':'hardened'}, timeout=10)
    values = dict(p.decode(errors='strict').split('=', 1) for p in raw.split(b'\0') if p)
    for k in REQUIRED_ENV:
        if k not in values: raise GateError(f'Konfiguration unvollständig: {k}')
    if values.get('SAFEBOX_STORAGE') != str(STORAGE) or values.get('SAFEBOX_BASE_IMAGE') != str(BASE):
        raise GateError('RC5 Test erwartet unveränderte festgelegte Speicherpfade')
    if values.get('SAFEBOX_NET_BACKEND') != 'qemu' or values.get('SAFEBOX_REQUIRE_ENCRYPTED_STORAGE') != '1':
        raise GateError('Netzbackend/Storage-Konfiguration unsicher')
    return values

def preflight(env: dict[str,str], checks: list[str]):
    if os.geteuid() != 0: raise GateError('hardware-acceptance.py benötigt root')
    if not Path('/dev/kvm').is_char_device(): raise GateError('Kein echtes /dev/kvm vorhanden')
    if not os.access('/dev/kvm', os.R_OK | os.W_OK): raise GateError('/dev/kvm nicht zugänglich')
    checks.append('Reales /dev/kvm verfügbar')
    # Enforce installed code owner/hash and root ownership before any privileged operations.
    host_fingerprint(STORAGE)
    checks.append('Host-/Runtime-Dateien root-owned, keine Gruppen-/Fremd-Schreibrechte')
    run('aa-status','--enabled')
    run('python3',str(LIBEXEC/'check-host-qemu-config.py'),'/etc/libvirt/qemu.conf')
    run(SHELL,str(LIBEXEC/'qemu-security-check.sh'),'offline',
        env={**env, 'SAFEBOX_CONFIG_FILE':str(CONFIG)})
    checks.append('AppArmor, qemu.conf und QEMU-Version geprüft')
    run('python3', str(LIBEXEC/'storage-crypto-check.py'), str(STORAGE))
    checks.append('Speicher direkt auf überprüftem LUKS2-Volume')
    if run(*VIRSH, 'list', '--name'):
        # Do not modify or test concurrently with ANY other guest; safest default.
        raise GateError('Während Abnahme dürfen keine anderen libvirt-VMs laufen')
    run('python3',str(LIBEXEC/'proc-absence.py'),'--all')
    checks.append('Vor Test: keine SafeBox-QEMU-Prozesse oder laufenden Domains')
    hashfile = STORAGE/'debian13-xfce-base.qcow2.sha256'
    bmeta = json.loads((STORAGE/'debian13-xfce-base.meta.json').read_text())
    if bmeta.get('safebox_version') != '0.5.1-rc5' or bmeta.get('base_path') != str(BASE):
        raise GateError('Basisimage gehört nicht zur RC5; neu versiegeln')
    if BASE.is_symlink() or BASE.stat().st_uid != 0 or BASE.stat().st_mode & 0o777 != 0o440:
        raise GateError('Basisimage hat unsichere Eigentums-/Modusattribute')
    run('sha256sum','--check',str(hashfile),timeout=180)
    checks.append('Unverändertes, versiegeltes RC5-Basisimage (SHA-256)')
    # Ensure independent service can be loaded on actual host.
    run('systemctl','cat','safebox-kill@.service')
    checks.append('Root-owned Kill-Dienst auf echtem systemd-Host verfügbar')
    return bmeta

def render_xml(env, domain, disk: Path) -> str:
    content=(LIBEXEC/'runtime.xml.in').read_text()
    period=int(env['SAFEBOX_CPU_PERIOD_US']); vcpus=int(env['SAFEBOX_VCPUS']); pct=int(env['SAFEBOX_CPU_MAX_PERCENT'])
    repl={
        '__DOMAIN_NAME__':domain, '__DISK_IMAGE__':str(disk),
        '__RAM_MIB__':env['SAFEBOX_RAM_MIB'], '__VCPUS__':env['SAFEBOX_VCPUS'],
        '__MEM_HARD_MIB__':env['SAFEBOX_MEM_HARD_MIB'],
        '__IOTHREADS__':env['SAFEBOX_IOTHREADS'], '__NET_BACKEND__':'qemu',
        '__CPU_PERIOD_US__':str(period),
        '__CPU_GLOBAL_QUOTA_US__':str(vcpus*period*pct//100),
        '__DISK_TOTAL_BYTES_SEC__':env['SAFEBOX_DISK_TOTAL_BYTES_SEC'],
        '__DISK_TOTAL_IOPS_SEC__':env['SAFEBOX_DISK_TOTAL_IOPS_SEC'],
        '__NETWORK_BLOCK__':'', '__SAMPLE_BLOCK__':'', '__ISO_IMAGE__':'',
    }
    for k,v in repl.items():
        if any(c in v for c in '&<>\"\'\r\n'): raise GateError('Ungültiger XML-Parameter')
        content=content.replace(k,v)
    if '__' in content: raise GateError('Unbekannte XML-Template-Platzhalter')
    return content

def assert_not_running(domain: str):
    run(*VIRSH,'list','--all','--name') # API must respond, but transient domain may already disappear.
    running=run(*VIRSH,'list','--name').splitlines()
    if domain in running: raise GateError('Test-Domain läuft noch')
    run('python3',str(LIBEXEC/'proc-absence.py'),domain)


def main() -> int:
    checks: list[str]=[]
    domain=f'safebox-acceptance-{uuid.uuid4().hex[:12]}'
    # A dedicated benign test, NEVER a sample ISO or guest-host file sharing.
    # This script can only create an offline base-backed VM and never takes user XML.
    disk=STORAGE/'sessions'/f'{domain}.qcow2'
    meta=Path(str(disk)+'.meta.json')
    temp_xml=Path('/run/safebox')/f'{domain}.xml'
    started=False
    finished=False
    watch_unit=f'safebox-watch-{domain}.service'
    try:
        env=read_env()
        env={**env, 'SAFEBOX_CONFIG_FILE':str(CONFIG), 'PATH':'/usr/sbin:/usr/bin:/sbin:/bin'}
        # A new test revokes any earlier PASS immediately; fail-closed on retest failures.
        evidence=STORAGE/'qualification'/'acceptance.json'
        if evidence.exists() or evidence.is_symlink():
            if evidence.is_symlink() or evidence.stat().st_uid != 0:
                raise GateError('Alte Abnahme besitzt unsichere Eigentumsrechte')
            evidence.unlink()
        base=preflight(env, checks)
        (STORAGE/'sessions').mkdir(mode=0o750, exist_ok=True)
        qemu_user=pwd.getpwnam(env.get('SAFEBOX_EXPECTED_QEMU_USER','libvirt-qemu'))
        os.chown(STORAGE/'sessions', 0, qemu_user.pw_gid)
        (STORAGE/'sessions').chmod(0o750)
        if disk.exists() or meta.exists() or temp_xml.exists():
            raise GateError('Test-Overlay oder temporäre XML existiert bereits')
        run('qemu-img','create','-f','qcow2','-F','qcow2','-b',str(BASE),str(disk))
        os.chown(disk, qemu_user.pw_uid, qemu_user.pw_gid)
        disk.chmod(0o600)
        data={'schema':1,'mode':'offline','domain':domain,'disk':str(disk.resolve()),
              'base_path':str(BASE.resolve()),'base_id':base['base_id'],
              'base_sha256':base['sha256'],'safebox_version':'0.5.1-rc5',
              'created_at_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
        meta.write_text(json.dumps(data, sort_keys=True, indent=2)+'\n')
        meta.chmod(0o440)
        # Verify the very same installed validators used during normal startup.
        run(SHELL,str(LIBEXEC/'storage-verify.sh'),domain,'offline',str(disk),env=env)
        checks.append('Echtes QCOW2-Overlay und Metadatenbindung geprüft')
        temp_xml.write_text(render_xml(env,domain,disk))
        temp_xml.chmod(0o600)
        run('python3',str(LIBEXEC/'xml-policy-check.py'),str(temp_xml),'offline',str(disk),
            env=env)
        run('virt-xml-validate',str(temp_xml),'domain')
        checks.append('Runtime-XML gegen XML-Allowlist und libvirt-Schema geprüft')
        started=True  # Even a failed create may leave a partially started QEMU process.
        run(*VIRSH,'create',str(temp_xml),timeout=50)
        # Some libvirt hooks populate /run/libvirt/qemu/PID file asynchronously.
        for attempt in range(20):
            try:
                run(SHELL,str(LIBEXEC/'runtime-verify.sh'),domain,'offline',str(disk),env=env,timeout=35)
                break
            except GateError:
                if attempt==19: raise
                time.sleep(0.3)
        checks.append('Reale QEMU-VM: PID, seccomp, AppArmor, Namespace, Geräte-/Netzwerkisolation')
        run(SHELL,str(LIBEXEC/'storage-verify.sh'),domain,'offline',str(disk),env=env)
        checks.append('Live-VM: Speicher-/Overlaygrenzen geprüft')
        # Production watchdog process must be present, not a mocked shell.
        kill_unit=f'safebox-kill@{domain}.service'
        run('systemd-run','--quiet','--collect',f'--unit=safebox-watch-{domain}',
            '--property=Type=simple','--property=Restart=on-failure',
            '--property=RestartSec=1s',f'--property=OnFailure={kill_unit}',
            '--property=NoNewPrivileges=yes','--property=PrivateTmp=yes',
            '--property=ProtectSystem=strict','--property=ProtectHome=yes',
            '--setenv=SAFEBOX_CONFIG_FILE=/etc/safebox/defaults.conf',
            '--setenv=SAFEBOX_PROFILE=hardened',
            *[f'--setenv={k}={env[k]}' for k in REQUIRED_ENV if k in env],
            '--',str(LIBEXEC/'runtime-watch.sh'),domain,'offline',str(disk))
        time.sleep(3)
        run('systemctl','is-active','--quiet',watch_unit)
        state=run(*VIRSH,'domstate',domain).lower()
        if 'running' not in state:
            raise GateError('Benigne Test-VM läuft beim Kill-Test nicht mehr')
        checks.append('Produktiver systemd-Watchdog an echter laufender VM aktiv')
        # Exercise the exact kill-domain path against this benign VM.
        run(SHELL,str(LIBEXEC/'kill-domain.sh'),domain,env=env,timeout=50)
        started=False  # verified by kill helper, recheck below.
        assert_not_running(domain)
        checks.append('Produktiver Kill-Fallback stoppt VM; libvirt UND /proc bestätigen Abwesenheit')
        run('systemctl','stop',watch_unit)
        assert_not_running(domain)
        run('python3',str(LIBEXEC/'proc-absence.py'),'--all')
        if run(*VIRSH,'list','--name').strip():
            raise GateError('Fremde laufende libvirt-Domain während Abschlussprüfung entdeckt')
        for p in (temp_xml, disk, meta):
            p.unlink()
        finished=True
        checks.append('Test-Overlay nach unabhängiger QEMU-Abwesenheitsprüfung entfernt')
        # If configuration changes during testing, recorded fingerprint is current;
        # caller must independently review machine safety before unknown samples.
        save_success(STORAGE,checks)
        check(STORAGE)
        print('[PASS] RC5 REAL-KVM-TEST: PASS, Security Gate für diesen Boot 12h gültig.')
        print('[HINWEIS] Das prüft keine unbekannten Hypervisor-/Kernel-Exploits und ersetzt keinen externen Review.')
        for item in checks: print('[PASS] '+item)
        return 0
    except (GateError,OSError,KeyError,ValueError,subprocess.TimeoutExpired,subprocess.SubprocessError) as e:
        print(f'[FAIL] RC5 REAL-KVM-TEST: {e}',file=sys.stderr)
        return 1
    finally:
        # A failed or interrupted test MUST NOT leave an unmonitored guest running.
        if not finished:
            print('[WARN] Abnahme nicht abgeschlossen; überprüfe VM-Status vor Verwendung.', file=sys.stderr)
        # On uncertainty, do not remove evidence. On successful proof, safe cleanup.
        try:
            subprocess.run(['systemctl','stop',watch_unit],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
        except Exception: pass
        try:
            if started:
                subprocess.run([*VIRSH,'destroy',domain],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=20)
            assert_not_running(domain)
        except Exception as e:
            print(f'[KRITISCH] QEMU-Abwesenheit NICHT bestätigt ({e}); Dateien NICHT gelöscht!',file=sys.stderr)
        else:
            for p in (temp_xml,disk,meta):
                try: p.unlink(missing_ok=True)
                except OSError as e: print(f'[WARN] Temporärer Pfad bleibt: {p}: {e}',file=sys.stderr)

if __name__=='__main__':
    if len(sys.argv) != 1:
        print('[FAIL] hardware-acceptance.py akzeptiert keine XML-, Pfad- oder Umgehungsoptionen.',file=sys.stderr)
        sys.exit(2)
    sys.exit(main())
