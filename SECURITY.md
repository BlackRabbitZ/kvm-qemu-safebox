# Sicherheitsrichtlinie

## Sicherheitsmodell

KVM-QEMU-SafeBox ist ein Defense-in-Depth-Projekt. Es behauptet ausdrücklich **nicht**, unbekannte VM-Escapes unmöglich zu machen.

## Sicherheitslücken melden

Bitte keine ungepatchte Schwachstelle als öffentliches GitHub-Issue veröffentlichen. Nutze stattdessen im Original-Repository **Security → Advisories → New draft security advisory**, sofern verfügbar.

Ein Bericht sollte mindestens enthalten:

- betroffene Version/Commit
- Host-Distribution und Kernel
- QEMU- und libvirt-Version
- reproduzierbare Schritte
- erwartetes und tatsächliches Verhalten
- mögliche Auswirkungen auf Host-/LAN-Isolation

## Unterstützte Version

Während `0.x` wird nur der jeweils aktuelle Stand des Hauptbranches aktiv gepflegt.
