# CrowdSec Integration mit Traefik

Detaillierte Anleitung zur Integration von CrowdSec mit Traefik.

## 🎯 Übersicht

Sie haben bereits:
- ✅ **CrowdSec Container** - Analysiert Logs, trifft Entscheidungen
- ✅ **Firewall Bouncer (Host)** - Blockiert IPs in nftables

Jetzt kommt hinzu:
- 🆕 **Traefik Bouncer Plugin** - Blockiert IPs auf HTTP-Ebene (in Traefik)

```
┌─────────────────────────────────────────┐
│ CrowdSec Container (docker/crowdsec)    │
│ - Analysiert Logs                       │
│ - Trifft Entscheidungen                 │
│ - API auf Port 8080                     │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌──────────────┐  ┌─────────────────────┐
│ Firewall     │  │ Traefik Plugin      │
│ Bouncer      │  │ (NEU!)              │
│ (Host)       │  │                     │
│              │  │ - Läuft in Traefik  │
│ - nftables   │  │ - HTTP-Level Block  │
│ - Kernel     │  │ - Braucht API-Key   │
└──────────────┘  └─────────────────────┘
```

## 📋 Voraussetzungen

- ✅ CrowdSec Container läuft (`docker/crowdsec/`)
- ✅ Firewall Bouncer auf Host installiert
- ✅ CrowdSec-Netzwerk existiert (`crowdsec-net`)
- 🆕 Traefik braucht API-Key für Plugin

## 🔧 Setup

### Warum braucht Traefik einen eigenen API-Key?

Sie haben bereits einen API-Key für den **Firewall Bouncer** (auf dem Host). Der **Traefik Bouncer Plugin** braucht einen **separaten API-Key**, weil:

1. **Verschiedene Bouncer** - Firewall-Bouncer (nftables) vs. Traefik-Plugin (HTTP)
2. **Verschiedene Zugriffsebenen** - Jeder Bouncer hat eigene Berechtigungen
3. **Unabhängiges Monitoring** - Sie können sehen, welcher Bouncer aktiv ist

### 1. Neuen API-Key für Traefik generieren

```bash
cd docker/crowdsec

# Neuen Bouncer für Traefik registrieren
docker compose exec crowdsec cscli bouncers add traefik-bouncer

# Output:
# Api key for 'traefik-bouncer':
#    abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
#
# Please keep this key since you will not be able to retrieve it!
```

**Wichtig:**
- Dies ist ein **neuer** API-Key, unabhängig vom Firewall-Bouncer!
- API-Key kopieren und sicher aufbewahren!

### 2. Beide Bouncer prüfen

```bash
# Sollte jetzt 2 Bouncer zeigen:
docker compose exec crowdsec cscli bouncers list

# Output:
# Name                IP Address    Valid  Last API Pull
# firewall-bouncer    127.0.0.1     ✓      2s ago
# traefik-bouncer     -             ✓      never (noch nicht gestartet)
```

### 3. API-Key in Traefik .env eintragen

```bash
cd docker/traefik
nano .env
```

```bash
CROWDSEC_TRAEFIK_BOUNCER_API_KEY=abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
```

### 4. Traefik starten

```bash
cd docker/traefik
docker compose up -d
```

### 5. Integration prüfen

```bash
# Traefik-Logs prüfen
docker compose logs traefik | grep -i crowdsec

# Sollte zeigen:
# "CrowdSec bouncer initialized"
# "Connected to CrowdSec LAPI"
```

```bash
# CrowdSec Bouncer-Liste prüfen
cd docker/crowdsec
docker compose exec crowdsec cscli bouncers list

# Sollte jetzt BEIDE Bouncer zeigen:
# Name                IP Address    Valid  Last API Pull
# firewall-bouncer    127.0.0.1     ✓      2s ago
# traefik-bouncer     172.x.x.x     ✓      2s ago
```

**Perfekt!** Jetzt haben Sie:
- ✅ **Firewall-Bouncer** - Blockiert auf Kernel-Ebene (nftables)
- ✅ **Traefik-Bouncer** - Blockiert auf HTTP-Ebene (Traefik)

## 🧪 Funktionstest

### Test 1: Manuelle IP blockieren

```bash
cd docker/crowdsec

# IP blockieren (z.B. 1.2.3.4)
docker compose exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 1h --reason "Test"

# Entscheidungen prüfen
docker compose exec crowdsec cscli decisions list
```

**Erwartetes Verhalten:**
- **Firewall-Bouncer**: Blockiert auf Kernel-Ebene (nftables)
  ```bash
  sudo nft list set ip crowdsec crowdsec-blacklists
  # Sollte 1.2.3.4 enthalten
  ```
- **Traefik-Bouncer**: Blockiert auf HTTP-Ebene
  - Zugriff von 1.2.3.4 zu https://ha.hajo63.de wird mit 403 Forbidden blockiert
  - Traefik-Logs zeigen: "IP 1.2.3.4 blocked by CrowdSec"

**Doppelter Schutz!** Die IP wird auf beiden Ebenen blockiert.

### Test 2: Automatisches Blocking

```bash
# Mehrere fehlgeschlagene SSH-Logins simulieren
# (auf Pi5 Host)
for i in {1..10}; do
  ssh invalid-user@localhost
done

# CrowdSec sollte die IP automatisch blockieren
docker compose exec crowdsec cscli decisions list
```

### Test 3: Traefik-spezifisches Blocking

```bash
# Viele Requests zu einem Service senden (Rate Limiting)
for i in {1..1000}; do
  curl -I https://ha.hajo63.de
done

# CrowdSec sollte die IP wegen zu vieler Requests blockieren
docker compose exec crowdsec cscli decisions list | grep "http-dos"
```

## 📊 Monitoring

### Geblockte IPs anzeigen

```bash
cd docker/crowdsec

# Alle Entscheidungen
docker compose exec crowdsec cscli decisions list

# Nur aktive Blocks
docker compose exec crowdsec cscli decisions list --type ban

# Spezifische IP prüfen
docker compose exec crowdsec cscli decisions list --ip 1.2.3.4

# Nach Grund filtern
docker compose exec crowdsec cscli decisions list --reason "http-dos"
```

### Bouncer-Status

```bash
# Alle Bouncer anzeigen
docker compose exec crowdsec cscli bouncers list

# Bouncer-Details
docker compose exec crowdsec cscli bouncers inspect traefik-bouncer
```

### Metriken

```bash
# CrowdSec-Metriken
docker compose exec crowdsec cscli metrics

# Zeigt:
# - Anzahl Entscheidungen
# - Anzahl Alerts
# - Anzahl geblockte IPs
# - Bouncer-Aktivität
```

## 🔧 Konfiguration

### CrowdSec Collections

In `docker/crowdsec/docker-compose.yml`:

```yaml
environment:
  - COLLECTIONS=crowdsecurity/linux crowdsecurity/sshd crowdsecurity/nginx crowdsecurity/traefik
```

**Wichtige Collections:**
- `crowdsecurity/traefik` - Traefik-spezifische Szenarien
- `crowdsecurity/http-cve` - HTTP-Exploits
- `crowdsecurity/http-dos` - DoS-Angriffe
- `crowdsecurity/whitelist-good-actors` - Bekannte gute Bots

### Traefik Bouncer Plugin

In `docker/traefik/config/dynamic/middlewares.yml`:

```yaml
crowdsec:
  plugin:
    crowdsec-bouncer:
      # Modus: live (Echtzeit) oder stream (periodisch)
      crowdsecMode: "live"
      
      # CrowdSec LAPI Connection
      crowdsecLapiScheme: "http"
      crowdsecLapiHost: "crowdsec:8080"
      crowdsecLapiKey: "{{env \"CROWDSEC_TRAEFIK_BOUNCER_API_KEY\"}}"
      
      # Logging
      logLevel: "INFO"
```

**Optionen:**
- `crowdsecMode: "live"` - Echtzeit-Abfrage (empfohlen)
- `crowdsecMode: "stream"` - Periodische Abfrage (weniger Last)
- `logLevel` - DEBUG, INFO, WARN, ERROR

### Traefik Logs für CrowdSec

CrowdSec muss Traefik-Logs lesen können:

In `docker/crowdsec/docker-compose.yml`:

```yaml
volumes:
  # Traefik Logs mounten
  - ../traefik/logs:/var/log/traefik:ro
```

In `docker/crowdsec/config/acquis.yaml`:

```yaml
# Traefik Access Logs
filenames:
  - /var/log/traefik/access.log
labels:
  type: traefik
```

## 🛡️ Sicherheitsempfehlungen

### 1. API-Key sicher aufbewahren

```bash
# .env sollte nicht in Git sein
echo ".env" >> .gitignore

# Berechtigungen setzen
chmod 600 .env
```

### 2. Bouncer regelmäßig prüfen

```bash
# Cronjob einrichten
crontab -e

# Täglich um 6:00 Uhr
0 6 * * * cd /home/hajo/docker/crowdsec && docker compose exec crowdsec cscli bouncers list
```

### 3. Alte Entscheidungen löschen

```bash
# Entscheidungen älter als 7 Tage löschen
docker compose exec crowdsec cscli decisions delete --all --older-than 7d
```

### 4. Whitelist für eigene IPs

```bash
# Eigene IP whitelisten
docker compose exec crowdsec cscli decisions add --ip YOUR_IP --type whitelist --duration 999999h --reason "Own IP"

# Lokales Netzwerk whitelisten
docker compose exec crowdsec cscli decisions add --range 192.168.178.0/24 --type whitelist --duration 999999h --reason "Local Network"
```

## 🐛 Troubleshooting

### Problem: Bouncer zeigt "Invalid API Key"

**Ursache:** API-Key falsch oder nicht gesetzt

**Lösung:**
```bash
# 1. API-Key neu generieren
cd docker/crowdsec
docker compose exec crowdsec cscli bouncers delete traefik-bouncer
docker compose exec crowdsec cscli bouncers add traefik-bouncer

# 2. Neuen Key in .env eintragen
cd ../traefik
nano .env

# 3. Traefik neu starten
docker compose restart traefik
```

### Problem: Bouncer zeigt "Last API Pull: never"

**Ursache:** Traefik kann CrowdSec nicht erreichen

**Lösung:**
```bash
# 1. Netzwerk prüfen
docker network inspect crowdsec-net

# 2. Traefik sollte im Netzwerk sein
docker inspect traefik | grep -A 10 Networks

# 3. Verbindung testen
docker compose exec traefik wget -O- http://crowdsec:8080/v1/decisions
```

### Problem: IPs werden nicht blockiert

**Ursache:** Middleware nicht aktiviert

**Lösung:**
```bash
# 1. Labels prüfen
docker inspect homeassistant-proxy | grep -i middleware

# Sollte enthalten:
# crowdsec@file

# 2. Middleware in docker-compose.yml hinzufügen
- "traefik.http.routers.homeassistant.middlewares=...,crowdsec@file,..."

# 3. Container neu starten
docker compose up -d
```

### Problem: Zu viele False Positives

**Ursache:** Zu aggressive Szenarien

**Lösung:**
```bash
# 1. Szenarien anzeigen
docker compose exec crowdsec cscli scenarios list

# 2. Spezifisches Szenario deaktivieren
docker compose exec crowdsec cscli scenarios remove crowdsecurity/http-dos

# 3. Oder Threshold erhöhen
# In config/scenarios/http-dos.yaml:
# capacity: 10  # Erhöhen auf z.B. 50
```

## 📚 Weitere Ressourcen

- [CrowdSec Dokumentation](https://docs.crowdsec.net/)
- [Traefik Bouncer Plugin](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin)
- [CrowdSec Hub](https://hub.crowdsec.net/) - Collections & Szenarien
- [CrowdSec Console](https://app.crowdsec.net/) - Community-Intelligence

## 🔄 Updates

### CrowdSec aktualisieren

```bash
cd docker/crowdsec
docker compose pull
docker compose up -d
```

### Bouncer Plugin aktualisieren

In `docker/traefik/config/traefik.yml`:

```yaml
experimental:
  plugins:
    crowdsec-bouncer:
      moduleName: github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin
      version: v1.3.3  # Auf neueste Version aktualisieren
```

```bash
cd docker/traefik
docker compose restart traefik
```

---

**Made with Bob** 🤖