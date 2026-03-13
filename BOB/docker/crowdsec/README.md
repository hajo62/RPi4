# 🛡️ CrowdSec - Kollaborative IPS/IDS Lösung

CrowdSec ist eine moderne, Open-Source IPS/IDS-Lösung, die böse IP-Adressen automatisch über die Firewall blockiert. Es analysiert Logs, erkennt Angriffsmuster und teilt Bedrohungsinformationen mit der Community.

## 📋 Inhaltsverzeichnis

- [Features](#-features)
- [Architektur](#-architektur)
- [Installation](#-installation)
- [Konfiguration](#-konfiguration)
- [Verwendung](#-verwendung)
- [Integration mit Traefik](#-integration-mit-traefik)
- [Direct-IP Blocking](#-direct-ip-blocking)
- [Docker FORWARD Chain](#-docker-forward-chain)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)
- [Wartung](#-wartung)

## ✨ Features

- **Automatische Bedrohungserkennung**: Analysiert Logs und erkennt Angriffsmuster
- **Firewall-Integration**: Blockiert böse IPs über nftables/iptables
- **Community-Intelligence**: Teilt und empfängt Bedrohungsinformationen
- **Multi-Service-Support**: SSH, nginx, Traefik, und viele mehr
- **Echtzeit-Schutz**: Reagiert sofort auf erkannte Bedrohungen
- **Niedrige Ressourcennutzung**: Perfekt für Raspberry Pi

## 🏗️ Architektur

```
┌─────────────────────────────────────────────────────────┐
│                    CrowdSec System                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐         ┌──────────────┐            │
│  │   CrowdSec   │◄────────┤  Log Files   │            │
│  │   (LAPI)     │         │  - auth.log  │            │
│  │              │         │  - syslog    │            │
│  │  Analysiert  │         │  - traefik   │            │
│  │  Entscheidet │         │  - nginx     │            │
│  └──────┬───────┘         └──────────────┘            │
│         │                                              │
│         │ API (Port 8080)                              │
│         │                                              │
│  ┌──────▼───────────────┐                             │
│  │  Firewall Bouncer    │                             │
│  │  (nftables)          │                             │
│  │                      │                             │
│  │  Blockiert IPs       │                             │
│  └──────┬───────────────┘                             │
│         │                                              │
└─────────┼──────────────────────────────────────────────┘
          │
          ▼
    ┌─────────────┐
    │  nftables   │
    │  Firewall   │
    └─────────────┘
```

## 🚀 Installation

### 0. rsyslog installieren (WICHTIG!)

**RaspberryOS Trixie nutzt journald statt klassischer Log-Dateien.**

CrowdSec benötigt aber Log-Dateien:

```bash
sudo apt install rsyslog
sudo systemctl enable rsyslog
sudo systemctl start rsyslog

# Prüfen ob Logs geschrieben werden
tail -f /var/log/auth.log
```

**Ohne rsyslog kann CrowdSec keine SSH-Angriffe erkennen!**

### 1. Verzeichnisstruktur erstellen

```bash
cd /home/hajo/docker/crowdsec
mkdir -p config data db
```

### 2. Umgebungsvariablen konfigurieren

```bash
cp .env.example .env
nano .env
```

### 3. Services starten

```bash
# Erstmaliger Start (generiert Konfiguration)
docker compose up -d

# Logs verfolgen
docker compose logs -f
```

### 4. Bouncer API Key generieren

```bash
# API Key für Firewall Bouncer erstellen
docker compose exec crowdsec cscli bouncers add firewall-bouncer

# Output: API Key kopieren und in .env eintragen
# Beispiel: BOUNCER_KEY_FIREWALL=abc123def456...
```

### 5. Services neu starten

```bash
# Nach .env Anpassung
docker compose down
docker compose up -d
```

## ⚙️ Konfiguration

### Collections (Regelsets)

CrowdSec verwendet "Collections" für verschiedene Services:

```yaml
# In docker-compose.yml bereits konfiguriert:
COLLECTIONS=crowdsecurity/linux crowdsecurity/sshd crowdsecurity/nginx crowdsecurity/traefik crowdsecurity/http-cve
```

Basis-Collections (automatisch installiert):
- `crowdsecurity/linux` - Basis Linux-Schutz
- `crowdsecurity/sshd` - SSH Brute-Force Schutz
- `crowdsecurity/nginx` - nginx Web-Angriffe
- `crowdsecurity/traefik` - Traefik Reverse Proxy
- `crowdsecurity/http-cve` - Bekannte HTTP CVEs

### Erweiterte Scenarios installieren

Für erweiterten Schutz wurden zusätzliche Scenarios vorbereitet:

```bash
# Automatische Installation aller empfohlenen Scenarios
cd /home/hajo/docker/crowdsec
chmod +x scripts/install-scenarios.sh
./scripts/install-scenarios.sh
```

**Installierte Scenarios umfassen:**

**HTTP-Angriffe:**
- `crowdsecurity/http-bad-user-agent` - Böse User-Agents (Bots, Scanner)
- `crowdsecurity/http-crawl-non_statics` - Aggressive Crawler
- `crowdsecurity/http-probing` - Probing-Angriffe (Schwachstellen-Scans)
- `crowdsecurity/http-sensitive-files` - Zugriffe auf sensible Dateien (.env, .git)
- `crowdsecurity/http-generic-bf` - Generischer HTTP Brute-Force
- `crowdsecurity/http-dos` - DoS-Angriffe
- `crowdsecurity/http-path-traversal-probing` - Path Traversal
- `crowdsecurity/http-backdoors-attempts` - Backdoor-Versuche
- `crowdsecurity/http-sqli-probing` - SQL Injection
- `crowdsecurity/http-xss-probing` - XSS-Angriffe

**Service-spezifisch:**
- `crowdsecurity/home-assistant-bf` - Home Assistant Brute-Force
- `crowdsecurity/nextcloud-bf` - Nextcloud Brute-Force

### Log-Dateien hinzufügen

Bearbeite `docker-compose.yml` und füge weitere Logs hinzu:

```yaml
volumes:
  # Traefik Logs (wenn Traefik installiert ist)
  - /home/hajo/docker/traefik/logs:/var/log/traefik:ro
  
  # nginx Logs vom Pi4 (via NFS)
  - /mnt/pi4-logs/nginx:/var/log/nginx:ro
```

### Firewall-Modus

Der Bouncer unterstützt verschiedene Modi:

- `drop` (Standard): Pakete verwerfen (empfohlen)
- `reject`: Pakete ablehnen mit ICMP-Antwort
- `tarpit`: Verbindungen verlangsamen

```yaml
# In docker-compose.yml
environment:
  - MODE=drop
```

## 📊 Verwendung

### Wichtige Befehle

```bash
# Status prüfen
docker compose ps

# Logs anzeigen
docker compose logs -f crowdsec
docker compose logs -f crowdsec-firewall-bouncer

# Geblockte IPs anzeigen
docker compose exec crowdsec cscli decisions list

# Spezifische IP blockieren (manuell)
docker compose exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 24h --reason "Manual block"

# IP entsperren
docker compose exec crowdsec cscli decisions delete --ip 1.2.3.4

# Alle Entscheidungen löschen
docker compose exec crowdsec cscli decisions delete --all

# Bouncer-Status
docker compose exec crowdsec cscli bouncers list

# Metriken anzeigen
docker compose exec crowdsec cscli metrics

# Alerts anzeigen
docker compose exec crowdsec cscli alerts list

# Hub-Status (installierte Collections)
docker compose exec crowdsec cscli hub list
```

### Scenarios (Angriffsszenarien)

```bash
# Alle Scenarios anzeigen
docker compose exec crowdsec cscli scenarios list

# Erweiterte Scenarios installieren (empfohlen)
./scripts/install-scenarios.sh

# Einzelnes Scenario manuell installieren
docker compose exec crowdsec cscli scenarios install crowdsecurity/http-bad-user-agent

# Scenario deaktivieren
docker compose exec crowdsec cscli scenarios remove crowdsecurity/http-bad-user-agent

# Installierte Scenarios prüfen
docker compose exec crowdsec cscli scenarios list | grep INSTALLED
```

## 🔗 Integration mit Traefik

### 1. Traefik Logs aktivieren

In deiner Traefik-Konfiguration:

```yaml
# traefik.yml
accessLog:
  filePath: "/var/log/traefik/access.log"
  format: json
```

### 2. Logs in CrowdSec einbinden

```yaml
# docker-compose.yml
volumes:
  - /home/hajo/docker/traefik/logs:/var/log/traefik:ro
```

### 3. Traefik Collection aktivieren

```bash
docker compose exec crowdsec cscli collections install crowdsecurity/traefik
docker compose restart crowdsec
```

### 4. Acquisition konfigurieren

CrowdSec erstellt automatisch `/etc/crowdsec/acquis.yaml`. Prüfen:

```bash
docker compose exec crowdsec cat /etc/crowdsec/acquis.yaml
```

Sollte enthalten:

```yaml
filenames:
  - /var/log/traefik/access.log
labels:
  type: traefik
```

## 🐳 Docker FORWARD Chain

**WICHTIG für Docker-Container wie Traefik!**

Der Standard Firewall-Bouncer blockt nur **INPUT-Traffic** (direkte Verbindungen zum Server). Docker-Container sind jedoch über **FORWARD-Traffic** erreichbar.

### Problem

Ohne FORWARD-Chain:
- ✅ SSH-Zugriff zum Server wird geblockt
- ❌ HTTPS-Zugriff zu Traefik (Docker) wird NICHT geblockt

### Lösung

Die FORWARD-Chain wurde automatisch eingerichtet:

```bash
# Prüfen ob aktiv
sudo nft list chain ip crowdsec crowdsec-chain-forward

# Service-Status
sudo systemctl status crowdsec-forward-chain.service
```

### Vollständige Dokumentation

Siehe **[DOCKER-FORWARD-CHAIN.md](DOCKER-FORWARD-CHAIN.md)** für:
- Detaillierte Erklärung der Architektur
- Installation und Konfiguration
- Verifikation und Testing
- Troubleshooting

**Kategorie**: Firewall-Konfiguration (nftables) mit CrowdSec-Integration

## 📈 Monitoring

### Prometheus Metrics (Optional)

CrowdSec exportiert Metriken auf Port 6060:

```yaml
# docker-compose.yml (auskommentiert)
ports:
  - "6060:6060"
```

Metriken abrufen:

```bash
curl http://localhost:6060/metrics
```

### CrowdSec Dashboard (Web UI)

Installiere Metabase für ein Web-Dashboard:

```bash
docker compose exec crowdsec cscli dashboard setup
```

### CrowdSec Central API (Optional)

Für zentrale Verwaltung und Community-Intelligence:

1. Registriere dich auf https://app.crowdsec.net
2. Erstelle eine Instanz und erhalte einen Enrollment Key
3. Füge in `.env` hinzu:

```bash
ENROLL_KEY=your_enroll_key_here
ENROLL_INSTANCE_NAME=rpi5-traefik
ENROLL_TAGS=raspberry-pi,traefik,home-server
```

4. Starte neu:

```bash
docker compose down
docker compose up -d
```

## 🔍 Troubleshooting

### Problem: Bouncer kann nicht mit CrowdSec kommunizieren

**Symptom**: Bouncer-Logs zeigen API-Fehler

**Lösung**:

```bash
# 1. API Key prüfen
docker compose exec crowdsec cscli bouncers list

# 2. Neuen Key generieren
docker compose exec crowdsec cscli bouncers add firewall-bouncer-new

# 3. In .env eintragen und neu starten
docker compose down
docker compose up -d
```

### Problem: Keine IPs werden blockiert

**Symptom**: `cscli decisions list` ist leer

**Lösung**:

```bash
# 1. Logs prüfen
docker compose logs crowdsec | grep -i error

# 2. Acquisition prüfen
docker compose exec crowdsec cat /etc/crowdsec/acquis.yaml

# 3. Scenarios prüfen
docker compose exec crowdsec cscli scenarios list

# 4. Manuell testen
docker compose exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 1h
```

### Problem: Firewall-Regeln werden nicht angewendet

**Symptom**: IPs in Decisions, aber nicht in nftables

**Lösung**:

```bash
# 1. Bouncer-Logs prüfen
docker compose logs crowdsec-firewall-bouncer

# 2. nftables prüfen
sudo nft list ruleset | grep crowdsec

# 3. Bouncer neu starten
docker compose restart crowdsec-firewall-bouncer
```

### Problem: Zu viele False Positives

**Symptom**: Legitime IPs werden blockiert

**Lösung**:

```bash
# 1. Whitelist erstellen
docker compose exec crowdsec cscli parsers install crowdsecurity/whitelists

# 2. Whitelist konfigurieren
docker compose exec crowdsec nano /etc/crowdsec/parsers/s02-enrich/whitelists.yaml

# Beispiel:
# name: crowdsecurity/whitelists
# whitelist:
#   reason: "Trusted IPs"
#   ip:
#     - "192.168.178.0/24"
#     - "10.0.0.0/8"

# 3. Neu laden
docker compose restart crowdsec
```

### Automatische Whitelist-Aktualisierung bei dynamischer IP

**Symptom**: Externe IP ändert sich (DynDNS), alte IP wird geblockt

**Lösung**: Automatische Integration mit ionos-dyndns

Das System aktualisiert die Whitelist automatisch, wenn sich die externe IP ändert:

```bash
# 1. Whitelist-Script ist bereits vorhanden
/home/hajo/docker/crowdsec/scripts/update-whitelist.sh

# 2. Integration mit DynDNS ist aktiv
# Bei IP-Änderung wird automatisch die Whitelist aktualisiert

# 3. Manuelle Aktualisierung (falls nötig)
sudo /home/hajo/docker/crowdsec/scripts/update-whitelist.sh

# 4. Status prüfen
cat /home/hajo/docker/crowdsec/config/parsers/s02-enrich/mywhitelists.yaml
```

**Wie es funktioniert:**
1. DynDNS-Script erkennt IP-Änderung
2. Aktualisiert `ionos-dyndns/data/status.json`
3. Triggert automatisch Whitelist-Update
4. CrowdSec wird neu gestartet
5. Neue IP ist whitelisted

**Voraussetzung:** Sudoers-Regel muss eingerichtet sein (siehe INTEGRATION.md)

### Problem: Hohe CPU-Last

**Symptom**: CrowdSec verbraucht viel CPU

**Lösung**:

```bash
# 1. Metriken prüfen
docker compose exec crowdsec cscli metrics

# 2. Log-Parsing reduzieren (weniger Logs)
# 3. Update-Frequenz erhöhen (weniger Updates)
# In docker-compose.yml:
# UPDATE_FREQUENCY=30  # statt 10 Sekunden
```

## 🔧 Wartung

### Regelmäßige Aufgaben

```bash
# Wöchentlich: Hub aktualisieren
docker compose exec crowdsec cscli hub update
docker compose exec crowdsec cscli hub upgrade

# Monatlich: Alte Entscheidungen bereinigen
docker compose exec crowdsec cscli decisions delete --all

# Logs rotieren (automatisch via Docker)
docker compose logs --tail=1000 crowdsec > crowdsec-$(date +%Y%m%d).log
```

### Backup

```bash
# Konfiguration sichern
tar -czf crowdsec-backup-$(date +%Y%m%d).tar.gz config/

# Datenbank sichern
tar -czf crowdsec-db-backup-$(date +%Y%m%d).tar.gz db/
```

### Updates

```bash
# Images aktualisieren
docker compose pull

# Services neu starten
docker compose down
docker compose up -d

# Hub aktualisieren
docker compose exec crowdsec cscli hub update
docker compose exec crowdsec cscli hub upgrade
```

## 📚 Weiterführende Ressourcen

- **Offizielle Dokumentation**: https://docs.crowdsec.net
- **Hub (Collections & Scenarios)**: https://hub.crowdsec.net
- **Community Forum**: https://discourse.crowdsec.net
- **GitHub**: https://github.com/crowdsecurity/crowdsec

## 🔐 Sicherheitshinweise

1. **API Keys schützen**: Niemals in Git committen
2. **Whitelists pflegen**: Eigene IPs nicht aussperren
3. **Logs überwachen**: Regelmäßig auf False Positives prüfen
4. **Updates einspielen**: Sicherheitsupdates zeitnah installieren
5. **Backup erstellen**: Konfiguration regelmäßig sichern

## 📝 Beispiel-Workflow

### Tägliche Routine

```bash
# 1. Status prüfen
docker compose ps

# 2. Geblockte IPs anzeigen
docker compose exec crowdsec cscli decisions list

# 3. Alerts prüfen
docker compose exec crowdsec cscli alerts list --limit 10
```

### Bei Angriff

```bash
# 1. Aktuelle Angriffe anzeigen
docker compose exec crowdsec cscli alerts list --limit 20

# 2. Details zu einem Alert
docker compose exec crowdsec cscli alerts inspect <alert_id>

# 3. Manuell blockieren (falls nötig)
docker compose exec crowdsec cscli decisions add --ip <ip> --duration 24h --reason "Manual block after attack"
```

## 🎯 Best Practices

1. **Starte mit Standard-Collections**: Füge später spezifische hinzu
2. **Überwache die ersten Tage**: Prüfe auf False Positives
3. **Whitelist dein Netzwerk**: Verhindere Aussperrung
4. **Aktiviere Community-Intelligence**: Profitiere von globalen Daten
5. **Dokumentiere Änderungen**: Halte Anpassungen fest

---

**Made with Bob** 🤖

Für Fragen oder Probleme: Siehe [Troubleshooting](#-troubleshooting) oder die [offizielle Dokumentation](https://docs.crowdsec.net).