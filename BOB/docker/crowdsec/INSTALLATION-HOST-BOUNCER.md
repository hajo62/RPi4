# 🔧 CrowdSec Firewall Bouncer - Host-Installation

Da es kein offizielles Docker Image für den Firewall Bouncer gibt, muss dieser auf dem Host installiert werden.

## ⚠️ Wichtig: rsyslog erforderlich!

**RaspberryOS Trixie nutzt standardmäßig journald statt klassischer Log-Dateien.**

CrowdSec benötigt aber Log-Dateien, daher muss rsyslog installiert werden:

```bash
sudo apt install rsyslog
sudo systemctl enable rsyslog
sudo systemctl start rsyslog

# Prüfen ob Logs geschrieben werden
tail -f /var/log/auth.log
```

**Ohne rsyslog kann CrowdSec keine SSH-Angriffe erkennen!**

## 📋 Übersicht

```
┌─────────────────────────────────────────┐
│           Docker Container              │
│  ┌──────────────────────────────────┐  │
│  │  CrowdSec (LAPI)                 │  │
│  │  - Analysiert Logs               │  │
│  │  - Trifft Entscheidungen         │  │
│  │  - API auf Port 8080             │  │
│  └──────────────┬───────────────────┘  │
└─────────────────┼──────────────────────┘
                  │ API (localhost:8080)
                  │
┌─────────────────▼──────────────────────┐
│           Host System                  │
│  ┌──────────────────────────────────┐  │
│  │  Firewall Bouncer (systemd)      │  │
│  │  - Holt Entscheidungen von API   │  │
│  │  - Blockiert IPs in nftables     │  │
│  └──────────────┬───────────────────┘  │
│                 │                       │
│  ┌──────────────▼───────────────────┐  │
│  │  nftables Firewall               │  │
│  │  - Blockiert böse IPs            │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

## 🚀 Installation

### Schritt 1: CrowdSec Container starten

```bash
cd /home/hajo/docker/crowdsec
docker compose up -d
```

Warte ca. 30 Sekunden, bis CrowdSec vollständig gestartet ist.

### Schritt 2: Bouncer API Key generieren

```bash
docker compose exec crowdsec cscli bouncers add firewall-bouncer
```

**Wichtig**: Kopiere den API Key! Du brauchst ihn gleich.

Beispiel-Output:
```
Api key for 'firewall-bouncer':
   abc123def456ghi789jkl012mno345pqr678stu901vwx234yz

Please keep this key since you will not be able to retrieve it!
```

### Schritt 3: CrowdSec Repository hinzufügen

```bash
# Repository-Skript herunterladen und ausführen
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | sudo bash

# Für Debian Trixie (Testing): Ersetze mit Bookworm (Stable)
# da Trixie noch nicht offiziell unterstützt wird
sudo sed -i 's/trixie/bookworm/g' /etc/apt/sources.list.d/crowdsec_crowdsec.list
```

**Hinweis für Debian Trixie**: Das CrowdSec-Repository unterstützt Trixie noch nicht offiziell. Wir nutzen daher die Bookworm-Pakete, die kompatibel sind.

### Schritt 4: Firewall Bouncer installieren

```bash
sudo apt update
sudo apt install crowdsec-firewall-bouncer-nftables
```

### Schritt 5: Bouncer konfigurieren

```bash
sudo nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```

Wichtige Einstellungen:

```yaml
# CrowdSec API Verbindung
api_url: http://localhost:8080
api_key: abc123def456ghi789jkl012mno345pqr678stu901vwx234yz  # Dein API Key!

# Firewall-Modus
mode: nftables

# nftables Konfiguration
nftables:
  ipv4:
    enabled: true
    set-only: false
    table: crowdsec
    chain: crowdsec-chain
  ipv6:
    enabled: true
    set-only: false
    table: crowdsec6
    chain: crowdsec6-chain

# Blacklist-Modus
blacklists_ipv4: crowdsec-blacklists
blacklists_ipv6: crowdsec6-blacklists

# Update-Intervall (mit Zeiteinheit!)
update_frequency: 10s

# Log-Einstellungen
log_mode: file
log_dir: /var/log/
log_level: info
log_compression: true
log_max_size: 40
log_max_backups: 3
log_max_age: 30

# Prometheus Metrics (optional)
prometheus:
  enabled: false
  listen_addr: 127.0.0.1
  listen_port: 60601
```

### Schritt 6: Bouncer starten

```bash
# Aktivieren (automatischer Start beim Boot)
sudo systemctl enable crowdsec-firewall-bouncer

# Starten
sudo systemctl start crowdsec-firewall-bouncer

# Status prüfen
sudo systemctl status crowdsec-firewall-bouncer
```

### Schritt 7: Installation prüfen

```bash
# 1. Bouncer-Status im CrowdSec Container
docker compose exec crowdsec cscli bouncers list

# Sollte zeigen:
# NAME              IP ADDRESS    VALID  LAST API PULL
# firewall-bouncer  127.0.0.1     ✔️     2s

# 2. nftables-Tabelle prüfen
sudo nft list table ip crowdsec

# Sollte zeigen:
# table ip crowdsec {
#     set crowdsec-blacklists {
#         type ipv4_addr
#         flags timeout
#     }
#     
#     chain crowdsec-chain {
#         type filter hook input priority -10; policy accept;
#         ip saddr @crowdsec-blacklists drop
#     }
# }

# 3. Bouncer-Logs prüfen
sudo journalctl -u crowdsec-firewall-bouncer -f
```

## 🧪 Funktionstest

```bash
# 1. Test-IP blockieren
docker compose exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 5m --reason "Test"

# 2. Prüfen ob IP in nftables ist
sudo nft list set ip crowdsec crowdsec-blacklists

# Sollte enthalten:
# elements = { 1.2.3.4 timeout 5m }

# 3. Test-IP wieder entfernen
docker compose exec crowdsec cscli decisions delete --ip 1.2.3.4
```

## 🛡️ Whitelist konfigurieren

Die Whitelist-Datei liegt bereits im Repository unter:
`docker/crowdsec/config/parsers/s02-enrich/mywhitelists.yaml`

Sie wird automatisch via Volume-Mount in den Container eingebunden.

**Wichtig:** CIDR-Notation (`/24`, `/12`) muss unter `cidr:` stehen, **nicht** unter `ip:` – sonst crasht CrowdSec beim Start!

```yaml
whitelist:
  ip:
    - "127.0.0.1"      # Einzelne IPs hier
    - "::1"
  cidr:
    - "192.168.178.0/24"   # Netzwerke hier (CIDR)
    - "172.16.0.0/12"      # Alle Docker-Netzwerke
```

Nach Änderungen an der Whitelist:
```bash
cd ~/docker/crowdsec
docker compose restart crowdsec

# Prüfen ob CrowdSec korrekt startet (kein "fatal" Fehler)
docker compose logs --tail=20 crowdsec
```

## 📊 Wichtige Befehle

### CrowdSec (Container)

```bash
# Status
docker compose ps

# Logs
docker compose logs -f crowdsec

# Geblockte IPs
docker compose exec crowdsec cscli decisions list

# Alerts
docker compose exec crowdsec cscli alerts list

# Metriken
docker compose exec crowdsec cscli metrics

# Bouncer-Status
docker compose exec crowdsec cscli bouncers list
```

### Firewall Bouncer (Host)

```bash
# Status
sudo systemctl status crowdsec-firewall-bouncer

# Logs
sudo journalctl -u crowdsec-firewall-bouncer -f

# Neu starten
sudo systemctl restart crowdsec-firewall-bouncer

# Stoppen
sudo systemctl stop crowdsec-firewall-bouncer

# Deaktivieren
sudo systemctl disable crowdsec-firewall-bouncer
```

### nftables

```bash
# CrowdSec-Tabelle anzeigen
sudo nft list table ip crowdsec

# Geblockte IPs anzeigen
sudo nft list set ip crowdsec crowdsec-blacklists

# Alle Tabellen anzeigen
sudo nft list ruleset
```

## 🔧 Troubleshooting

### Problem: Bouncer kann nicht mit CrowdSec kommunizieren

**Symptom**: `cscli bouncers list` zeigt Bouncer nicht oder "last pull" ist alt

**Lösung**:

```bash
# 1. Prüfe ob CrowdSec läuft
docker compose ps

# 2. Prüfe ob Port 8080 erreichbar ist
curl http://localhost:8080/v1/decisions

# 3. Prüfe API Key in Bouncer-Konfiguration
sudo cat /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml | grep api_key

# 4. Prüfe Bouncer-Logs
sudo journalctl -u crowdsec-firewall-bouncer -n 50

# 5. Neuen API Key generieren
docker compose exec crowdsec cscli bouncers delete firewall-bouncer
docker compose exec crowdsec cscli bouncers add firewall-bouncer

# 6. Neuen Key in Konfiguration eintragen
sudo nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml

# 7. Bouncer neu starten
sudo systemctl restart crowdsec-firewall-bouncer
```

### Problem: nftables-Tabelle wird nicht erstellt

**Symptom**: `sudo nft list table ip crowdsec` zeigt Fehler

**Lösung**:

```bash
# 1. Prüfe Bouncer-Status
sudo systemctl status crowdsec-firewall-bouncer

# 2. Prüfe Bouncer-Logs
sudo journalctl -u crowdsec-firewall-bouncer -n 100

# 3. Prüfe nftables-Konfiguration
sudo cat /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml | grep -A 10 nftables

# 4. Bouncer neu starten
sudo systemctl restart crowdsec-firewall-bouncer

# 5. Warte 10 Sekunden und prüfe erneut
sleep 10
sudo nft list table ip crowdsec
```

### Problem: IPs werden nicht blockiert

**Symptom**: Decisions vorhanden, aber nicht in nftables

**Lösung**:

```bash
# 1. Prüfe Decisions
docker compose exec crowdsec cscli decisions list

# 2. Prüfe Bouncer-Verbindung
docker compose exec crowdsec cscli bouncers list

# 3. Prüfe nftables
sudo nft list set ip crowdsec crowdsec-blacklists

# 4. Bouncer-Logs prüfen
sudo journalctl -u crowdsec-firewall-bouncer -f

# 5. Bouncer neu starten
sudo systemctl restart crowdsec-firewall-bouncer
```

## 🔄 Updates

### CrowdSec Container

```bash
cd /home/hajo/docker/crowdsec
docker compose pull
docker compose up -d
```

### Firewall Bouncer (Host)

```bash
sudo apt update
sudo apt upgrade crowdsec-firewall-bouncer-nftables
sudo systemctl restart crowdsec-firewall-bouncer
```

## 🗑️ Deinstallation

### Firewall Bouncer entfernen

```bash
# Stoppen und deaktivieren
sudo systemctl stop crowdsec-firewall-bouncer
sudo systemctl disable crowdsec-firewall-bouncer

# Deinstallieren
sudo apt remove crowdsec-firewall-bouncer-nftables

# Konfiguration entfernen (optional)
sudo rm -rf /etc/crowdsec/bouncers/

# nftables-Tabelle entfernen
sudo nft delete table ip crowdsec
sudo nft delete table ip6 crowdsec6
```

### CrowdSec Container entfernen

```bash
cd /home/hajo/docker/crowdsec
docker compose down
docker compose down -v  # Mit Volumes
```

## 📝 Zusammenfassung

**Installation:**
1. CrowdSec Container starten
2. API Key generieren
3. Bouncer auf Host installieren
4. Bouncer konfigurieren
5. Bouncer starten

**Verwaltung:**
- CrowdSec: Docker Compose
- Bouncer: systemd
- Firewall: nftables

**Vorteile dieser Lösung:**
- ✅ CrowdSec isoliert im Container
- ✅ Bouncer hat direkten Firewall-Zugriff
- ✅ Einfache Updates für beide Komponenten
- ✅ Klare Trennung der Verantwortlichkeiten

---

**Made with Bob** 🤖

Für weitere Fragen siehe [README.md](README.md) oder [QUICKSTART.md](QUICKSTART.md).