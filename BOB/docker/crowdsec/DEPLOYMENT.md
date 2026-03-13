# 📦 CrowdSec Deployment auf Pi5

Diese Anleitung erklärt, welche Dateien du auf den Pi5 kopieren musst und wie du CrowdSec installierst.

## 📋 Dateien zum Kopieren

### Minimale Installation (nur diese Dateien benötigt):

```
docker/crowdsec/
├── docker-compose.yml      # Hauptkonfiguration (ERFORDERLICH)
├── .env.example            # Umgebungsvariablen-Vorlage (ERFORDERLICH)
├── .gitignore              # Git-Ignore (optional)
└── install.sh              # Installations-Skript (EMPFOHLEN)
```

### Vollständige Installation (mit Dokumentation):

```
docker/crowdsec/
├── docker-compose.yml      # Hauptkonfiguration
├── .env.example            # Umgebungsvariablen-Vorlage
├── .gitignore              # Git-Ignore
├── install.sh              # Installations-Skript
├── README.md               # Vollständige Anleitung
├── QUICKSTART.md           # Schnellstart
├── INTEGRATION.md          # Firewall-Integration
└── DEPLOYMENT.md           # Diese Datei
```

## 🚀 Deployment-Schritte

### Option 1: Mit Git (EMPFOHLEN)

Wenn dein Projekt bereits ein Git-Repository ist:

```bash
# Auf dem Pi5
cd /home/hajo/docker

# Repository pullen (oder klonen)
git pull

# Zum CrowdSec-Verzeichnis wechseln
cd crowdsec

# Installation starten
chmod +x install.sh
sudo ./install.sh
```

### Option 2: Mit rsync (von deinem lokalen Rechner)

```bash
# Von deinem lokalen Rechner aus
# Ersetze <pi5-ip> mit der IP deines Pi5 (z.B. 192.168.178.55)

# Nur die notwendigen Dateien kopieren
rsync -avz --progress \
  docker/crowdsec/docker-compose.yml \
  docker/crowdsec/.env.example \
  docker/crowdsec/install.sh \
  hajo@<pi5-ip>:/home/hajo/docker/crowdsec/

# Oder alle Dateien inklusive Dokumentation
rsync -avz --progress \
  docker/crowdsec/ \
  hajo@<pi5-ip>:/home/hajo/docker/crowdsec/
```

### Option 3: Mit scp (von deinem lokalen Rechner)

```bash
# Von deinem lokalen Rechner aus
# Ersetze <pi5-ip> mit der IP deines Pi5

# Verzeichnis auf Pi5 erstellen
ssh hajo@<pi5-ip> "mkdir -p /home/hajo/docker/crowdsec"

# Dateien kopieren
scp docker/crowdsec/docker-compose.yml \
    docker/crowdsec/.env.example \
    docker/crowdsec/install.sh \
    hajo@<pi5-ip>:/home/hajo/docker/crowdsec/

# Optional: Dokumentation kopieren
scp docker/crowdsec/*.md \
    hajo@<pi5-ip>:/home/hajo/docker/crowdsec/
```

### Option 4: Manuell (einzelne Dateien)

Wenn du die Dateien manuell erstellen möchtest:

```bash
# Auf dem Pi5
cd /home/hajo/docker
mkdir -p crowdsec

# Dateien erstellen und Inhalt einfügen
nano crowdsec/docker-compose.yml    # Inhalt aus docker-compose.yml kopieren
nano crowdsec/.env.example          # Inhalt aus .env.example kopieren
nano crowdsec/install.sh            # Inhalt aus install.sh kopieren

# Ausführbar machen
chmod +x crowdsec/install.sh
```

## 🔧 Installation durchführen

### Automatische Installation (EMPFOHLEN)

```bash
# Auf dem Pi5
cd /home/hajo/docker/crowdsec

# Installations-Skript ausführen
sudo ./install.sh
```

Das Skript führt automatisch aus:
1. ✅ Prüft Voraussetzungen (Docker, nftables)
2. ✅ Erstellt Verzeichnisse (config, data, db)
3. ✅ Erstellt .env aus .env.example
4. ✅ Startet CrowdSec Services
5. ✅ Generiert Bouncer API Key
6. ✅ Konfiguriert Whitelist
7. ✅ Führt Funktionstest durch

### Manuelle Installation

Falls du das Skript nicht verwenden möchtest:

```bash
# 1. Verzeichnisse erstellen
cd /home/hajo/docker/crowdsec
mkdir -p config data db

# 2. .env erstellen
cp .env.example .env

# 3. Services starten
docker compose up -d

# 4. Warte 30 Sekunden
sleep 30

# 5. Bouncer API Key generieren
docker compose exec crowdsec cscli bouncers add firewall-bouncer

# 6. API Key in .env eintragen
nano .env
# BOUNCER_KEY_FIREWALL=<dein-api-key>

# 7. Services neu starten
docker compose down
docker compose up -d

# 8. Whitelist konfigurieren
docker compose exec crowdsec cscli parsers install crowdsecurity/whitelists

docker compose exec crowdsec bash -c 'cat > /etc/crowdsec/parsers/s02-enrich/whitelists.yaml << EOF
name: crowdsecurity/whitelists
description: "Whitelist für vertrauenswürdige IPs"
whitelist:
  reason: "Trusted local network"
  ip:
    - "192.168.178.0/24"
    - "127.0.0.1"
    - "::1"
EOF'

docker compose restart crowdsec

# 9. Installation prüfen
docker compose ps
docker compose exec crowdsec cscli bouncers list
sudo nft list table ip crowdsec
```

## ✅ Installations-Checkliste

Nach der Installation solltest du prüfen:

- [ ] Services laufen: `docker compose ps`
- [ ] Bouncer verbunden: `docker compose exec crowdsec cscli bouncers list`
- [ ] nftables-Tabelle existiert: `sudo nft list table ip crowdsec`
- [ ] Whitelist konfiguriert: `docker compose exec crowdsec cat /etc/crowdsec/parsers/s02-enrich/whitelists.yaml`
- [ ] Funktionstest erfolgreich: Test-IP blockieren und prüfen

## 🔄 Integration in zentrale docker-compose.yml

Um CrowdSec mit anderen Services zu starten:

```bash
# Hauptverzeichnis
cd /home/hajo/docker

# docker-compose.yml bearbeiten
nano docker-compose.yml
```

Füge hinzu (falls noch nicht vorhanden):

```yaml
include:
  - docker/crowdsec/docker-compose.yml
  # ... andere Services
```

Dann:

```bash
# Alle Services starten
docker compose up -d

# Nur CrowdSec starten
docker compose up -d crowdsec crowdsec-firewall-bouncer
```

## 📊 Verzeichnisstruktur nach Installation

```
/home/hajo/docker/crowdsec/
├── docker-compose.yml          # Hauptkonfiguration
├── .env                        # Umgebungsvariablen (mit API Key)
├── .env.example                # Vorlage
├── .gitignore                  # Git-Ignore
├── install.sh                  # Installations-Skript
├── README.md                   # Dokumentation
├── QUICKSTART.md               # Schnellstart
├── INTEGRATION.md              # Firewall-Integration
├── DEPLOYMENT.md               # Diese Datei
├── config/                     # CrowdSec-Konfiguration (automatisch erstellt)
│   ├── acquis.yaml
│   ├── config.yaml
│   └── ...
├── data/                       # CrowdSec-Daten (automatisch erstellt)
└── db/                         # CrowdSec-Datenbank (automatisch erstellt)
    └── crowdsec.db
```

## 🆘 Troubleshooting

### Problem: Verzeichnis existiert nicht

```bash
# Verzeichnis erstellen
mkdir -p /home/hajo/docker/crowdsec
```

### Problem: Keine Schreibrechte

```bash
# Besitzer ändern
sudo chown -R hajo:hajo /home/hajo/docker/crowdsec
```

### Problem: Docker Compose nicht gefunden

```bash
# Docker Compose installieren
sudo apt update
sudo apt install docker-compose-plugin
```

### Problem: Dateien nicht kopiert

```bash
# Prüfe ob Dateien vorhanden sind
ls -la /home/hajo/docker/crowdsec/

# Sollte zeigen:
# docker-compose.yml
# .env.example
# install.sh
```

## 📝 Zusammenfassung

**Minimale Dateien zum Kopieren:**
1. `docker-compose.yml` (ERFORDERLICH)
2. `.env.example` (ERFORDERLICH)
3. `install.sh` (EMPFOHLEN)

**Installation:**
```bash
cd /home/hajo/docker/crowdsec
sudo ./install.sh
```

**Fertig!** 🎉

---

**Made with Bob** 🤖

Für weitere Fragen siehe [README.md](README.md) oder [QUICKSTART.md](QUICKSTART.md).