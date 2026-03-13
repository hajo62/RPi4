# Ordner- und Ablagestruktur für Raspberry Pi 5 (Traefik-Server)

## 📊 Hardware-Übersicht

- **System-SSD**: 250 GB (Root `/`)
- **Daten-SSD**: 950 GB (Mount `/home`)
- **RAM**: 16 GB
- **Hauptaufgabe**: Traefik Reverse-Proxy mit CrowdSec & GeoIP

---

## 🎯 Aufteilungsprinzip: System vs. Daten

### System-SSD (250 GB) - Betriebssystem & Docker
**Verwendung für:**
- ✅ Betriebssystem (RaspberryOS)
- ✅ Docker-Images & Container-Layer
- ✅ Temporäre Dateien
- ✅ Systemlogs (mit Rotation)

**Begründung:**
- Schneller Zugriff für OS und Docker-Engine
- Weniger kritisch bei Ausfall (neu installierbar)
- Geringere Schreiblast durch Log-Rotation

### Daten-SSD (950 GB) - Alle persistenten Daten
**Verwendung für:**
- ✅ **Traefik-Konfiguration** (docker-compose.yml, .env, config/)
- ✅ Docker-Volumes (persistente Daten)
- ✅ SSL-Zertifikate (Let's Encrypt)
- ✅ Anwendungslogs (langfristig)
- ✅ CrowdSec-Datenbank
- ✅ GeoIP-Datenbanken
- ✅ Backups
- ✅ Traefik Access-Logs

**Begründung:**
- **Alles an einem Ort**: Einfacher zu verwalten und zu sichern
- Daten überleben System-Neuinstallation
- Mehr Platz für wachsende Logs (950GB)
- Einfacheres Backup (nur `/home/hajo/docker-volumes/` sichern)

---

## 📁 Detaillierte Ordnerstruktur

### System-SSD (`/` - 250 GB)

```
/etc/
├── nftables.conf                         # Firewall-Konfiguration
└── systemd/system/
    └── traefik-backup.timer              # Automatisches Backup

/var/log/
└── traefik/                              # Symlink zu /home/hajo/docker-volumes/traefik/logs/
```

### Daten-SSD (`/home` - 950 GB)

```
/home/hajo/
└── docker-volumes/                       # Alle persistenten Docker-Daten
    │
    ├── traefik/                          # Traefik Hauptverzeichnis
    │   ├── docker-compose.yml            # Traefik + CrowdSec Stack
    │   ├── .env                          # Umgebungsvariablen (Secrets!)
    │   │
    │   ├── config/                       # Traefik-Konfiguration
    │   │   ├── traefik.yml               # Hauptkonfiguration
    │   │   └── dynamic/                  # Dynamische Konfiguration (File Provider)
    │   │       ├── middlewares.yml       # Rate-Limiting, Headers, GeoIP
    │   │       ├── routers.yml           # Routen-Definitionen
    │   │       └── services.yml          # Backend-Service-Definitionen
    │   │
    │   ├── letsencrypt/                  # SSL-Zertifikate
    │   │   ├── acme.json                 # Let's Encrypt Account (600 Permissions!)
    │   │   └── certs/                    # Generierte Zertifikate
    │   │       ├── hajo63.de/
    │   │       └── *.hajo63.de/          # Wildcard-Zertifikate
    │   │
    │   ├── logs/                         # Langfristige Logs
    │   │   ├── access.log                # Access-Logs (groß!)
    │   │   ├── access.log.1.gz           # Rotierte Logs
    │   │   ├── access.log.2.gz
    │   │   ├── error.log                 # Error-Logs
    │   │   └── traefik.log               # Traefik-interne Logs
    │   │
    │   ├── scripts/                      # Wartungsskripte
    │   │   ├── backup.sh                 # Backup-Skript
    │   │   ├── update-geoip.sh           # GeoIP-Update (Cronjob)
    │   │   └── health-check.sh           # Monitoring-Skript
    │   │
    │   └── config-backup/                # Automatische Config-Backups
    │       ├── 2026-02-18/
    │       └── 2026-02-17/
    │
    ├── crowdsec/                         # CrowdSec Daten
    │   ├── config/                       # CrowdSec-Konfiguration
    │   │   ├── acquis.yaml               # Log-Quellen
    │   │   ├── profiles.yaml             # Entscheidungsprofile
    │   │   └── local_api_credentials.yaml
    │   │
    │   ├── data/                         # CrowdSec-Datenbank
    │   │   └── crowdsec.db               # SQLite-Datenbank
    │   │
    │   └── hub/                          # Collections & Scenarios
    │       ├── collections/
    │       ├── parsers/
    │       └── scenarios/
    │
    ├── geoip/                            # GeoIP-Datenbanken
    │   ├── GeoLite2-Country.mmdb
    │   ├── GeoLite2-City.mmdb
    │   └── .last-update                  # Timestamp für Update-Check
    │
    └── backups/                          # Backup-Verzeichnis
        ├── traefik/
        │   ├── weekly/
        │   └── monthly/
        ├── crowdsec/
        └── certificates/
```

---

## 🔀 Konfigurationsvarianten: Labels vs. File Provider

### Variante A: Docker-Labels (Empfohlen für Ihr Setup)

#### ✅ Vorteile
- **Einfacher Einstieg**: Alles in einer `docker-compose.yml`
- **Übersichtlich**: Service-Definition und Routing zusammen
- **Weniger Dateien**: Keine separaten YAML-Dateien nötig
- **Dynamisch**: Änderungen durch Container-Neustart aktiv
- **Gut für Remote-Services**: Perfekt für Pi4-Services (externe IPs)

#### ❌ Nachteile
- **Weniger flexibel**: Komplexe Middlewares schwieriger
- **Keine Versionierung**: Änderungen nicht in Git trackbar (außer compose-Datei)
- **Begrenzte Wiederverwendung**: Middlewares müssen pro Service definiert werden

#### 📂 Ordnerstruktur (Labels-Variante)

```
/home/hajo/docker-volumes/traefik/
├── docker-compose.yml          # Enthält ALLE Konfiguration
├── .env                        # Secrets
└── config/
    └── traefik.yml             # Nur Basis-Config (Entrypoints, Providers)
```

#### 📝 Beispiel: docker-compose.yml (Labels)

```yaml
services:
  traefik:
    image: traefik:v3.6
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /home/hajo/docker-volumes/traefik/config/traefik.yml:/etc/traefik/traefik.yml:ro
      - /home/hajo/docker-volumes/traefik/letsencrypt:/letsencrypt
      - /home/hajo/docker-volumes/traefik/logs:/logs
    labels:
      # Dashboard aktivieren
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.hajo63.de`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      
      # Dashboard Auth
      - "traefik.http.routers.dashboard.middlewares=dashboard-auth"
      - "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$apr1$$..."
    networks:
      - traefik-public

  # Beispiel: Home Assistant auf Pi4 (192.168.178.3:8123)
  homeassistant-proxy:
    image: alpine:latest
    container_name: homeassistant-proxy
    command: tail -f /dev/null  # Dummy-Container für Labels
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.homeassistant.rule=Host(`ha.hajo63.de`)"
      - "traefik.http.routers.homeassistant.entrypoints=websecure"
      - "traefik.http.routers.homeassistant.tls.certresolver=letsencrypt"
      
      # Backend auf Pi4
      - "traefik.http.services.homeassistant.loadbalancer.server.url=http://192.168.178.3:8123"
      
      # Middlewares
      - "traefik.http.routers.homeassistant.middlewares=ha-headers,geoip-de,rate-limit"
      - "traefik.http.middlewares.ha-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
      - "traefik.http.middlewares.geoip-de.plugin.geoblock.allowedCountries=DE"
      - "traefik.http.middlewares.rate-limit.ratelimit.average=100"
    networks:
      - traefik-public

networks:
  traefik-public:
    name: traefik-public
    driver: bridge
```

---

### Variante B: File Provider (Flexibler, mehr Dateien)

#### ✅ Vorteile
- **Sehr flexibel**: Komplexe Routing-Regeln möglich
- **Wiederverwendbar**: Middlewares zentral definiert
- **Versionierbar**: Alle Configs in Git
- **Übersichtlich**: Trennung von Concerns (Routers, Services, Middlewares)
- **Hot-Reload**: Änderungen ohne Container-Neustart

#### ❌ Nachteile
- **Mehr Dateien**: Mehrere YAML-Dateien zu pflegen
- **Komplexer**: Höhere Lernkurve
- **Fehleranfälliger**: Syntax-Fehler in mehreren Dateien möglich

#### 📂 Ordnerstruktur (File Provider)

```
/home/hajo/docker-volumes/traefik/
├── docker-compose.yml          # Nur Container-Definitionen
├── .env
└── config/
    ├── traefik.yml             # Hauptkonfiguration
    └── dynamic/                # Dynamische Konfiguration
        ├── middlewares.yml     # Zentrale Middleware-Definitionen
        ├── routers.yml         # Alle Routen
        └── services.yml        # Backend-Services
```

#### 📝 Beispiel: config/dynamic/middlewares.yml

```yaml
http:
  middlewares:
    # Security Headers
    secure-headers:
      headers:
        sslRedirect: true
        forceSTSHeader: true
        stsSeconds: 31536000
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "same-origin"
    
    # GeoIP Deutschland
    geoip-de:
      plugin:
        geoblock:
          allowedCountries:
            - DE
          defaultAllow: false
    
    # Rate Limiting
    rate-limit-standard:
      rateLimit:
        average: 100
        burst: 50
        period: 1s
    
    # Home Assistant spezifisch
    ha-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
```

#### 📝 Beispiel: config/dynamic/routers.yml

```yaml
http:
  routers:
    # Home Assistant
    homeassistant:
      rule: "Host(`ha.hajo63.de`)"
      entryPoints:
        - websecure
      service: homeassistant-backend
      middlewares:
        - secure-headers
        - ha-headers
        - geoip-de
        - rate-limit-standard
      tls:
        certResolver: letsencrypt
    
    # Nextcloud
    nextcloud:
      rule: "Host(`nc.hajo63.de`)"
      entryPoints:
        - websecure
      service: nextcloud-backend
      middlewares:
        - secure-headers
        - rate-limit-standard
      tls:
        certResolver: letsencrypt
```

#### 📝 Beispiel: config/dynamic/services.yml

```yaml
http:
  services:
    # Home Assistant auf Pi4
    homeassistant-backend:
      loadBalancer:
        servers:
          - url: "http://192.168.178.3:8123"
        healthCheck:
          path: /
          interval: 30s
          timeout: 5s
    
    # Nextcloud auf Pi4
    nextcloud-backend:
      loadBalancer:
        servers:
          - url: "http://192.168.178.3:8088"
        healthCheck:
          path: /status.php
          interval: 30s
          timeout: 5s
```

---

## 🎯 Empfehlung für Ihr Setup

### **Hybrid-Ansatz** (Beste Balance)

**Basis-Konfiguration**: File Provider für wiederverwendbare Middlewares
**Service-Routing**: Docker-Labels für einfache Verwaltung

#### Warum Hybrid?

1. **Zentrale Middlewares** (File Provider):
   - Security Headers (für alle Services gleich)
   - GeoIP-Regeln (einmal definieren)
   - Rate-Limiting-Profile (Standard, Streng, Locker)

2. **Service-spezifisches Routing** (Labels):
   - Einfaches Hinzufügen neuer Services
   - Klare Zuordnung Service ↔ Route
   - Weniger Dateien zu pflegen

#### 📂 Hybrid-Ordnerstruktur

```
/home/hajo/docker-volumes/traefik/
├── docker-compose.yml          # Services mit Labels
├── .env
└── config/
    ├── traefik.yml             # Hauptkonfiguration
    └── dynamic/
        └── middlewares.yml     # Nur wiederverwendbare Middlewares
```

#### 📝 Beispiel: Hybrid docker-compose.yml

```yaml
services:
  traefik:
    image: traefik:v3.6
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /home/hajo/docker-volumes/traefik/config:/etc/traefik:ro
      - /home/hajo/docker-volumes/traefik/letsencrypt:/letsencrypt
      - /home/hajo/docker-volumes/traefik/logs:/logs
    networks:
      - traefik-public

  # Home Assistant Proxy
  homeassistant-proxy:
    image: alpine:latest
    container_name: homeassistant-proxy
    command: tail -f /dev/null
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.homeassistant.rule=Host(`ha.hajo63.de`)"
      - "traefik.http.routers.homeassistant.entrypoints=websecure"
      - "traefik.http.routers.homeassistant.tls.certresolver=letsencrypt"
      - "traefik.http.services.homeassistant.loadbalancer.server.url=http://192.168.178.3:8123"
      
      # Nutzt zentrale Middlewares aus middlewares.yml
      - "traefik.http.routers.homeassistant.middlewares=secure-headers@file,geoip-de@file,rate-limit-standard@file"
    networks:
      - traefik-public

networks:
  traefik-public:
    name: traefik-public
```

---

## 📊 Speicherplatz-Kalkulation

### System-SSD (250 GB)
```
RaspberryOS:              ~8 GB
Docker-Images:           ~15 GB  (Traefik, CrowdSec, Alpine)
System-Logs:             ~2 GB   (mit Rotation)
Reserve:                 ~25 GB
─────────────────────────────────
Gesamt genutzt:          ~50 GB
Verfügbar:              ~200 GB  ✅ Sehr viel Reserve
```

### Daten-SSD (950 GB)
```
Traefik-Konfiguration:  ~50 MB   (docker-compose, config, scripts)
Traefik Logs:           ~50 GB   (1 Jahr Access-Logs)
SSL-Zertifikate:        ~10 MB
CrowdSec-Datenbank:     ~500 MB
GeoIP-Datenbanken:      ~100 MB
Backups:                ~20 GB   (3 Monate)
Reserve:                ~50 GB
─────────────────────────────────
Gesamt genutzt:         ~120 GB
Verfügbar:              ~830 GB  ✅ Sehr viel Reserve
```

---

## 🔐 Berechtigungen & Sicherheit

### Kritische Dateien

```bash
# acme.json (Let's Encrypt Account)
chmod 600 /home/hajo/docker-volumes/traefik/letsencrypt/acme.json
chown hajo:hajo /home/hajo/docker-volumes/traefik/letsencrypt/acme.json

# .env (Secrets)
chmod 600 /home/hajo/docker-volumes/traefik/.env
chown hajo:hajo /home/hajo/docker-volumes/traefik/.env

# Traefik-Konfiguration
chmod 644 /home/hajo/docker-volumes/traefik/config/traefik.yml
chown hajo:hajo /home/hajo/docker-volumes/traefik/config/traefik.yml
```

### Docker-Volumes

```bash
# Traefik-Volumes (User hajo besitzt alles)
chown -R hajo:hajo /home/hajo/docker-volumes/traefik
chmod -R 755 /home/hajo/docker-volumes/traefik

# Logs beschreibbar für Docker-Container
chmod 777 /home/hajo/docker-volumes/traefik/logs
```

---

## 🔄 Log-Rotation

### Traefik Access-Logs (können sehr groß werden!)

**Datei**: `/etc/logrotate.d/traefik`

```bash
/home/hajo/docker-volumes/traefik/logs/access.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        docker kill -s USR1 traefik 2>/dev/null || true
    endscript
}

/home/hajo/docker-volumes/traefik/logs/error.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
```

### CrowdSec-Logs

**Datei**: `/etc/logrotate.d/crowdsec`

```bash
/home/hajo/docker-volumes/crowdsec/logs/*.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
```

---

## 💾 Backup-Strategie

### Was muss gesichert werden?

#### Kritisch (täglich)
- ✅ `/home/hajo/docker-volumes/traefik/letsencrypt/acme.json`
- ✅ `/opt/traefik/.env`
- ✅ `/opt/traefik/config/`

#### Wichtig (wöchentlich)
- ✅ `/home/hajo/docker-volumes/crowdsec/config/`
- ✅ `/home/hajo/docker-volumes/crowdsec/data/crowdsec.db`
- ✅ `/etc/nftables.conf`

#### Optional (monatlich)
- ⚠️ `/home/hajo/docker-volumes/traefik/logs/` (nur bei Bedarf)

### Backup-Skript

**Datei**: `/home/hajo/docker-volumes/traefik/scripts/backup.sh`

```bash
#!/bin/bash
# Traefik Backup-Skript

BACKUP_DIR="/home/hajo/docker-volumes/backups/traefik"
DATE=$(date +%Y-%m-%d)
BACKUP_PATH="$BACKUP_DIR/$DATE"

# Backup-Verzeichnis erstellen
mkdir -p "$BACKUP_PATH"

# Kritische Dateien sichern
echo "Sichere Traefik-Konfiguration..."
cp -r /home/hajo/docker-volumes/traefik/config "$BACKUP_PATH/"
cp /home/hajo/docker-volumes/traefik/.env "$BACKUP_PATH/"
cp /home/hajo/docker-volumes/traefik/docker-compose.yml "$BACKUP_PATH/"

# SSL-Zertifikate
echo "Sichere SSL-Zertifikate..."
cp -r /home/hajo/docker-volumes/traefik/letsencrypt "$BACKUP_PATH/"

# CrowdSec
echo "Sichere CrowdSec-Daten..."
cp -r /home/hajo/docker-volumes/crowdsec/config "$BACKUP_PATH/"
cp /home/hajo/docker-volumes/crowdsec/data/crowdsec.db "$BACKUP_PATH/"

# Firewall
echo "Sichere Firewall-Konfiguration..."
cp /etc/nftables.conf "$BACKUP_PATH/"

# Komprimieren
echo "Komprimiere Backup..."
cd "$BACKUP_DIR"
tar -czf "traefik-backup-$DATE.tar.gz" "$DATE"
rm -rf "$DATE"

# Alte Backups löschen (älter als 30 Tage)
find "$BACKUP_DIR" -name "traefik-backup-*.tar.gz" -mtime +30 -delete

echo "Backup abgeschlossen: $BACKUP_DIR/traefik-backup-$DATE.tar.gz"
```

### Automatisches Backup (Systemd Timer)

**Datei**: `/etc/systemd/system/traefik-backup.service`

```ini
[Unit]
Description=Traefik Backup Service
After=docker.service

[Service]
Type=oneshot
ExecStart=/opt/traefik/scripts/backup.sh
User=root
```

**Datei**: `/etc/systemd/system/traefik-backup.timer`

```ini
[Unit]
Description=Traefik Backup Timer
Requires=traefik-backup.service

[Timer]
OnCalendar=daily
OnCalendar=03:00
Persistent=true

[Install]
WantedBy=timers.target
```

**Aktivieren**:
```bash
chmod +x /home/hajo/docker-volumes/traefik/scripts/backup.sh
systemctl enable traefik-backup.timer
systemctl start traefik-backup.timer
systemctl list-timers  # Prüfen
```

---

## 📈 Monitoring & Wartung

### Speicherplatz überwachen

```bash
# Cronjob: Täglich um 6:00 Uhr
0 6 * * * df -h | grep -E '/$|/home' | awk '{if ($5+0 > 80) print "Warnung: "$0}' | mail -s "Speicherplatz-Warnung Pi5" root
```

### Log-Größen prüfen

```bash
# Skript: /home/hajo/docker-volumes/traefik/scripts/check-logs.sh
#!/bin/bash
echo "=== Traefik Log-Größen ==="
du -sh /home/hajo/docker-volumes/traefik/logs/*
echo ""
echo "=== CrowdSec Log-Größen ==="
du -sh /home/hajo/docker-volumes/crowdsec/logs/*
```

### Docker-Image-Cleanup

```bash
# Wöchentlich: Alte Images entfernen
0 2 * * 0 docker image prune -a -f --filter "until=168h"
```

---

## 🚀 Migrations-Checkliste

### Vor der Migration (Pi4 → Pi5)

- [ ] Backup aller Konfigurationen auf Pi4
- [ ] Ordnerstruktur auf Pi5 erstellen
- [ ] Berechtigungen setzen
- [ ] Docker & Docker-Compose installieren
- [ ] Firewall konfigurieren (nftables)

### Während der Migration

- [ ] Traefik auf Pi5 installieren
- [ ] SSL-Zertifikate übertragen (oder neu generieren)
- [ ] CrowdSec konfigurieren
- [ ] GeoIP-Datenbanken herunterladen
- [ ] Test-Routing zu Pi4-Services

### Nach der Migration

- [ ] DNS-Einträge auf Pi5 umstellen
- [ ] Monitoring aktivieren
- [ ] Backup-Timer starten
- [ ] Log-Rotation testen
- [ ] Pi4-nginx deaktivieren (nach Testphase)

---

## 📚 Zusammenfassung

### Empfohlene Konfiguration

| Aspekt | Empfehlung |
|--------|------------|
| **Konfigurationsmethode** | Hybrid (Middlewares in Files, Routing in Labels) |
| **Traefik-Verzeichnis** | `/home/hajo/docker-volumes/traefik/` (Daten-SSD) |
| **Persistente Daten** | `/home/hajo/docker-volumes/` (Daten-SSD) |
| **Logs** | Daten-SSD mit täglicher Rotation |
| **Backups** | Täglich automatisch, 30 Tage Aufbewahrung |
| **SSL-Zertifikate** | Daten-SSD (`/home/.../letsencrypt/`) |
| **Berechtigungen** | User `hajo:hajo` (kein Root nötig) |

### Nächste Schritte

1. Ordnerstruktur auf Pi5 erstellen
2. Entscheidung: Labels, File Provider oder Hybrid?
3. Traefik docker-compose.yml erstellen
4. Backup-Skripte einrichten
5. Log-Rotation konfigurieren

---

**Erstellt**: 2026-02-18  
**Für**: Raspberry Pi 5 Traefik-Setup  
**Autor**: IBM Bob (Plan Mode)