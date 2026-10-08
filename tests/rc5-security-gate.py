#!/usr/bin/env python3
"""Run fail-closed negative tests without claiming real KVM acceptance."""
import importlib.util
import pathlib
import sys
root=pathlib.Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('security_gate',root/'tools/security_gate.py')
mod=importlib.util.module_from_spec(spec);sys.modules['security_gate']=mod;spec.loader.exec_module(mod)
now=100_000
host={'boot_id':'boot-A','version':mod.VERSION,'components':{'qemu':'abc'}}
good={'schema':1,'status':'PASS','scope':'benign-offline-kvm-smoke','monotonic':now-30,
    'checks':['one','two','three','four','five','six'], 'host':host}
mod.validate_evidence(good,host,now)
print('[PASS] RC5: gültiger Boot-/Host-/Testnachweis wird akzeptiert')
for label,changes in [
 ('not-pass',{'status':'FAIL'}),('scope',{'scope':'mock-test'}),
 ('old',{'monotonic':now-mod.TTL_SECONDS-1}),
 ('future',{'monotonic':now+2}),('too-few',{'checks':['one']}),
 ('no-host',{'host':None}),('missing-status',{'status':None}),
 ('bad-schema',{'schema':4})]:
    bad={**good,**changes}
    try:mod.validate_evidence(bad,host,now)
    except mod.GateError:pass
    else:raise AssertionError('Gate accepted '+label)
    print('[PASS] RC5: verworfener Nachweis:',label)
try:mod.validate_evidence(good,{**host,'boot_id':'boot-B'},now)
except mod.GateError:print('[PASS] RC5: geänderter Boot gesperrt')
else:raise AssertionError('Gate accepts changed boot')
try:mod.validate_evidence(good,{**host,'components':{'qemu':'tampered'}},now)
except mod.GateError:print('[PASS] RC5: geänderte Hostdateien gesperrt')
else:raise AssertionError('Gate accepts tampered host')
cli=(root/'safebox').read_text()
pre=cli.index('security_gate.py\" check || die')
post=cli.index('qemu-img create -f qcow2',cli.index('start_vm(){'))
assert pre<post
assert 'hardware-test)' in cli
assert 'installed_helpers_ok || die' in cli
assert '/dev/kvm' in (root/'tools/hardware-acceptance.py').read_text()
print('[PASS] RC5: Gate ist vor Overlay/VM-Erstellung integriert; KVM-Test ist echt (kein Mock)')
