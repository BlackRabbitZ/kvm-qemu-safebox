#!/usr/bin/env python3
"""Static SafeBox libvirt-domain XML allowlist validator."""
from __future__ import annotations
import os, sys, xml.etree.ElementTree as ET

if len(sys.argv) < 3:
    print('usage: xml-policy-check.py XML MODE [EXPECTED_DISK]', file=sys.stderr); raise SystemExit(2)
path, mode = sys.argv[1], sys.argv[2]
expected_disk = sys.argv[3] if len(sys.argv) > 3 else ''
expected_iso = sys.argv[4] if len(sys.argv) > 4 else ''
if mode not in {'installer','offline','malware'}:
    print('[FAIL] RC4: Netzbetrieb/Persistent-VM für Malware ausgeschlossen',file=sys.stderr); raise SystemExit(1)
try: root = ET.parse(path).getroot()
except Exception as e:
    print(f'[FAIL] XML nicht parsebar: {e}', file=sys.stderr); raise SystemExit(1)

fails=[]
def fail(m): fails.append(m)
def one(parent, tag):
    xs=parent.findall(tag); return xs[0] if len(xs)==1 else None
def attr(el,k,v): return el is not None and el.get(k)==str(v)
def text(el,v): return el is not None and (el.text or '').strip()==str(v)
def n(tag): return len(root.findall(tag))
def env_int(k):
    try:return int(os.environ[k])
    except Exception: fail(f'Konfiguration fehlt/ungültig: {k}'); return -1

ram=env_int('SAFEBOX_RAM_MIB'); vcpus=env_int('SAFEBOX_VCPUS'); mem=env_int('SAFEBOX_MEM_HARD_MIB'); ioth=env_int('SAFEBOX_IOTHREADS')
period=env_int('SAFEBOX_CPU_PERIOD_US'); pct=env_int('SAFEBOX_CPU_MAX_PERCENT'); quota=vcpus*period*pct//100
bytes_sec=env_int('SAFEBOX_DISK_TOTAL_BYTES_SEC'); iops=env_int('SAFEBOX_DISK_TOTAL_IOPS_SEC')
net_backend=os.environ.get('SAFEBOX_NET_BACKEND','qemu'); net_model=os.environ.get('SAFEBOX_NET_MODEL','e1000e'); disk_bus=os.environ.get('SAFEBOX_DISK_BUS','sata'); disk_target=os.environ.get('SAFEBOX_DISK_TARGET','sda'); network=os.environ.get('SAFEBOX_NETWORK','safebox-net')
install_network=os.environ.get('SAFEBOX_INSTALL_NETWORK_NAME','safebox-install-net'); mac=os.environ.get('SAFEBOX_MAC','52:54:00:77:00:10')
guest_ip=os.environ.get('SAFEBOX_GUEST_IP','10.77.0.100'); nwfilter=os.environ.get('SAFEBOX_INSTALL_NWFILTER','safebox-install-filter') if mode=='installer' else os.environ.get('SAFEBOX_NWFILTER','safebox-runtime-filter')

if root.tag!='domain' or root.get('type')!='kvm': fail('Domain ist nicht type=kvm')
ost=root.find('./os/type')
if not (attr(ost,'arch','x86_64') and attr(ost,'machine','q35')): fail('OS ist nicht x86_64/q35')
mb=root.find('memoryBacking')
if mb is None or mb.find('nosharepages') is None or not attr(mb.find('source'),'type','anonymous') or not attr(mb.find('access'),'mode','private'): fail('Memory-Backing/KSM weicht ab')
for tag,val in [('memory',ram),('currentMemory',ram)]:
    e=root.find(tag)
    if not (attr(e,'unit','MiB') and text(e,val)): fail(f'{tag} weicht ab')
for tag in ('hard_limit','swap_hard_limit'):
    e=root.find(f'./memtune/{tag}')
    if not (attr(e,'unit','MiB') and text(e,mem)): fail(f'memtune/{tag} weicht ab')
vc=root.find('vcpu')
if not (attr(vc,'placement','static') and text(vc,vcpus)): fail('vCPU weicht ab')
if not text(root.find('iothreads'),ioth): fail('IOThreads weichen ab')
if not text(root.find('./cputune/global_period'),period) or not text(root.find('./cputune/global_quota'),quota): fail('CPU-Quota weicht ab')
if not attr(root.find('./features/hyperv/vapic'),'state','off'): fail('VAPIC nicht off')
if not attr(root.find('./features/pmu'),'state','off') or not attr(root.find('./features/vmport'),'state','off'): fail('PMU/vmport nicht off')
cpu=root.find('cpu')
if not attr(cpu,'mode','host-model'): fail('CPU-Modus nicht host-model')
features={(e.get('name'),e.get('policy')) for e in root.findall('./cpu/feature')}
if ('vmx','disable') not in features or ('svm','disable') not in features: fail('Nested Virtualization nicht vollständig deaktiviert')
sec=root.find('seclabel')
if not (attr(sec,'model','apparmor') and attr(sec,'type','dynamic')): fail('AppArmor-Seclabel fehlt')
for e in root.iter():
    if e.tag.endswith('commandline'): fail('qemu:commandline ist verboten')

dev=root.find('devices')
if dev is None: fail('devices fehlt'); dev=ET.Element('devices')
allowed={'emulator','disk','controller','interface','input','graphics','video','memballoon'}
for c in dev:
    if c.tag not in allowed: fail(f'Nicht erlaubter Device-Knoten: {c.tag}')
ems=dev.findall('emulator')
if len(ems)!=1 or (ems[0].text or '').strip()!='/usr/bin/qemu-system-x86_64': fail('Emulator weicht ab')
controllers=dev.findall('controller')
roots=[c for c in controllers if c.get('type')=='pci' and c.get('model')=='pcie-root' and c.get('index')=='0']
ports=[c for c in controllers if c.get('type')=='pci' and c.get('model')=='pcie-root-port']
usbn=[c for c in controllers if c.get('type')=='usb' and c.get('model')=='none']
if len(roots)!=1: fail('PCIe root count != 1')
if len(ports)>8: fail('Zu viele PCIe root ports')
if len(usbn)!=1: fail('USB controller model=none count != 1')
allowed_cont=set(map(id,roots+ports+usbn))
sata=[c for c in controllers if c.get('type')=='sata' and c.get('index')=='0']
if len(sata)!=1: fail('SATA controller count != 1')
allowed_cont.update(map(id,sata))
if any(id(c) not in allowed_cont for c in controllers): fail('Unerlaubter Controller')

ball=dev.findall('memballoon')
if len(ball)!=1 or ball[0].get('model')!='none': fail('Balloon nicht exakt deaktiviert')
gfx=dev.findall('graphics')
if len(gfx)!=1 or gfx[0].get('type')!='spice': fail('Grafik nicht exakt SPICE')
else:
    g=gfx[0]
    if len(g.findall("listen[@type='none']"))!=1: fail('SPICE listener nicht none')
    if not attr(g.find('clipboard'),'copypaste','no') or not attr(g.find('filetransfer'),'enable','no') or not attr(g.find('gl'),'enable','no'): fail('SPICE sharing/GL nicht aus')
vid=dev.findall('video')
if len(vid)!=1: fail('Video count != 1')
else:
    m=vid[0].find('model')
    if not (attr(m,'type','bochs') and attr(m,'heads','1') and attr(m,'primary','yes')): fail('Video nicht Bochs/1/primary')

disks=dev.findall('disk')
sysdisks=[d for d in disks if d.get('device')=='disk']
if len(sysdisks)!=1: fail('Systemdisk count != 1')
else:
    d=sysdisks[0]
    if d.get('type')!='file': fail('Systemdisk type != file')
    drv=d.find('driver'); wanted={'name':'qemu','type':'qcow2','cache':'none','io':'native','discard':'ignore'}
    if drv is None or any(drv.get(k)!=v for k,v in wanted.items()): fail('Systemdisk driver weicht ab')
    tgt=d.find('target')
    if not (attr(tgt,'dev',disk_target) and attr(tgt,'bus',disk_bus)): fail('Systemdisk target weicht ab')
    src=d.find('source')
    if src is None or not src.get('file') or len(src.attrib)!=1: fail('Systemdisk source ist nicht exakt file')
    elif expected_disk and src.get('file')!=expected_disk: fail('Systemdisk source != erwartetes Overlay')
    if d.find('readonly') is not None: fail('Systemdisk unerwartet readonly')
    io=d.find('iotune')
    if io is None or not text(io.find('total_bytes_sec'),bytes_sec) or not text(io.find('total_iops_sec'),iops): fail('Disk-I/O-Limits weichen ab')

interfaces=dev.findall('interface'); inputs=dev.findall('input'); cdroms=[d for d in disks if d.get('device')=='cdrom']
if mode=='offline':
    if interfaces: fail('Offline hat NIC')
    if cdroms: fail('Offline hat CD-ROM')
    if expected_iso: fail('Offline darf keine Sample-ISO erwarten')
    expected_inputs={('keyboard','ps2'),('mouse','ps2')}
elif mode=='malware':
    if interfaces: fail('Malware-VM hat NIC')
    if len(cdroms)!=1: fail('Malware-VM braucht exakt ein readonly Sample-ISO')
    else:
        c=cdroms[0]
        src=c.find('source'); drv=c.find('driver'); tgt=c.find('target')
        if (c.get('type')!='file' or not attr(drv,'name','qemu') or
            not attr(drv,'type','raw') or not attr(tgt,'dev','sdb') or
            not attr(tgt,'bus','sata') or c.find('readonly') is None or
            not expected_iso or not attr(src,'file',expected_iso) or
            src is None or len(src.attrib)!=1):
            fail('Sample-CDROM nicht exakt readonly/ISO/Pfad gebunden')
    expected_inputs={('keyboard','ps2'),('mouse','ps2')}
else:
    if len(interfaces)!=1: fail('Installer NIC count != 1')
    if len(cdroms)!=1: fail('Installer CD-ROM count != 1')
    else:
        c=cdroms[0]
        if c.get('type')!='file' or not attr(c.find('driver'),'name','qemu') or not attr(c.find('driver'),'type','raw') or not attr(c.find('target'),'dev','sdb') or not attr(c.find('target'),'bus','sata') or c.find('readonly') is None: fail('Installer CD-ROM weicht ab')
    expected_inputs={('keyboard','ps2'),('mouse','ps2')}
if len(inputs)!=2 or {(i.get('type'),i.get('bus')) for i in inputs} != expected_inputs: fail('Input-Geräte weichen ab')

if mode=='installer' and len(interfaces)==1:
    i=interfaces[0]
    expected_net=install_network if mode=='installer' else network
    if i.get('type')!='network' or not attr(i.find('source'),'network',expected_net) or not attr(i.find('model'),'type',net_model): fail('NIC Typ/Netz/Model weicht ab')
    drv=i.find('driver')
    if net_model=='e1000e' and drv is not None: fail('e1000e darf keinen VirtIO/vhost driver-Knoten besitzen')
    if net_model=='virtio' and not attr(drv,'name',net_backend): fail('VirtIO-NIC backend weicht ab')
    if not attr(i.find('rom'),'bar','off') or not attr(i.find('port'),'isolated','yes') or not attr(i.find('mac'),'address',mac): fail('NIC ROM/isolation/MAC weicht ab')
    filt=i.find('filterref')
    if filt is None or filt.get('filter')!=nwfilter: fail('nwfilter weicht ab')
    params={(p.get('name'),p.get('value')) for p in (filt.findall('parameter') if filt is not None else [])}
    if mode=='installer':
        if params: fail('Installer Filter-Parameter unerwartet (Bootstrap verwendet keinen IP-Learning-Parameter)')
    else:
        if ('IP',guest_ip) not in params or ('CTRL_IP_LEARNING','none') not in params: fail('Runtime IP anti-spoof parameters weichen ab')

if fails:
    for m in fails: print('[FAIL] '+m, file=sys.stderr)
    raise SystemExit(1)
print('[PASS] Domain-XML entspricht der SafeBox-Allowlist.')
