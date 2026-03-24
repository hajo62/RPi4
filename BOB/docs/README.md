# BOB - Raspberry Pi 5 Server Setup

Dokumentation für den Pi5 Home-Server mit Docker, Traefik, CrowdSec und mehr.

## 📋 Übersicht

Dieses Repository enthält die komplette Konfiguration für einen Raspberry Pi 5 Home-Server mit:
- **Traefik** als Reverse Proxy mit SSL/TLS
- **CrowdSec** für Security & Intrusion Detection
- **Nextcloud** für Cloud-Storage
- **Home Assistant** für Smart Home
- **Weitere Services** (siehe Docker-Verzeichnis)

## 🚀 Quick Start

### Git-basierter Deployment-Workflow

```bash
# Auf dem Mac: Änderungen machen
git add .
git commit -m "Update configuration"
git push pi5 main

# Auf dem Pi5: Automatisch deployed via Git Hook
# Docker-Services werden automatisch neu gestartet
# System-Configs müssen manuell angewendet werden
```

### System-Konfigurationen anwenden

```bash
# Auf dem Pi5
ssh pi5
cd /home/hajo/BOB
sudo ./system/apply-system-config.sh
```

## 📁 Verzeichnisstruktur

```
BOB/
├── docker/              # Docker-Services (Auto-Deployment)
│   ├── docker-compose.yml
│   ├── traefik/
│   ├── crowdsec/
│   ├── nextcloud/
│   └── ...
│
├── system/              # System-Konfigurationen (Manuelles Deployment)
│   ├── firewall/
│   ├── nginx/
│   ├── logrotate/
│   ├── docker-daemon.json
│   └── apply-system-config.sh
│
├── docs/                # Dokumentation
│   ├── README.md
│   ├── docker.md
│   ├── setup/
│   ├── services/       # Docker-Services Dokumentation
│   │   └── traefik/
│   ├── system/         # System-Komponenten Dokumentation
│   │   └── firewall/
│   ├── architecture/
│   └── security/
│
├── backup/              # Backup-Scripts
└── archive/             # Alte Konfigurationen
```

## 📚 Dokumentation

### Setup & Installation
- [Git-basiertes Deployment Setup](setup/Git-Deployment-Setup.md) ⭐
- [Pi5 Ordnerstruktur Empfehlung](setup/Pi5-Ordnerstruktur-Empfehlung.md)
- [Pi5 Ordnerstruktur Begründung](setup/Pi5-Ordnerstruktur-Begründung.md)
- [NFS Setup Pi5 von Pi4](setup/nfs_Pi5_von_Pi4.md)

### Allgemein
- [Docker Setup & Best Practices](docker.md)

### Docker-Services
- **Traefik**
  - [Setup Checkliste](services/traefik/Traefik-Setup-Checkliste.md)
  - [Konfigurationsmethode](services/traefik/Traefik-Konfigurationsmethode-Entscheidung.md)

### System-Komponenten
- **Firewall**
  - [Firewall Konfiguration](system/firewall/Firewall.md)

### Architektur
- [Firewall Architektur](architecture/firewall-architektur.svg)
- [Firewall Zonen](architecture/firewall-zonen.svg)

### Security
- [SSL Server Test Report](security/SSL%20Server%20Test_%20ha.hajo63.de%20(Powered%20by%20Qualys%20SSL%20Labs).pdf)

## 🔧 Deployment-Strategien

### Docker-Services (Automatisch)
- Änderungen werden automatisch deployed
- Container werden automatisch neu gestartet
- Ideal für häufige Updates und Experimente

### System-Konfigurationen (Manuell)
- Änderungen werden nur kopiert
- Manuelle Bestätigung erforderlich
- Sicherer für kritische System-Einstellungen

## 🌿 Git Workflow

### Feature-Branches für Experimente

```bash
# Neuen Feature-Branch erstellen
git checkout -b feature/neue-funktion

# Änderungen machen und testen
git add .
git commit -m "Add neue Funktion"

# Wenn erfolgreich: Mergen
git checkout main
git merge feature/neue-funktion
git push pi5 main
```

### Rollback bei Problemen

```bash
# Letzten Commit rückgängig machen
git revert HEAD
git push pi5 main

# Oder zu einem bestimmten Commit zurück
git reset --hard <commit-hash>
git push pi5 main --force
```

## 🔐 Sicherheit

- Sensible Daten (`.env`, Passwörter, Zertifikate) sind in `.gitignore`
- Verwende `.env.example` Templates für Konfigurationen
- System-Änderungen erfordern manuelle Bestätigung
- Firewall-Regeln werden über nftables verwaltet

## 📞 Support

Bei Fragen oder Problemen siehe die entsprechende Dokumentation im `docs/` Verzeichnis.

## 📝 Lizenz

Privates Projekt - Alle Rechte vorbehalten