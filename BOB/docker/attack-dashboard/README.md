# 🛡️ Attack Dashboard

Browser-Dashboard zur Echtzeit-Übersicht aller Angriffe auf den Pi5.

| Zugriff | URL |
|---------|-----|
| **LAN** | `http://192.168.178.55:8095` |
| **Extern** | `https://attack.hajo63.de` (Basic Auth erforderlich) |

---

## Was wird angezeigt?

| Quelle | Was wird erkannt |
|--------|-----------------|
| **Traefik Access Log** | HTTP-Angriffe (403/451), Direct-IP-Hits, Angriffs-Pfade, HTTP-Methoden |
| **CrowdSec LAPI** | Aktive Bans getrennt nach **lokal** (eigene Szenarien) und **CAPI** (Community-Blocklist) |
| **auth.log** | SSH Brute-Force-Versuche, angegriffene Benutzernamen |
| **GeoIP** | Herkunftsland jeder Angreifer-IP (kostenlose APIs, kein Key nötig) |

### Dashboard-Bereiche

```
┌─────────────────────────────────────────────────────────────────────┐
│  KPI-Leiste: HTTP geblockt · SSH · CrowdSec lokal · Direct-IP · Alle
│              (je 10 min / 1h / seit Start)
│              CrowdSec: 🔴 lokal aktiv (eigene Szenarien) · 🟡 CAPI
├──────────────────────────────┬──────────────────────────────────────┤
│  Weltkarte (Angriffs-Punkte) │  Live-Feed (Echtzeit-Events)         │
├──────────────┬───────────────┴──────────────────────────────────────┤
│  Top Länder  │  Top geblockte IPs  │  Top Hosts/Ziele               │
├──────────────┼─────────────────────┼────────────────────────────────┤
│  Top Pfade   │  HTTP-Methoden      │  CrowdSec-Szenarien             │
│              │  Status-Codes       │  CrowdSec-IPs                  │
├──────────────┼─────────────────────┼────────────────────────────────┤
│  SSH-IPs     │  SSH-Benutzernamen  │  Direct-IP-Hits                │
└──────────────┴─────────────────────┴────────────────────────────────┘
```

---

## Installation

### 1. CrowdSec API Key erstellen

```bash
cd /home/hajo/docker/crowdsec
docker compose exec crowdsec cscli bouncers add attack-dashboard
# → Key kopieren
```

### 2. .env anlegen

```bash
cd /home/hajo/docker/attack-dashboard
cp .env.example .env
nano .env
# CROWDSEC_KEY=<key aus Schritt 1>
```

### 3. Container starten

```bash
cd /home/hajo/docker/attack-dashboard
docker compose up -d --build

# Logs prüfen
docker compose logs -f attack-dashboard
```

### 4. Dashboard öffnen

```
http://192.168.178.55:8095
```

---

## Externer Zugriff via Traefik

Das Dashboard ist über `https://attack.hajo63.de` von außen erreichbar.

### Voraussetzungen

- DNS-Eintrag `attack.hajo63.de` bei IONOS (gleiche IP wie `ha.hajo63.de`)
- Traefik läuft und ist im selben Docker-Netzwerk (`crowdsec-net`)
- `middlewares.auth.yml` mit htpasswd-Hash in `docker/traefik/config/dynamic/`

### Basic Auth einrichten

```bash
# Hash erzeugen
htpasswd -nb hajo MeinPasswort

# In Traefik-Konfiguration eintragen (einfache Anführungszeichen!)
nano /home/hajo/docker/traefik/config/dynamic/middlewares.auth.yml
```

```yaml
http:
  middlewares:
    dashboard-auth:
      basicAuth:
        users:
          - 'hajo:$apr1$xyz123$abcdefghijklmnop'
```

### Traffic-Weg

```
Internet
    │
    ▼ HTTPS (443)
Traefik
    ├── GeoIP-Check (nur DE-IPs)
    ├── Basic Auth (dashboard-auth)
    ├── Security Headers
    │
    ▼ HTTP intern (crowdsec-net)
attack-dashboard:8095
```

### Deaktivieren (ohne DNS-Eintrag zu löschen)

Router in `docker/traefik/config/dynamic/routes.yml` auskommentieren:

```yaml
# attack-dashboard:
#   rule: "Host(`attack.hajo63.de`)"
#   ...
```

Traefik lädt die Änderung automatisch (hot-reload).

---

## Voraussetzungen

| Voraussetzung | Prüfen |
|---------------|--------|
| Traefik schreibt JSON-Log | `ls /home/hajo/docker/traefik/logs/access.json` |
| rsyslog läuft (auth.log) | `sudo systemctl status rsyslog` |
| CrowdSec LAPI erreichbar | `curl http://localhost:8080/v1/decisions` |
| crowdsec-net Netzwerk existiert | `docker network ls \| grep crowdsec` |

---

## Logrotate-Support

Das Dashboard unterstützt **automatisch rotierte Log-Dateien**. Wenn Traefik-Logs rotiert werden (z.B. wöchentlich), liest das Dashboard beim Start sowohl die aktuelle `access.json` als auch rotierte Dateien (`access.json.1`, `access.json.1.gz`, etc.), um immer vollständige 24h-Daten anzuzeigen.

### Empfohlene Logrotate-Konfiguration

```bash
sudo nano /etc/logrotate.d/traefik
```

```
/home/hajo/docker/traefik/logs/access.json {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 0644 hajo hajo
    postrotate
        # Optional: Container neu starten für FULL_SCAN mit rotierten Dateien
        # docker restart attack-dashboard
    endscript
}
```

**Erklärung:**
- `weekly` – Rotation jeden Sonntag um 00:00
- `rotate 4` – 4 Wochen Backup behalten
- `compress` – Alte Dateien mit gzip komprimieren
- `delaycompress` – Neueste rotierte Datei (.1) nicht komprimieren
- `create 0644 hajo hajo` – Neue Datei mit korrekten Rechten anlegen

### Wie es funktioniert

1. **Beim Container-Start** (FULL_SCAN=1):
   - Dashboard sucht nach `access.json.1`, `access.json.1.gz`, `access.json.2.gz`, etc.
   - Liest alle Dateien und filtert auf letzte 24h
   - Zeigt vollständige Daten auch direkt nach Rotation

2. **Im laufenden Betrieb**:
   - Dashboard folgt nur der aktuellen `access.json` (tail -f Prinzip)
   - Rotierte Dateien werden nicht mehr gelesen

3. **Nach Rotation**:
   - Optional Container neu starten für FULL_SCAN mit neuen rotierten Dateien
   - Oder warten bis nächster regulärer Neustart

### Testen

```bash
# Manuelle Rotation simulieren
sudo logrotate -f /etc/logrotate.d/traefik

# Container neu starten
cd /home/hajo/docker/attack-dashboard
docker compose restart attack-dashboard

# Logs prüfen
docker compose logs attack-dashboard | grep -i "rotierte\|FULL_SCAN"
```

Erwartete Ausgabe:
```
[attack-dashboard] Lese rotierte Datei: access.json.1
[attack-dashboard]   → 1234 Zeilen eingelesen, 567 übersprungen
[attack-dashboard] Lese aktuelle Datei: access.json
[attack-dashboard]   → 89 Zeilen eingelesen, 0 übersprungen
[attack-dashboard] FULL_SCAN abgeschlossen: 1323 Zeilen (letzte 24h) aus 2 Datei(en)
```

---

## Konfiguration (Umgebungsvariablen)

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `TRAEFIK_LOG` | `/logs/traefik/access.json` | Pfad zum Traefik Access Log |
| `AUTH_LOG` | `/logs/auth.log` | Pfad zum SSH Auth Log |
| `CROWDSEC_URL` | `http://crowdsec:8080` | CrowdSec LAPI URL |
| `CROWDSEC_KEY` | *(leer)* | API Key für CrowdSec |
| `FULL_SCAN` | `1` | Beim Start gesamtes Log einlesen |
| `SHOW_IPS` | `true` | IPs anzeigen (`false` = anonymisieren) |
| `BLOCK_STATUS` | `403,451` | HTTP-Status-Codes als "geblockt" werten |
| `PORT` | `8095` | Dashboard-Port |
| `GEO_TIMEOUT` | `3` | Timeout für GeoIP-Anfragen (Sekunden) |

---

## Architektur

```
Pi5 Host
├── /var/log/auth.log          ──► attack-dashboard (SSH-Monitoring)
├── /home/hajo/docker/traefik/
│   └── logs/access.json       ──► attack-dashboard (HTTP-Monitoring)
│
Docker (crowdsec-net)
├── traefik              ──► attack-dashboard:8095 (Reverse Proxy)
├── crowdsec:8080        ──► attack-dashboard (CrowdSec-Polling)
└── attack-dashboard:8095
        ├── Browser LAN:    http://192.168.178.55:8095
        └── Browser extern: https://attack.hajo63.de (via Traefik)
```

### Datenfluss

1. **Traefik** schreibt jeden Request als JSON in `access.json`
2. **attack-dashboard** liest die Datei kontinuierlich (tail -f Prinzip)
3. Für jeden geblockten Request (403/451) wird die IP per **GeoIP** aufgelöst
4. **CrowdSec LAPI** wird alle 30s nach neuen Bans gefragt
5. **auth.log** wird auf SSH-Fehlversuche überwacht
6. Das **Browser-Dashboard** pollt `/api/stats` alle 5 Sekunden

---

## Firewall

Port 8095 ist in `nftables-pi5-fixed.conf` in `local_management_ports` eingetragen:
- ✅ Erreichbar aus LAN (192.168.178.0/24)
- ✅ Erreichbar von außen via `https://attack.hajo63.de` (Traefik + Basic Auth)
- ❌ Direkter externer Zugriff auf Port 8095 blockiert (nftables)

---

## Troubleshooting

### Keine HTTP-Daten

```bash
# Traefik-Log prüfen
ls -la /home/hajo/docker/traefik/logs/access.json
tail -5 /home/hajo/docker/traefik/logs/access.json

# Container-Logs
docker compose logs attack-dashboard | grep -i traefik
```

### Keine CrowdSec-Daten

```bash
# API Key prüfen
docker compose exec crowdsec cscli bouncers list

# Verbindung testen (nur /v1/decisions – Bouncer-Keys haben keinen Zugriff auf /v1/alerts)
docker compose exec attack-dashboard \
  python3 -c "import urllib.request; print(urllib.request.urlopen('http://crowdsec:8080/v1/decisions').read())"

# Debug-Endpoint (zeigt Rohdaten + Fehler)
curl -s http://localhost:8095/api/debug/crowdsec | python3 -m json.tool
```

### CrowdSec zeigt überall 500 (oder andere hohe Zahl)

Das ist **normal beim ersten Start**: Da Bouncer-Keys keinen Zugriff auf `/v1/alerts` haben,
kennen wir keine historischen Timestamps. Beim Start werden alle aktuell aktiven lokalen
Decisions einmalig mit `ts=now` gestempelt.

**KPI-Bedeutung:**
- **🔴 lokal aktiv** = aktuell aktive Bans durch eigene CrowdSec-Szenarien (z.B. CVE-Erkennung)
- **🟡 CAPI** = Community-Blocklist-Einträge (vorgefertigte Listen, keine eigenen Erkennungen)
- **seit Start** = lokale Neuzugänge seit letztem Container-Start (10m/1h/gesamt)

### Keine SSH-Daten

```bash
# rsyslog prüfen
sudo systemctl status rsyslog
tail -5 /var/log/auth.log

# auth.log im Container prüfen
docker compose exec attack-dashboard tail -5 /logs/auth.log
```

### GeoIP schlägt fehl

Die GeoIP-Auflösung nutzt eine Fallback-Kette aus 4 kostenlosen APIs.
Bei Rate-Limiting wird automatisch zur nächsten API gewechselt.
Fehler werden im Dashboard unter "Config" angezeigt.

### Externer Zugriff funktioniert nicht (401)

```bash
# Hash in middlewares.auth.yml prüfen (einfache Anführungszeichen!)
cat /home/hajo/docker/traefik/config/dynamic/middlewares.auth.yml

# Traefik-Logs prüfen
cd /home/hajo/docker/traefik
docker compose logs traefik | grep -i "attack\|auth\|error"
```

### Externer Zugriff funktioniert nicht (Middleware nicht gefunden)

```bash
# middlewares.auth.yml existiert?
ls -la /home/hajo/docker/traefik/config/dynamic/

# Traefik neu starten (falls Datei neu angelegt wurde)
cd /home/hajo/docker/traefik
docker compose restart traefik
```

---

## Vergleich mit geoblock-monitor-live-v15

| Feature | geoblock-monitor-v15 | attack-dashboard |
|---------|---------------------|-----------------|
| HTTP-Angriffe | ✅ | ✅ |
| Direct-IP-Hits | ✅ | ✅ |
| CrowdSec-Events | ✅ (via Docker-Socket) | ✅ (via LAPI REST) |
| SSH-Angriffe | ❌ | ✅ |
| Weltkarte | ❌ | ✅ (Canvas) |
| Live-Feed | ❌ | ✅ |
| Angriffs-Pfade | ❌ | ✅ |
| HTTP-Methoden | ❌ | ✅ |
| CrowdSec-Szenarien | ❌ | ✅ |
| Docker-Socket nötig | ✅ | ❌ |
| Externer Zugriff | ❌ | ✅ (via Traefik + Basic Auth) |

---

## What's Up Docker (WUD)

Der Container ist mit `wud.watch=true` konfiguriert und erscheint in der WUD-UI.
Da es ein **lokaler Build** ist (kein Registry-Image), kann WUD keine Updates prüfen –
der Container wird mit Status "unknown" angezeigt. Das ist korrekt und erwartet.

---

*Made with Bob* 🤖