<p align="right">
  🌐 <strong>Language / Sprache:</strong>&nbsp;
  <a href="README.md"><img alt="Zu Deutsch wechseln" src="https://img.shields.io/badge/DE-Deutsch-64748b?style=flat-square" /></a>
  <a href="README_EN.md"><img alt="English (active)" src="https://img.shields.io/badge/EN-English%20%E2%9C%93-2563eb?style=flat-square" /></a>
</p>

<div align="center">

# 🛡️ KVM/QEMU SafeBox

**Security-hardened, offline-by-design Linux sandbox for manually examining suspicious software.**

*Debian 13 · KVM/QEMU · libvirt · ephemeral VMs · Defense in Depth*

[![Version](https://img.shields.io/badge/Version-v0.5.1--rc5-2563eb?style=flat-square)](CHANGELOG.md)
[![Host](https://img.shields.io/badge/Host-Debian%2013-a80030?logo=debian&logoColor=white&style=flat-square)](https://www.debian.org/)
[![Virtualization](https://img.shields.io/badge/Virtualization-KVM%20%2F%20QEMU-6d28d9?style=flat-square)](https://www.qemu.org/)
[![Isolation](https://img.shields.io/badge/Analysis%20network-NO%20NIC-166534?style=flat-square)](docs/threat-model.md)
[![Approval](https://img.shields.io/badge/Malware%20approval-PENDING-d97706?style=flat-square)](docs/validation-rc5.md)
[![CI](https://github.com/BlackRabbitZ/kvm-qemu-safebox/actions/workflows/ci.yml/badge.svg)](https://github.com/BlackRabbitZ/kvm-qemu-safebox/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache--2.0-0f766e?style=flat-square)](LICENSE)

[**Quick Start**](#-quick-start) · [**Installation**](#-installation-on-debian-13) · [**Security Testing**](#-security-tests-and-acceptance) · [**Usage**](#-usage) · [**Credits**](#-project-and-credits)

</div>

> [!CAUTION]
> **Release candidate — not approved for unknown, active malware.** Automated repository checks cannot establish security on an actual KVM host. RC5 adds a live test and a mandatory Security Gate; their results must be evaluated **on the intended host**. Passing does **not** guarantee protection against unknown VM escapes or compromised host firmware. For high-risk samples, use a **dedicated computer physically disconnected from other networks**.

## 📑 Table of Contents

- [About the Project](#-about-the-project)
- [Security Architecture](#-security-architecture)
- [Quick Start](#-quick-start)
- [System Requirements](#-system-requirements)
- [Installation on Debian 13](#-installation-on-debian-13)
- [Preparing the Debian Base VM](#-preparing-the-debian-base-vm)
- [Security Tests and Acceptance](#-security-tests-and-acceptance)
- [Usage](#-usage)
- [Upgrading from an Older Version](#-upgrading-from-an-older-version)
- [Troubleshooting](#-troubleshooting)
- [Security Boundaries and Known Limitations](#-security-boundaries-and-known-limitations)
- [Project Layout and Documentation](#-project-layout-and-documentation)
- [Project and Credits](#-project-and-credits)

---

## 🔎 About the Project

**SafeBox** is an open-source sandbox built on **KVM/QEMU and libvirt** for the **manual examination of suspicious Linux files**. The guest is always treated as untrusted — even when an attacker has administrator or `root` access inside it.

**Priorities:** minimize guest-to-host device interfaces, enforce offline analysis, validate VM configurations, constrain resources, use temporary disks, and require **real-hardware acceptance testing before starting an analysis VM**.

SafeBox deliberately is **not** an automated malware detonation or analysis platform: it does not simulate command-and-control infrastructure, generate automated behavioral reports, or provide a supported Windows guest. Windows PE files can be inspected **statically** on Debian, but cannot be executed natively as Windows processes.

### Supported modes

| Mode | Purpose | Network | Persistence | RC5 |
|:--|:--|:--:|:--:|:--:|
| `start offline` | Start a clean, benign test guest | ❌ No NIC | Ephemeral | ✅ |
| `start malware FILE` | Attach a sample as a read-only ISO | ❌ No NIC | Ephemeral | ✅ After acceptance |
| `create-base` | Install a trusted Debian base image | Separate, temporary installation network | Base image | ✅ |
| `start disposable` | Legacy networked disposable runtime | — | — | ⛔ Disabled |
| `start persistent` | Legacy persistent runtime | — | — | ⛔ Disabled |
| `setup-network` | Legacy runtime network configuration | — | — | ⛔ Disabled |

## 🏗️ Security Architecture

```text
      DEDICATED DEBIAN 13 HOST (physically offline for high-risk work)
┌───────────────────────────────────────────────────────────────────┐
│  libvirt (qemu:///system) · KVM/QEMU · AppArmor · Seccomp          │
│  Root-owned runtime helpers · XML/process validation · watchdog  │
│                                                                   │
│               sealed Debian 13 base image (SHA-256)               │
│                         │                                         │
│                 temporary QCOW2 overlay                          │
│                         │                                         │
│            ┌────────────▼─────────────────────┐                   │
│            │ Debian 13 / XFCE analysis VM     │                   │
│            │  ✓ read-only sample ISO          │                   │
│            │  ✓ virtual display/input         │                   │
│            │  ✗ no network interface          │                   │
│            │  ✗ no host file sharing          │                   │
│            │  ✗ no USB/PCI passthrough        │                   │
│            │  ✗ no clipboard / guest agent    │                   │
│            └──────────────────────────────────┘                   │
│                                                                   │
│   Session files on verified LUKS2-encrypted underlying storage   │
└───────────────────────────────────────────────────────────────────┘
```

| Protection layer | Intended property | Verification / limitation |
|---|---|---|
| **Network** | No NIC in the analysis domain | Check domain XML **and** guest; does not rule out hypervisor escapes |
| **Host devices** | No USB/PCI passthrough, vsock, or host filesystem access | XML allowlist and runtime inspection |
| **Guest integration** | No clipboard, file transfer, shared folder, or guest agent | Inspect devices and communication channels |
| **QEMU process** | Non-`root` identity, AppArmor, Seccomp, dedicated cgroup/namespace | Requires live verification on the target host |
| **Storage** | Sealed base and temporary overlay on LUKS2 | LUKS2 does **not** guarantee per-session key destruction |
| **Shutdown** | Watchdog and kill helper with independent process checks | Exercise failure cases; ambiguous process states block cleanup |
| **Start authorization** | Security Gate requires a recent successful live test | Valid for **at most 12 hours**, tied to current boot/host fingerprint |

Technical background: [Threat Model](docs/threat-model.md) · [Host Hardening](docs/hardening.md) · [Limitations](docs/limitations.md).

---

## ⚡ Quick Start

The order is deliberately strict. **Use trusted software only through step 5.**

| Step | Task | Reference |
|:--:|---|---|
| **1** | Prepare a Debian 13 host and LUKS2 storage | [Requirements](#-system-requirements) |
| **2** | Review RC5 source and install host components | [Installation](#-installation-on-debian-13) |
| **3** | Install a verified Debian ISO, harden the guest, seal the base | [Base VM](#-preparing-the-debian-base-vm) |
| **4** | Run `make check` and `make release-check` | [Repository Tests](#1-repository-tests-without-malware) |
| **5** | Run `hardware-test`, `gate-check`, and manual offline checks | [Host Acceptance](#2-real-kvm-hardware-test) |
| **6** | Only after documented acceptance, examine a benign sample | [Usage](#-usage) |

### Essential commands

```bash
make check                           # Code/regression tests (NOT real KVM isolation evidence)
make release-check                   # Also includes release/signature negative tests
sudo bash ./safebox doctor           # Full configuration status
sudo bash ./safebox hardware-test    # Harmless live KVM test on the target host
sudo bash ./safebox gate-check       # Validate an existing acceptance record
sudo bash ./safebox start offline    # Ephemeral guest with NO network interface
sudo bash ./safebox status           # Runtime status
```

---

## 💻 System Requirements

| Component | Requirement / note |
|---|---|
| Host OS | **Debian 13** (RC5 reference and target system) |
| Virtualization | Intel VT-x or AMD-V and working **`/dev/kvm`** |
| Services | QEMU, system-wide libvirt, systemd, AppArmor, nftables |
| Tools | Python 3, `qemu-img`, `virsh`, `virt-viewer`, `genisoimage`, `cryptsetup`, `jq`, etc. (installer supplies dependencies) |
| RAM | Default profile uses **6 GiB guest RAM**, plus headroom for the host |
| Storage | Space for a **50 GiB base disk**, temporary overlays, and free-space reserve |
| Encryption | `/var/lib/safebox` must reside on a **verifiably LUKS2-encrypted** volume |
| Environment | High-risk malware: **dedicated, physically network-disconnected system** |

Initial checks on the **host** (do not use malware yet):

```bash
cat /etc/os-release
lscpu | grep -E 'Virtualization|Virtualisierung' || true
ls -l /dev/kvm
findmnt -T /var/lib/safebox -o TARGET,SOURCE,FSTYPE
lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS
```

> [!WARNING]
> **Do not set up encryption blindly.** Formatting a LUKS2 volume can destroy all existing data. SafeBox **does not create** an encrypted partition for you. If `/var/lib/safebox` does not exist, plan and configure an appropriate LUKS2 filesystem before proceeding. Account for swap, hibernation, crash dumps, snapshots, and backups as well.

## 📥 Installation on Debian 13

> [!WARNING]
> The installer installs packages, modifies the **global** `/etc/libvirt/qemu.conf`, configures firewall and systemd components, and enables AppArmor. **Do not run it unreviewed on a production virtualization host.** Only invoke it as root from a **trusted checkout protected against unauthorized changes**.

**1. Obtain the complete RC5 project.** Extract the RC5 release archive or — **once RC5 is actually published on GitHub** — clone the repository:

```bash
git clone https://github.com/BlackRabbitZ/kvm-qemu-safebox.git
cd kvm-qemu-safebox
cat VERSION                   # Must print 0.5.1-rc5
```

**2. Review the source code, configuration, and changes.** Before running anything with root privileges, inspect [`install/install-host.sh`](install/install-host.sh), [`host/harden-libvirt.sh`](host/harden-libvirt.sh), and [`network/install-firewall-service.sh`](network/install-firewall-service.sh). This locally built RC5 archive is **not cryptographically signed**; an SHA-256 checksum distributed through the same unsigned channel does not authenticate the publisher.

**3. Install host components and inspect the diagnostics:**

```bash
sudo bash ./install/install-host.sh
sudo bash ./safebox doctor
```

During initial setup, `doctor` may report **`NOT READY`** until a sealed base image and real-hardware acceptance record exist. That can be expected at this stage; **do not bypass checks** to silence it.

**4. Verify installation:**

```bash
sudo aa-status --enabled
sudo virsh -c qemu:///system capabilities >/dev/null && echo 'libvirt reachable'
sudo bash ./safebox security-check
```

These instructions assume a dedicated host. Other VMs on the machine may be affected by global hardening settings.

## 🧱 Preparing the Debian Base VM

### 1. Verify the original ISO and start installation

Obtain an official **Debian 13 netinst ISO**, its `SHA256SUMS`, and `SHA256SUMS.sign` from trusted Debian sources. Do **not** skip signature verification.

```bash
sudo bash ./safebox verify-debian-iso /path/to/debian-13-amd64-netinst.iso /path/to/SHA256SUMS /path/to/SHA256SUMS.sign
sudo bash ./safebox create-base       /path/to/debian-13-amd64-netinst.iso /path/to/SHA256SUMS /path/to/SHA256SUMS.sign
```

In the Debian installer, choose **XFCE**, a minimal guest, and **no SSH server**. The **separate installation network** is for building a trusted base **only**, **never** for examining malware.

If the viewer does not appear:

```bash
bash ./safebox viewer safebox-installer
```

The viewer uses local libvirt permissions; a sufficiently locked-down host may require a separate authorized console session. Do **not** add ordinary users indiscriminately to the privileged `libvirt` group.

### 2. Harden the guest

Run these commands **inside the newly installed Debian guest**, not on the host:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/BlackRabbitZ/kvm-qemu-safebox.git
cd kvm-qemu-safebox
cat VERSION                   # Confirm version 0.5.1-rc5
sudo bash ./guest/harden.sh
sudo poweroff
```

Alternatively, transfer a previously reviewed copy of the RC5 files to the trusted guest. `guest/harden.sh` removes unnecessary integrations, configures firewall and kernel defaults, and handles the NIC available **during installation**. The later analysis VM launches **without** that NIC. See [Hardening Details](docs/hardening.md).

### 3. Seal the base image

**Back on the host — after the guest has shut down completely:**

```bash
sudo bash ./safebox seal-base
sudo bash ./safebox doctor
```

Sealing validates the base, removes the installer environment, and records SHA-256/version metadata. Base images built for **RC4 or older** are not accepted by RC5: rebuild and seal instead of editing metadata.

---

## 🧪 Security Tests and Acceptance

> [!IMPORTANT]
> **Three distinct levels of testing:** `make check` validates code and rules, `hardware-test` runs a **real harmless KVM guest**, and **manual acceptance** checks additional host/guest properties. Together they provide stronger evidence — **not** a guarantee against unknown vulnerabilities.

### 1. Repository tests (without malware)

From the RC5 project directory:

```bash
make check
make release-check
```

| Test | What it covers | What it proves |
|---|---|---|
| `make check` | Bash/Python syntax, policies, profiles, XML mutations, mocked watchdog/libvirt failures, RC4 isolation tests, RC5 gate negative tests | **Does not** establish live VM isolation |
| `make release-check` | Above plus version metadata, documentation links, release artifacts, checksums, and signature/negative tests | **Does not** establish safety for unknown malware |
| `python3 tests/rc5-security-gate.py` | Rejects expired, tampered, or mismatched acceptance records | Tests the validation logic only |

**Expected:** Commands complete with exit status `0`. Investigate all `[FAIL]` messages. A green CI badge cannot replace hardware testing.

### 2. Real KVM hardware test

Run this **only on the dedicated Debian 13 target host**, with working `/dev/kvm`, a sealed RC5 base, and LUKS2 storage. **Shut down all unrelated libvirt VMs first.** This does **not** execute malware.

```bash
sudo bash ./safebox hardware-test
sudo bash ./safebox gate-check
sudo bash ./safebox doctor
```

As far as implemented by the code, the hardware test checks `/dev/kvm`, installed root-owned verification helpers, AppArmor/QEMU configuration, LUKS2, base-image integrity, permitted domain devices, live QEMU process confinement, the active systemd watchdog, and **kill/process absence** after the test.

**Expected key output when successful** (other messages may appear):

```text
[PASS] RC5 REAL-KVM-TEST: PASS, Security Gate für diesen Boot 12h gültig.
[PASS] RC5 Security Gate: Live-Abnahme gültig; Host unverändert; 12h/Boot-Bindung.
```

These messages originate from the implementation and are shown in German even when following this English guide.

- Starting a new test **first revokes any prior PASS**. If the new test fails, there is **no new approval**.
- The root-protected acceptance record is stored in `/var/lib/safebox/qualification/acceptance.json`.
- Approval expires after **at most 12 hours**, upon **reboot**, or after relevant changes to the validated host state.
- **Do not** edit the JSON file, disable Security Gate code, or copy a PASS from another host.

### 3. Manual isolation checks using a benign guest

**Only after a passing gate, still without actual malware:**

```bash
sudo bash ./safebox start offline hardened
```

In a **second host terminal** (while the guest is running):

```bash
sudo virsh -c qemu:///system list --name
sudo bash ./safebox status
sudo bash ./safebox verify-runtime
sudo virsh -c qemu:///system dumpxml DOMAINNAME > /tmp/safebox-live.xml
```

Replace `DOMAINNAME` with the actual name from `virsh list --name`. Inspect the XML: analysis mode must have **no** `<interface>` devices, host filesystem shares, passthrough devices, or unexpected communication channels. XML alone does not prove every property; also inspect the **benign guest**:

```bash
ip -br link               # Usually only lo; no Ethernet/Wi-Fi NIC
lspci                     # No unexpected host/passthrough devices
lsblk                     # Expected virtual drives only
```

**Also verify manually:** physical host network isolation, QEMU AppArmor/Seccomp status, watchdog operation, absence of unrelated running VMs, host/firmware updates, and logs. Observe the benign guest for **at least 30 minutes** as an additional recommended check. Test libvirt or systemd failure scenarios **only under controlled conditions on the dedicated test host**, then perform acceptance again.

**After a normal guest shutdown**, run on the host:

```bash
sudo virsh -c qemu:///system list --name
sudo python3 ./tools/proc-absence.py --all
sudo bash ./safebox cleanup
sudo bash ./safebox gate-check
```

> [!WARNING]
> **Never force `cleanup`** if a QEMU process is still running or libvirt cannot determine its state reliably. Investigate ambiguous states; the security logic intentionally preserves files in those cases. Deleting session overlays is **not a cryptographic erasure guarantee**.

### 4. Acceptance checklist

| Criterion | Status |
|---|:---:|
| Repository/regression tests pass | ☐ |
| `hardware-test` reports `[PASS]` on **this** host | ☐ |
| `gate-check` is valid for the current boot and configuration | ☐ |
| No NIC, host shares, or passthrough in the running guest | ☐ |
| AppArmor, Seccomp, watchdog, and QEMU process identity verified live | ☐ |
| QEMU termination confirmed after shutdown | ☐ |
| Host physically separated from networks for high-risk samples | ☐ |
| Updates, residual risks, and test results documented | ☐ |

**Only after completing all applicable checks** should further use be considered. `[PASS]` means *“the tested conditions held at that time”*, **not** *“arbitrary malware cannot escape”*. Further reading: [RC5 Hardware Validation](docs/validation-rc5.md) · [Testing Overview](docs/testing.md).

---

## 🎛️ Usage

### List profiles

```bash
bash ./safebox profiles
```

| Profile | Guest RAM | vCPUs | Description |
|---|---:|---:|---|
| `hardened` | 6 GiB | 4 | Default; conservative resource limits |
| `balanced` | 8 GiB | 4 | More RAM/I/O; same isolation restrictions |
| `performance` | 12 GiB | 8 | Higher resource budget; same device restrictions |

### Start an empty offline VM

```bash
sudo bash ./safebox start offline hardened
```

`start` waits for the session to end. Shut the guest down **normally** and confirm successful cleanup. If the GUI has problems, `bash ./safebox viewer DOMAINNAME` may help from an authorized desktop session.

### Examine a suspicious file manually

**Only after documented acceptance, preferably in an isolated lab.** Use a **benign test file** for the first run.

```bash
sudo bash ./safebox start malware /absolute/path/to/testfile.bin hardened
```

- The source must be a **regular file** (not a symlink), up to **256 MiB**.
- SafeBox builds a read-only ISO and exposes the sample inside the guest as **`sample.bin`**.
- The analysis guest has **no NIC**, shared folder, or host clipboard integration.
- The sample is **not executed on the host**, but host-side processing of the file is still an attack surface.

**Inside the guest:**

```bash
sudo mkdir -p /mnt/probe
sudo mount -o ro /dev/sr0 /mnt/probe
ls -lah /mnt/probe
sha256sum /mnt/probe/sample.bin
```

After a normal guest shutdown, SafeBox removes temporary session components **only after QEMU absence is confirmed**. Files may remain after failures. **This is not guaranteed forensic-grade data destruction.** Do not add host shares, network cards, or USB devices to simplify analysis.

### Diagnostics and maintenance commands

| Command | Purpose |
|---|---|
| `sudo bash ./safebox doctor` | Host and Security Gate status (READY/NOT READY) |
| `sudo bash ./safebox gate-check` | Validate existing hardware acceptance |
| `sudo bash ./safebox hardware-test` | New live KVM acceptance with a harmless guest |
| `sudo bash ./safebox status` | Running SafeBox domain and runtime status |
| `sudo bash ./safebox verify-runtime` | Check live domain, QEMU process, and storage |
| `sudo bash ./safebox cleanup` | Safe cleanup after confirmed VM termination |
| `bash ./safebox profiles` | Available resource profiles |
| `make check` | Local repository logic tests |
| `make release-check` | Additional release and artifact tests |

## 🔁 Upgrading from an Older Version

**RC5 intentionally changes the security model:** old networked and persistent analysis modes are removed. To upgrade from RC4 or earlier:

1. **Shut down** existing SafeBox domains normally and independently confirm the absence of running QEMU processes.
2. Back up existing data, but **do not** reuse old session overlays as RC5 runtime data.
3. Review the complete **RC5 source**; install updated helpers using `sudo bash ./install/install-host.sh`.
4. Recheck the LUKS2 backing storage; **reinstall, harden, and seal the Debian base image under RC5**.
5. Repeat `make check`, `make release-check`, `hardware-test`, and manual security acceptance.

**Do not** change `VERSION`, JSON metadata, or checksums merely to circumvent version binding.

## 🧰 Troubleshooting

| Symptom | Possible cause | Next step |
|---|---|---|
| `Configuration status: NOT READY` | Missing host prerequisites, base image, LUKS2, or gate evidence | Check `[FAIL]` lines from `sudo bash ./safebox doctor` |
| `Keine gültige KVM-Hardware-Abnahme` | No successful live test, reboot, or expired 12-hour window | Run `sudo bash ./safebox hardware-test`, then `gate-check` |
| No usable `/dev/kvm` | CPU virtualization disabled or KVM unavailable | Check BIOS/UEFI and host KVM; do not bypass using mocks |
| Runtime helpers missing/mismatched | New source with old installed root-owned helpers | Verify source, then rerun `sudo bash ./install/install-host.sh` |
| Storage not on LUKS2 | Data path is not on a verifiably encrypted volume | Check storage; **do not** format without planning/backups |
| Base sealed with a different version | RC4/RC3 base is not compatible with RC5 | Rebuild and seal an RC5 guest base |
| VM starts but viewer does not | Missing GUI or libvirt access permissions | Inspect desktop/viewer configuration and local access control |
| Cleanup refuses deletion | libvirt unavailable or QEMU state ambiguous | Inspect processes and journal; **do not** force removal |
| `hardware-test` fails | Real policy/device/process mismatch | Preserve logs, fix cause, rerun the full test |

Troubleshoot with harmless test data only. **Do not temporarily disable protections** to make a failing check disappear.

## ⚠️ Security Boundaries and Known Limitations

- **Unknown VM escapes** in QEMU/KVM, the Linux kernel, CPU, or firmware remain possible.
- The host must remain trusted: a compromised host `root` account can subvert the isolation mechanisms.
- **No automatic host disconnection:** absence of a guest NIC does not replace a physically isolated analysis workstation for high-risk malware.
- **No Windows execution environment** or automated malware behavior analysis.
- **LUKS2 protects data at rest** but does not destroy a unique session key; swap, dumps, snapshots, and backups carry separate risks.
- Deleting a temporary QCOW2 overlay provides **no guaranteed proof of irreversible data destruction**.
- Time/configuration checks cannot cover every race condition, side channel, hardware fault, or denial-of-service scenario.
- A passed RC5 hardware test is **not blanket approval to execute arbitrary unknown malware**; it documents specific conditions verified on that host.

Use the [Security Policy](SECURITY.md) to report vulnerabilities. Missing tests and limitations are documented in the [RC5 Audit](docs/security-audit-rc5.md) and [RC5 Validation Plan](docs/validation-rc5.md).

## 📁 Project Layout and Documentation

```text
kvm-qemu-safebox/
├── safebox                    # Main CLI
├── config/                    # Version and security defaults
├── install/                   # Host installer and runtime helpers
├── host/                      # libvirt/QEMU hardening
├── guest/                     # Debian guest hardening
├── vm/templates/              # libvirt domain XML templates
├── tools/                     # Attestation, Security Gate, hardware test
├── network/                   # Installer network and firewall helpers
├── profiles/                  # Resource profiles
├── tests/                     # Regression, mutation, signature tests
├── docs/                      # Threat model, validation, limitations
├── .github/workflows/         # GitHub Actions
├── SECURITY.md                # Vulnerability reporting
├── ATTRIBUTION.md             # Original idea attribution
└── NOTICE                     # Copyright and attribution notices
```

**Read more:** [Architecture](docs/architecture.md) · [Host Hardening](docs/hardening.md) · [Threat Model](docs/threat-model.md) · [Testing](docs/testing.md) · [RC5 Validation](docs/validation-rc5.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Release Process](docs/releases.md).

## ❤️ Project and Credits

> **💡 Original project idea: Esmaralda Haze**  
> Special thanks to **Esmaralda Haze** for the original KVM/QEMU SafeBox idea.
>
> **🛠️ Implementation, development, and extensions: [BlackRabbitZ](https://github.com/BlackRabbitZ)**  
> Project repository: **https://github.com/BlackRabbitZ/kvm-qemu-safebox**

This project is distributed under the **Apache License 2.0**. For license and attribution information, see [LICENSE](LICENSE), [NOTICE](NOTICE), and [ATTRIBUTION.md](ATTRIBUTION.md).

<div align="center">

**Security first: test → validate on real hardware → assess residual risks → only then use it.**

</div>
