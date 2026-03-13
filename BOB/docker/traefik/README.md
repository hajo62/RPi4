# Traefik Reverse Proxy

Traefik v3.6 als zentraler Reverse-Proxy für alle Services auf Pi4 mit CrowdSec-Integration und GeoIP-Blocking.

## 📋 Features

- ✅ **Hybrid-Konfiguration**: Labels + File Provider für Middlewares
- ✅ **CrowdSec-Integration**: Automatisches Blocking böser IPs
- ✅ **GeoIP-Blocking**: Nur Deutschland erlaubt
- ✅ **Let's Encrypt**: Automatische SSL-Zertifikate
- ✅ **Security Headers**: HSTS, CSP, etc.
- ✅ **Rate Limiting**: Schutz vor DDoS
- ✅ **Basic Auth**: Zugriffsschutz für das Attack Dashboard
- ✅ **WUD-Integration**: Update-Überwachung

## 🏗️ Architektur

```
Internet
    ↓
Traefik (Pi5:443) ← CrowdSec (Blocking)
    ↓               ← GeoIP (nur DE)
    ├── Pi4 Services (via Nginx):
    │       - Home Assistant (ha.hajo63.de)
    │       - Nextcloud (nc.hajo63.de)
    │       - Pigallery2 (pg.hajo63.de)
    │
    └── Pi5 Services (direkt):
            - Attack Dashboard (attack.hajo63.de, Basic Auth)
```

## 📁 Verzeichnisstruktur

```
docker/traefik/
├── docker-compose.yml              # Traefik Container
├── .env                            # Umgebungsvariablen (nicht in Git!)
├── .env.example                    # Template
├── .gitignore
│
├── config/
│   ├── traefik.yml                 # Hauptkonfiguration
│   └── dynamic/
│       ├── routes.yml              # Routers & Services
│       ├── middlewares.yml         # Wiederverwendbare Middlewares
│       ├── middlewares.auth.yml    # Basic Auth Hashes (nicht in Git!)
│       └── tls.yml                 # TLS-Optionen
│
├── certs/                          # SSL-Zertifikate (Ionos, nicht in Git!)
│   ├── hajo63.de/
│   │   ├── fullchain.pem
│   │   └── privkey.pem
│   └── hajo62.duckdns.org/
│       ├── fullchain.pem
│       └── privkey.pem
│
├── logs/                           # Logs (automatisch, nicht in Git!)
│   ├── traefik.log
│   └── access.json
│
└── README.md                       # Diese Datei
```

## 🚀 Installation

### 1. Voraussetzungen

- Docker & Docker Compose installiert
- CrowdSec läuft bereits (`docker/crowdsec/`)
- Ports 80 und 443 sind frei

### 2. Umgebungsvariablen konfigurieren

```bash
cd docker/traefik
cp .env.example .env
nano .env
```

### 3. Basic Auth für Attack Dashboard einrichten

```bash
# Hash erzeugen
htpasswd -nb hajo MeinPasswort

# middlewares.auth.yml anlegen (nicht in Git!)
nano config/dynamic/middlewares.auth.yml
```

Inhalt (einfache Anführungszeichen verwenden – kein `$$` nötig in YAML!):

```yaml
http:
  middlewares:
    dashboard-auth:
      basicAuth:
        users:
          - 'hajo:$apr1$xyz123$abcdefghijklmnop'
```

### 4. SSL-Zertifikate vorbereiten

Traefik benötigt die Zertifikate im `.pem`-Format. Let's Encrypt liefert die Dateien als `.cer` und `.key`.

#### Für hajo63.de (Ionos):

```bash
mkdir -p certs/hajo63.de

# Zertifikate von Ionos herunterladen und umbenennen
# fullchain.cer → fullchain.pem
# hajo63.de.key → privkey.pem

cp /pfad/zu/ionos/fullchain.cer certs/hajo63.de/fullchain.pem
cp /pfad/zu/ionos/hajo63.de.key certs/hajo63.de/privkey.pem

# Berechtigungen setzen
chmod 600 certs/hajo63.de/privkey.pem
chmod 644 certs/hajo63.de/fullchain.pem
```

#### Für hajo62.duckdns.org (DuckDNS):

```bash
mkdir -p certs/hajo62.duckdns.org

# Zertifikate von Let's Encrypt umbenennen
# fullchain.cer → fullchain.pem
# hajo62.duckdns.org.key → privkey.pem

cp /pfad/zu/letsencrypt/fullchain.cer certs/hajo62.duckdns.org/fullchain.pem
cp /pfad/zu/letsencrypt/hajo62.duckdns.org.key certs/hajo62.duckdns.org/privkey.pem

# Berechtigungen setzen
chmod 600 certs/hajo62.duckdns.org/privkey.pem
chmod 644 certs/hajo62.duckdns.org/fullchain.pem
```

**Hinweis:** Die `.cer`-Dateien sind bereits im PEM-Format – nur die Dateiendung muss geändert werden. Kein Konvertieren nötig!

**Zertifikate prüfen:**

```bash
# Gültigkeit prüfen
openssl x509 -in certs/hajo63.de/fullchain.pem -noout -dates
openssl x509 -in certs/hajo62.duckdns.org/fullchain.pem -noout -dates

# Domain im Zertifikat prüfen
openssl x509 -in certs/hajo63.de/fullchain.pem -noout -subject -ext subjectAltName
```

### 4. Verzeichnisse erstellen

```bash
mkdir -p logs
```

### 5. Starten

```bash
docker compose up -d
```

### 6. Logs prüfen

```bash
docker compose logs -f traefik
```

## 🔧 Konfiguration

### Neue Services hinzufügen

Neuen Router und Service in `config/dynamic/routes.yml` eintragen:

```yaml
# Router
mein-service:
  rule: "Host(`mein.hajo63.de`)"
  entryPoints:
    - websecure
  service: mein-service
  middlewares:
    - geoblock-de@file
    - secure-headers@file
  tls:
    options: tls-modern

# Service
mein-service:
  loadBalancer:
    servers:
      - url: "http://192.168.178.3:PORT"
```

### Middlewares anpassen

Zentrale Middlewares in `config/dynamic/middlewares.yml` bearbeiten:

```yaml
# Beispiel: Weitere Länder erlauben
geoblock-de:
  plugin:
    geoblock:
      countries:
        - DE
        - AT  # Österreich hinzufügen
        - CH  # Schweiz hinzufügen
```

Traefik lädt Dynamic-Config-Änderungen **automatisch** (hot-reload) – kein Neustart nötig.

## 🔍 Monitoring

### Traefik Dashboard (intern)

- URL: `http://192.168.178.55:8092`
- Nur im LAN erreichbar (nftables blockiert externen Zugriff)
- Kein Passwort nötig

### Attack Dashboard (extern)

- URL: `https://attack.hajo63.de`
- Basic Auth erforderlich (Hash in `config/dynamic/middlewares.auth.yml`)
- GeoIP: nur DE-IPs
- Zeigt HTTP-Angriffe, CrowdSec-Bans, SSH-Brute-Force, Weltkarte

**Port-Übersicht Pi5 (192.168.178.55):**

| Port | Dienst |
|------|--------|
| 80 | Traefik HTTP |
| 443 | Traefik HTTPS |
| 3000 | WUD (What's Up Docker) |
| 8080 | CrowdSec LAPI |
| 8090 | signal-cli-rest-api |
| 8091 | wud-webhook |
| 8092 | **Traefik Dashboard** (LAN only) |
| 8095 | **Attack Dashboard** (LAN + extern via attack.hajo63.de) |
| 8180 | this-week-in-past |

**Externe Domains:**

| Domain | Service | Schutz |
|--------|---------|--------|
| `ha.hajo63.de` | Home Assistant (Pi4) | GeoIP (DE), Rate Limit |
| `nc.hajo63.de` | Nextcloud (Pi4) | GeoIP (DE), Rate Limit |
| `pg.hajo63.de` | Pigallery2 (Pi4) | GeoIP (DE), Rate Limit |
| `attack.hajo63.de` | Attack Dashboard (Pi5) | GeoIP (DE), Basic Auth |

### Logs

```bash
# Live-Logs
docker compose logs -f traefik

# Access-Logs (JSON)
tail -f logs/access.json | jq

# Error-Logs
tail -f logs/traefik.log
```

### CrowdSec-Entscheidungen

```bash
# Geblockte IPs anzeigen
cd ../crowdsec
docker compose exec crowdsec cscli decisions list

# Spezifische IP prüfen
docker compose exec crowdsec cscli decisions list --ip 1.2.3.4
```

## 🛡️ Sicherheit

### Aktive Schutzmaßnahmen

1. **CrowdSec Bouncer (nftables)**: Blockiert bekannte böse IPs VOR Traefik
2. **Rate Limiting**: Max 100 Requests/Sekunde (erste Middleware in Traefik)
3. **GeoIP**: Nur Deutschland erlaubt
4. **Basic Auth**: Zugriffsschutz für das Attack Dashboard
5. **Security Headers**: HSTS, CSP, X-Frame-Options, etc.
6. **HTTPS-Only**: HTTP → HTTPS Redirect
7. **TLS 1.3**: Moderne Verschlüsselung mit starken Cipher Suites

### Middleware-Reihenfolge (wichtig!)

Die Reihenfolge der Middlewares ist bewusst gewählt:

```yaml
# Standard-Services (ha, nc, pg):
middlewares:
  - rate-limit-standard@file  # 1. Rate Limit
  - geoblock-de@file          # 2. GeoIP
  - secure-headers@file       # 3. Security Headers

# Attack Dashboard:
middlewares:
  - geoblock-de@file          # 1. GeoIP
  - dashboard-auth@file       # 2. Basic Auth
  - secure-headers@file       # 3. Security Headers
```

#### **Warum diese Reihenfolge?**

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────┐
│  0. nftables (Host)                                 │
│     └─ CrowdSec Bouncer: bekannte böse IPs → DROP   │ ← VOR Traefik
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────┐
│  Traefik Middlewares (in dieser Reihenfolge):        │
│                                                     │
│  1. rate-limit-standard                             │
│     └─ Max 100 req/s → verhindert DoS               │
│     └─ Schützt GeoIP-API vor Überlastung            │
│                                                     │
│  2. geoblock-de                                     │
│     └─ Nicht-DE-IPs → 403                           │
│     └─ Läuft nur für IPs, die Rate Limit bestehen   │
│                                                     │
│  3. secure-headers                                  │
│     └─ HSTS, CSP, etc. setzen                       │
│     └─ Läuft nur für DE-IPs                         │
└─────────────────────────────────────────────────────┘
```

#### **Zusammenspiel CrowdSec + GeoIP:**

| Situation | Was passiert |
|-----------|-------------|
| **Bekannte böse IP** | nftables verwirft Paket (CrowdSec Bouncer) |
| **Unbekannte US-IP** | Rate Limit → GeoIP 403 → CrowdSec lernt aus Log |
| **US-IP mit bösem User-Agent** | GeoIP 403 + CrowdSec erkennt User-Agent → Ban |
| **DE-IP greift an** | Rate Limit → GeoIP lässt durch → CrowdSec erkennt Muster → Ban |
| **Beim nächsten Angriff** | nftables verwirft Paket (CrowdSec hat gelernt) |

**Wichtig:** CrowdSec liest die Traefik Access Logs und erkennt Angriffsmuster auch aus 403-Responses (z.B. böse User-Agents). Geblockte IPs werden in nftables eingetragen und beim nächsten Versuch bereits VOR Traefik verworfen.

### Basic Auth – Attack Dashboard

Der htpasswd-Hash wird in `config/dynamic/middlewares.auth.yml` gespeichert (nicht in Git):

```bash
# Hash erzeugen
htpasswd -nb hajo MeinPasswort

# Wichtig: einfache Anführungszeichen in YAML (kein $$ nötig!)
# 'hajo:$apr1$xyz123$abcdefghijklmnop'
```

**Hinweis:** Traefik ersetzt keine Umgebungsvariablen in Dynamic-Config-Dateien.
Der Hash muss direkt in `middlewares.auth.yml` eingetragen werden.

### Security Headers im Detail

Die `secure-headers` Middleware in `config/dynamic/middlewares.yml` setzt folgende Header:

#### **HSTS (HTTP Strict Transport Security)**
```yaml
stsSeconds: 63072000          # 2 Jahre
stsIncludeSubdomains: true    # Gilt auch für Subdomains
stsPreload: true              # Für HSTS Preload List
```
- ✅ Erzwingt HTTPS für 2 Jahre
- ✅ Verhindert SSL-Stripping-Angriffe
- ✅ SSL Labs A+ Rating

#### **CSP (Content Security Policy)**
```yaml
contentSecurityPolicy: "default-src 'none'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; ..."
```

**Konfiguration:**
- `default-src 'none'` - Deny by Default (Best Practice)
- `script-src 'self' 'unsafe-inline' 'unsafe-eval'` - JavaScript von eigener Domain + Inline-Scripts
- `style-src 'self' 'unsafe-inline'` - CSS von eigener Domain + Inline-Styles
- `img-src 'self' data: https:` - Bilder von eigener Domain, Data-URLs, HTTPS
- `font-src 'self' data:` - Schriftarten von eigener Domain, Data-URLs
- `connect-src 'self'` - AJAX/WebSocket nur zu eigener Domain
- `media-src 'self'` - Audio/Video von eigener Domain
- `worker-src 'self'` - Web Workers von eigener Domain
- `child-src 'self'` - iframes von eigener Domain
- `object-src 'none'` - Flash/Java/ActiveX blockiert
- `frame-ancestors 'self'` - Clickjacking-Schutz
- `base-uri 'self'` - Base-Tag-Injection-Schutz
- `form-action 'self'` - Form-Hijacking-Schutz
- `manifest-src 'self'` - PWA Manifests von eigener Domain

**Warum `unsafe-inline` und `unsafe-eval`?**
- ✅ Home Assistant benötigt Inline-Scripts
- ✅ Nextcloud benötigt Inline-Scripts
- ✅ Moderne Web-Apps nutzen dynamischen Code
- ⚠️ Mozilla Observatory zeigt Warnung (akzeptabel)

**Schutz trotzdem vorhanden:**
- ✅ Flash/Java/ActiveX blockiert (`object-src 'none'`)
- ✅ Clickjacking verhindert (`frame-ancestors 'self'`)
- ✅ Externe Ressourcen beschränkt
- ✅ Mehrschichtige Sicherheit (CrowdSec, GeoIP, Rate Limiting)

#### **Weitere Security Headers**
```yaml
frameDeny: true                              # X-Frame-Options: DENY
contentTypeNosniff: true                     # X-Content-Type-Options: nosniff
browserXssFilter: true                       # X-XSS-Protection: 1; mode=block
referrerPolicy: strict-origin-when-cross-origin
```

#### **Permissions-Policy**
```yaml
permissionsPolicy: "geolocation=(), microphone=(), camera=(), ..."
```
Deaktiviert Browser-Features:
- ❌ Geolocation
- ❌ Microphone
- ❌ Camera
- ❌ Payment API
- ❌ USB
- ❌ Magnetometer
- ❌ Gyroscope
- ❌ Accelerometer

### TLS-Konfiguration

In `config/dynamic/tls.yml`:

```yaml
tls:
  options:
    default:
      minVersion: VersionTLS12
      maxVersion: VersionTLS13
      curvePreferences:
        - X25519        # Moderne Elliptic Curve
        - CurveP521
        - CurveP384
      cipherSuites:
        # TLS 1.3 (automatisch)
        # TLS 1.2 Cipher Suites (AES-256 priorisiert)
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
```

**SSL Labs Ergebnis:**
- ✅ **A+ Rating**
- ✅ 100% Key Exchange (X25519)
- ✅ 100% Cipher Strength (AES-256)
- ✅ TLS 1.3 Support
- ✅ HSTS mit Preload

### Security Testing

#### **SSL Labs Test**
```bash
# Online testen
https://www.ssllabs.com/ssltest/analyze.html?d=ha.hajo63.de
```

#### **Mozilla Observatory**
```bash
https://observatory.mozilla.org/analyze/ha.hajo63.de
```

#### **Security Headers Check**
```bash
curl -I https://ha.hajo63.de
```

### Firewall-Regeln (nftables)

```bash
# Auf Pi5: Nur Ports 80 und 443 von außen
sudo nft list ruleset | grep -A 5 "input"
```

## 🔄 Wartung

### Updates

```bash
# Traefik-Image aktualisieren
docker compose pull
docker compose up -d

# Oder mit Watchtower (automatisch)
```

### Logs rotieren

Logs werden automatisch rotiert (siehe `docker-compose.yml`):
- Max 10MB pro Datei
- Max 5 Dateien

### Backup

```bash
# Wichtige Dateien sichern
tar -czf traefik-backup-$(date +%Y%m%d).tar.gz \
  .env \
  config/ \
  certs/

# Backup auf NAS kopieren
scp traefik-backup-*.tar.gz user@nas:/backups/
```

## 🐛 Troubleshooting

### Problem: Traefik startet nicht

```bash
# Logs prüfen
docker compose logs traefik

# Häufige Ursachen:
# - .env nicht konfiguriert
# - CrowdSec nicht erreichbar
# - Ports 80/443 bereits belegt
# - middlewares.auth.yml fehlt oder hat YAML-Fehler
```

### Problem: dashboard-auth Middleware nicht gefunden

```bash
# Prüfen ob middlewares.auth.yml existiert
ls -la config/dynamic/middlewares.auth.yml

# YAML-Syntax prüfen ($ in einfachen Quotes!)
cat config/dynamic/middlewares.auth.yml

# Traefik-Logs
docker compose logs traefik | grep -i "auth\|middleware"
```

### Problem: Basic Auth – 401 trotz richtigem Passwort

```bash
# Hash neu erzeugen und prüfen
htpasswd -nb hajo MeinPasswort

# Wichtig: In middlewares.auth.yml einfache Anführungszeichen verwenden!
# Falsch:  - "hajo:$apr1$..."   ← doppelte Quotes → $ wird interpretiert
# Richtig: - 'hajo:$apr1$...'   ← einfache Quotes → $ bleibt literal
```

### Problem: SSL-Zertifikat wird nicht geladen

```bash
# Zertifikate prüfen
ls -la certs/hajo63.de/
openssl x509 -in certs/hajo63.de/fullchain.pem -noout -dates
```

### Problem: Service nicht erreichbar

```bash
# 1. Traefik-Dashboard prüfen
http://192.168.178.55:8092

# 2. Routers in der API prüfen
curl -s http://localhost:8092/api/http/routers | python3 -m json.tool | grep "name\|status"

# 3. Netzwerk prüfen
docker network ls | grep crowdsec
docker network inspect crowdsec-net
```

### Problem: CrowdSec blockiert nicht

```bash
# 1. CrowdSec-Verbindung prüfen
docker compose logs traefik | grep -i crowdsec

# 2. CrowdSec-Entscheidungen prüfen
cd ../crowdsec
docker compose exec crowdsec cscli decisions list

# 3. Bouncer-Status prüfen
docker compose exec crowdsec cscli bouncers list
```

### Problem: GeoIP blockiert lokale Requests

```bash
# In config/dynamic/middlewares.yml:
geoblock-de:
  plugin:
    geoblock:
      allowLocalRequests: true  # Muss true sein!
```

## 📚 Weitere Ressourcen

- [Traefik Dokumentation](https://doc.traefik.io/traefik/)
- [CrowdSec Bouncer Plugin](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin)
- [GeoBlock Plugin](https://github.com/PascalMinder/geoblock)
- [htpasswd Generator](https://hostingcanada.org/htpasswd-generator/)

## 📝 Changelog

### 2026-03-01 – Attack Dashboard extern erreichbar
- Neuer Router `attack-dashboard` → `https://attack.hajo63.de`
- Neue Middleware `dashboard-auth` (Basic Auth) in `middlewares.auth.yml`
- `middlewares.auth.yml` in `.gitignore` (enthält htpasswd-Hash)
- DNS-Eintrag `attack.hajo63.de` bei IONOS (gleiche IP wie `ha.hajo63.de`)

### 2026-02-25 – Initial Release
- Traefik v3.6 Setup
- CrowdSec-Integration
- GeoIP-Blocking (nur DE)
- File Provider Konfiguration (routes.yml + middlewares.yml)
- 3 Services: Home Assistant, Nextcloud, Pigallery2

---

**Made with Bob** 🤖