# Sichere Releases und Verifikation

SafeBox v0.5.1-rc5 erzeugt für jeden Release vier Kernartefakte:

- `kvm-qemu-safebox-VERSION.zip`
- `kvm-qemu-safebox-VERSION.tar.gz`
- `kvm-qemu-safebox-VERSION.spdx.json`
- `kvm-qemu-safebox-VERSION.sha256`

## Release lokal bauen

```bash
bash ./tools/build-release.sh
```

Die Dateien landen standardmäßig unter `dist/`.

## Release mit GPG signieren

```bash
bash ./tools/build-release.sh --sign DEIN_GPG_KEY_ID
```

Dadurch werden detached ASCII-Signaturen (`.asc`) für ZIP, tar.gz, SBOM und Prüfsummenmanifest erzeugt. Der öffentliche Schlüssel muss den Empfängern über einen **unabhängigen vertrauenswürdigen Kanal** bekannt sein.

## Artefakte prüfen

```bash
# Signierschlüssel zuvor unabhängig besorgen und in GPG importieren.
SAFEBOX_SIGNING_FINGERPRINT='HIER_40_HEX_ZEICHEN_EINTRAGEN' \
  bash ./tools/verify-release.sh dist 0.5.1-rc5
```

Alle vier `.asc`-Dateien sind **zwingend** erforderlich. Jede Signatur wird kryptografisch überprüft und anhand des **explizit gepinnten** 40-stelligen Fingerprints abgeglichen. Fehlender Fingerprint, andere Schlüssel oder fehlende Signaturen führen zu einem Fehler. Lokal mit `build-release.sh` ohne `--sign` erzeugte ZIP-Dateien sind nur **unsignierte Test-/Quellcodearchive**, kein authentifiziertes offizielles Release.

## Git-Tag signieren

Empfohlen wird ein signierter annotierter Tag:

```bash
git tag -s v0.5.1-rc5 -m "KVM/QEMU SafeBox v0.5.1-rc5"
git push origin v0.5.1-rc5
```

Prüfung:

```bash
git verify-tag v0.5.1-rc5
bash ./tools/verify-signed-tag.sh v0.5.1-rc5
```

Der GitHub-Release-Workflow prüft den signierten Git-Tag, importiert einen mit dem erwarteten Fingerprint versehenen **privaten GPG-Signierschlüssel** aus dem GitHub-Actions-Secret `RELEASE_GPG_PRIVATE_KEY_B64`, signiert **alle vier** Dateien und erstellt nur nach erfolgreicher Artefaktverifikation einen **Draft Release**. Fehlt das Secret, bleibt der Build gesperrt. Der Signierschlüssel sollte möglichst dediziert sein und separat geschützt werden.

## GitHub Actions vorbereiten

Die GitHub-Actions-Variable `RELEASE_SIGNER_FINGERPRINT` muss dem erwarteten 40-stelligen Fingerprint entsprechen. Das Secret `RELEASE_GPG_PRIVATE_KEY_B64` enthält den Base64-kodierten, für CI nutzbaren (z. B. gesonderten) GPG-Private-Key. **Ein passwortgeschützter Schlüssel benötigt in CI eine sichere, nicht-interaktive Passphrase-Verwaltung**; aktuell erwartet der Workflow einen in der CI-Umgebung ohne interaktive PIN nutzbaren Schlüssel. Den privaten Hauptschlüssel niemals in ein Repository committen. Bei ungeklärter Schlüsselbereitstellung Releases gesperrt lassen.

## Gepinnter Release-Signer

Vor einem GitHub-Release muss im Repository die Actions-Variable `RELEASE_SIGNER_FINGERPRINT` auf den vollständigen Fingerprint des erlaubten BlackRabbitZ-GPG-Release-Keys gesetzt werden. Der Workflow importiert die bei GitHub veröffentlichten GPG-Keys von `BlackRabbitZ` und akzeptiert den Tag nur, wenn `git verify-tag --raw` exakt diesen Fingerprint als `VALIDSIG` meldet. Eine gültige Signatur eines anderen Keys wird abgelehnt.
