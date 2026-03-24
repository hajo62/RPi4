# 📋 BOB Projekt-Regeln & Standards

Diese Datei enthält alle projektspezifischen Regeln, Pfade und Standards für das BOB-Projekt (Raspberry Pi 5 Server).

## 🌍 SPRACHE

**WICHTIG: Alle Antworten, Kommentare und Dokumentation IMMER auf DEUTSCH!**

- ✅ Antworten: Deutsch
- ✅ Kommentare in Code: Deutsch
- ✅ Dokumentation: Deutsch
- ✅ Commit-Messages: Deutsch
- ✅ README-Dateien: Deutsch

**Ausnahmen:**
- Code-Variablen und Funktionsnamen: Englisch (Standard)
- Technische Begriffe: Original (z.B. "Docker", "Container", "Traefik")

---

## 🏠 System-Informationen

### Hardware
- **Gerät**: Raspberry Pi 5 (16 GB RAM)
- **System-SSD**: 250 GB (Root `/`)
- **Daten-SSD**: 950 GB (Mount `/home`)
- **IP-Adresse**: 192.168.178.55
- **Hostname**: pi5 (oder bob)

### Betriebssystem
- **OS**: Raspberry Pi OS (Debian-basiert)
- **User**: hajo
- **Zeitzone**: Europe/Berlin

### Entwicklungsumgebung
- **Entwicklung**: Mac (lokales Git-Repository)
- **Deployment**: Raspberry Pi 5 (Produktiv-System)
- **Wichtig**: Dateien werden auf dem Mac bearbeitet und müssen dann auf den Pi5 übertragen werden!


---

## 📁 Verzeichnisstruktur & Pfade

### Basis-Pfade (IMMER verwenden!)

```
/home/hajo/
├── docker/                         # Docker-Container-Konfigurationen & Daten
│   ├── traefik/                    # Traefik Reverse Proxy
│   │   ├── docker-compose.yml
│   │   ├── config/
│   │   ├── logs/
│   │   └── certs/
│   │
│   ├── crowdsec/                   # CrowdSec Security
│   ├── nextcloud/                  # Nextcloud (geplant)
│   └── ...
│
└── photos/                         # Geteiltes Foto-Verzeichnis
    ├── 2025/
    ├── 2024/
    ├── 2023/
    └── ...
```

### Wichtige Pfade

| Zweck | Pfad | Beschreibung |
|-------|------|--------------|
| **Container-Configs & Daten** | `/home/hajo/docker/` | Alle Docker-Container (docker-compose.yml, config/, data/) |
| **Foto-Verzeichnis** | `/home/hajo/photos/` | Geteilt zwischen oCIS, Piwigo, Pigallery2, ThisWeekInPast |
| **Backups** | `/home/hajo/backups/` | Automatische Backups |

### Pfad-Konventionen

**Container-Daten bleiben bei Container-Configs:**
- ✅ `/home/hajo/docker/owncloud/data/` (oCIS-Daten)
- ✅ `/home/hajo/docker/traefik/logs/` (Traefik-Logs)
- ✅ `/home/hajo/docker/nextcloud/data/` (Nextcloud-Daten)

**Geteilte Ressourcen:**
- ✅ `/home/hajo/photos/` (für alle Foto-Apps)

---

## 🐳 Docker-Container Standards

### PFLICHT-Labels für JEDEN Container

```yaml
labels:
  # What's Up Docker (WUD) - IMMER hinzufügen!
  - "wud.watch=true"
  - "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"  # Semantic Versioning
  - "wud.display.name=Container Name"
  - "wud.display.icon=si:icon-name"  # Simple Icons
  
  # Watchtower (optional - nur für stabile Container)
  - "com.centurylinklabs.watchtower.enable=true"
```

### Standard-Verzeichnisstruktur

```
docker/container-name/
├── docker-compose.yml      # Hauptkonfiguration
├── .env.example            # Umgebungsvariablen-Template
├── .gitignore              # Git-Ausschlüsse
├── README.md               # Dokumentation
├── config/                 # Konfigurationsdateien
├── data/                   # Persistente Daten (in .gitignore!)
├── logs/                   # Logs (in .gitignore!)
└── scripts/                # Helper-Scripts
```

### Pflicht-Konfigurationen

```yaml
# Zeitzone (IMMER setzen!)
environment:
  - TZ=Europe/Berlin

volumes:
  - /etc/localtime:/etc/localtime:ro
  - /etc/timezone:/etc/timezone:ro

# Restart-Policy
restart: unless-stopped

# Logging
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

# Resource Limits (empfohlen)
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
    reservations:
      cpus: '0.1'
      memory: 64M
```

### Volume-Pfade (relative Pfade bevorzugt)

```yaml
volumes:
  # Relative Pfade für Container-eigene Daten
  - ./config:/config:rw
  - ./data:/data:rw
  - ./logs:/logs:rw
  
  # Absolute Pfade für geteilte Ressourcen
  - /home/hajo/photos:/photos:ro  # read-only für die meisten Apps
```

---

## 🌐 Netzwerk & Routing

### Standard-Netzwerk
- **Name**: `crowdsec-net`
- **Typ**: external (zentral definiert)
- **Verwendung**: Alle Container, die mit Traefik/CrowdSec kommunizieren

```yaml
networks:
  crowdsec-net:
    external: true
```

### Traefik-Integration

**File Provider Ansatz** (bevorzugt):
- Alle Routers/Services in `docker/traefik/config/dynamic/routes.yml`
- Wiederverwendbare Middlewares in `docker/traefik/config/dynamic/middlewares.yml`
- KEINE Docker-Labels für Routing

**Standard-Middlewares** (für alle öffentlichen Services):
```yaml
middlewares:
  - rate-limit-standard@file   # Standard Rate Limiting
  - geoblock-de@file           # Nur Deutschland
  - secure-headers@file        # Security Headers
```

---

## 🔐 Sicherheit

### GeoIP-Blocking
- **Standard**: Nur Deutschland (`geoblock-de@file`)
- **Ausnahmen**: Nur nach expliziter Anforderung

### Rate-Limiting
- **Standard**: 100 req/s, burst 50 (`rate-limit-standard@file`)

### Secrets & Credentials
- **NIEMALS** in Git committen!
- Immer `.env.example` erstellen (ohne echte Werte)
- Echte `.env` in `.gitignore`

### Berechtigungen
- **Container-User**: Bevorzugt 1000:1000 (hajo)
- **Geteilte Verzeichnisse**: Gruppe `media` (GID 1001)
- **SetGID**: Für Verzeichnisse mit gemeinsamen Zugriff

```bash
# Beispiel: Foto-Verzeichnis
chown -R hajo:media /home/hajo/photos
chmod -R 775 /home/hajo/photos
find /home/hajo/photos -type d -exec chmod g+s {} \;
```

---

## 🔌 Port-Management

### Port-Bereiche
- **80, 443**: Traefik (HTTP/HTTPS)
- **3000**: What's Up Docker
- **8080**: CrowdSec LAPI
- **8086**: OwnCloud Infinite Scale
- **8090-8099**: Verschiedene Services
- **8180, 8280**: ThisWeekInPast

### Port-Vergabe-Regeln
1. Prüfe `docker/PORTS.md` vor neuer Port-Vergabe
2. Aktualisiere `docker/PORTS.md` nach Port-Vergabe
3. Bevorzuge Standard-Ports der Anwendung (wenn frei)
4. Dokumentiere Port-Verwendung in README.md

---

## 📝 Dokumentations-Standards

### Pflicht-Dateien für jeden Container

1. **README.md** (Mindestinhalt):
   - Beschreibung & Zweck
   - Voraussetzungen
   - Installation & Konfiguration
   - Verwendung
   - Troubleshooting

2. **.env.example**:
   - Alle Umgebungsvariablen mit Platzhaltern
   - Kommentare für jede Variable
   - Hinweise zur Secret-Generierung

3. **.gitignore**:
   - `.env`
   - `data/`, `logs/`, `db/`
   - `*.key`, `*.pem`, `*.crt`

### Kommentar-Header für docker-compose.yml

```yaml
# ============================================
# Container-Name - Kurzbeschreibung
# ============================================
#
# Beschreibung was der Container macht
#
# Verwendung:
#   docker compose up -d              # Service starten
#   docker compose logs -f            # Logs anzeigen
#   docker compose down               # Service stoppen
#
# ============================================
```

---

## 🎨 Icon-Auswahl (Simple Icons)

Bevorzugte Icons für Container:

| Container-Typ | Icon-Code |
|--------------|-----------|
| Nextcloud | `si:nextcloud` |
| Home Assistant | `si:homeassistant` |
| Traefik | `si:traefikproxy` |
| CrowdSec | `si:crowdsec` |
| Signal | `si:signal` |
| nginx | `si:nginx` |
| PostgreSQL | `si:postgresql` |
| Redis | `si:redis` |
| Docker | `si:docker` |

**Suche weitere Icons**: https://simpleicons.org/

---

## 🔄 Backup-Strategie

### Was wird gesichert?

**Täglich**:
- `/home/hajo/docker/` (alle Container-Daten)
- Traefik-Konfiguration & SSL-Zertifikate
- oCIS-Daten

**Wöchentlich**:
- `/home/hajo/photos/` (groß, aber wichtig)
- CrowdSec-Datenbank
- Logs (komprimiert)

### Backup-Speicherort
- **Lokal**: `/home/hajo/backups/`
- **Remote**: (noch zu definieren)

---


### Datei-Transfer Mac → Pi5

**Wichtig**: Dateien werden auf dem Mac bearbeitet und müssen auf den Pi5 übertragen werden!

#### Methode 1: rsync (empfohlen)
```bash
# Einzelne Datei
rsync -avz /pfad/zur/datei hajo@192.168.178.55:/home/hajo/ziel/

# Ganzes Verzeichnis
rsync -avz /pfad/zum/verzeichnis/ hajo@192.168.178.55:/home/hajo/ziel/

# Beispiel: Firewall-Konfiguration
rsync -avz nftables-pi5-fixed.conf hajo@192.168.178.55:/tmp/
# Dann auf Pi5: sudo cp /tmp/nftables-pi5-fixed.conf /etc/nftables.conf
```

#### Methode 2: scp
```bash
# Einzelne Datei
scp /pfad/zur/datei hajo@192.168.178.55:/home/hajo/ziel/

# Ganzes Verzeichnis
scp -r /pfad/zum/verzeichnis hajo@192.168.178.55:/home/hajo/ziel/
```

#### Methode 3: Git (für versionierte Dateien)
```bash
# Auf Mac: Commit & Push
git add .
git commit -m "Update configuration"
git push

# Auf Pi5: Pull
cd /home/hajo/Privat/RaspberryPi/BOB
git pull
```

## 🚀 Deployment-Workflow

### Neue Container hinzufügen

1. **Verzeichnis erstellen**:
   ```bash
   mkdir -p /home/hajo/docker/container-name/{config,data,logs,scripts}
   ```

2. **Dateien erstellen**:
   - `docker-compose.yml` (mit WUD-Labels!)
   - `.env.example`
   - `.gitignore`
   - `README.md`

3. **Berechtigungen setzen**:
   ```bash
   chown -R hajo:hajo /home/hajo/docker/container-name
   chmod -R 750 /home/hajo/docker/container-name
   ```

4. **Traefik-Route hinzufügen** (falls öffentlich):
   - Router in `docker/traefik/config/dynamic/routes.yml`
   - Service in `docker/traefik/config/dynamic/routes.yml`

5. **Port dokumentieren**:
   - Eintrag in `docker/PORTS.md`

6. **Testen**:
   ```bash
   cd /home/hajo/docker/container-name
   docker compose up -d
   docker compose logs -f
   ```

---

## 📚 Referenz-Dokumente

- **Container-Standards**: `docker/CONTAINER-STANDARDS.md`
- **Port-Übersicht**: `docker/PORTS.md`
- **Traefik-Konfiguration**: `docker/traefik/README.md`
- **CrowdSec-Integration**: `docker/crowdsec/README.md`

---

## ✅ Checkliste für neue Container

- [ ] Verzeichnisstruktur unter `/home/hajo/docker/container-name/` angelegt
- [ ] docker-compose.yml mit WUD-Labels erstellt
- [ ] Relative Pfade für Container-Daten (`./config`, `./data`, `./logs`)
- [ ] Absolute Pfade nur für geteilte Ressourcen (`/home/hajo/photos`)
- [ ] .env.example erstellt
- [ ] .gitignore erstellt
- [ ] README.md erstellt
- [ ] Berechtigungen gesetzt (hajo:hajo, 750)
- [ ] Zeitzone konfiguriert (TZ=Europe/Berlin)
- [ ] Resource Limits definiert
- [ ] Logging konfiguriert (max-size 10m, max-file 3)
- [ ] Netzwerk: crowdsec-net (external)
- [ ] Traefik-Route hinzugefügt (falls öffentlich)
- [ ] Port in PORTS.md dokumentiert
- [ ] Getestet (start, stop, restart)
- [ ] WUD-Erkennung verifiziert

---

*Zuletzt aktualisiert: 2026-03-07*
*Made with Bob* 🤖