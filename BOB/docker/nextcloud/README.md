# 🌥️ Nextcloud auf Pi5

Nextcloud Cloud-Speicher und Collaboration-Plattform für Pi5.

## 📋 Übersicht

Diese Installation ersetzt die Nextcloud-Installation auf Pi4 und nutzt:
- **Nextcloud**: Stable Version
- **MariaDB**: Datenbank
- **Redis**: Cache für bessere Performance
- **Traefik**: Reverse Proxy mit SSL
- **CrowdSec**: Sicherheit

## 🔌 Ports

| Port | Dienst | Beschreibung |
|------|--------|--------------|
| **8089** | Nextcloud | Web-Interface (intern) |
| **3307** | MariaDB | Datenbank (intern) |

**Öffentlicher Zugriff:**
- `https://nc.hajo63.de` (via Traefik)
- `https://nc.hajo62.duckdns.org` (via Traefik, Fallback)

## 📁 Verzeichnisstruktur

```
docker/nextcloud/
├── docker-compose.yml      # Container-Konfiguration
├── .env.example            # Umgebungsvariablen-Template
├── .env                    # Umgebungsvariablen (nicht in Git!)
├── .gitignore              # Git-Ausschlüsse
├── README.md               # Diese Datei
├── config/                 # Nextcloud-Konfiguration
├── data/                   # Nextcloud-Daten (nicht in Git!)
├── db/                     # MariaDB-Daten (nicht in Git!)
├── logs/                   # Log-Dateien (nicht in Git!)
└── scripts/                # Helper-Scripts
```

## 🚀 Installation

### 1. Verzeichnisse auf Pi5 erstellen

```bash
# Auf Pi5 ausführen:
ssh hajo@192.168.178.55

# Verzeichnisse erstellen
mkdir -p /home/hajo/docker/nextcloud/{config,data,db,logs,scripts}

# Berechtigungen setzen
chown -R hajo:hajo /home/hajo/docker/nextcloud
chmod -R 750 /home/hajo/docker/nextcloud
```

### 2. Dateien übertragen

```bash
# Auf Mac ausführen:
cd /Users/hajo/Privat/RaspberryPi/BOB

# Dateien übertragen
rsync -avz docker/nextcloud/ hajo@192.168.178.55:/home/hajo/docker/nextcloud/
```

### 3. Umgebungsvariablen konfigurieren

```bash
# Auf Pi5 ausführen:
cd /home/hajo/docker/nextcloud

# .env erstellen
cp .env.example .env
nano .env

# Sichere Passwörter generieren:
openssl rand -base64 32
```

**Wichtig:** Setze sichere Passwörter für:
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_PASSWORD`

### 4. Netzwerk erstellen (falls noch nicht vorhanden)

```bash
# Auf Pi5 ausführen:
docker network create crowdsec-net
```

### 5. Container starten

```bash
# Auf Pi5 ausführen:
cd /home/hajo/docker/nextcloud

# Container starten
docker compose up -d

# Logs anzeigen
docker compose logs -f
```

### 6. Nextcloud einrichten

1. Öffne `http://192.168.178.55:8089` im Browser
2. Erstelle Admin-Account
3. Datenbank-Konfiguration wird automatisch übernommen

### 7. Traefik-Route aktivieren

Die Route muss in `/home/hajo/docker/traefik/config/dynamic/routes.yml` hinzugefügt werden (siehe unten).

## 🔧 Konfiguration

### Nextcloud-Konfiguration anpassen

```bash
# Auf Pi5 ausführen:
cd /home/hajo/docker/nextcloud

# config.php bearbeiten
nano data/config/config.php
```

**Wichtige Einstellungen:**

```php
'trusted_domains' => 
  array (
    0 => 'nc.hajo63.de',
    1 => 'nc.hajo62.duckdns.org',
    2 => '192.168.178.55',
  ),
'overwrite.cli.url' => 'https://nc.hajo63.de',
'overwriteprotocol' => 'https',
'trusted_proxies' => 
  array (
    0 => '172.0.0.0/8',
  ),
```

### Redis-Cache aktivieren

```php
'memcache.local' => '\\OC\\Memcache\\Redis',
'memcache.locking' => '\\OC\\Memcache\\Redis',
'redis' => 
  array (
    'host' => 'nextcloud-redis',
    'port' => 6379,
  ),
```

## 🌐 Traefik-Integration

### Route hinzufügen

Füge in `/home/hajo/docker/traefik/config/dynamic/routes.yml` hinzu:

```yaml
# Nextcloud (Pi5)
nc-pi5:
  rule: "Host(`nc.hajo63.de`) || Host(`nc.hajo62.duckdns.org`)"
  entryPoints:
    - websecure
  service: nextcloud-pi5
  middlewares:
    - rate-limit-standard@file
    - geoblock-de@file
    - secure-headers@file
  tls:
    options: tls-modern
```

### Service hinzufügen

```yaml
# Nextcloud Pi5
nextcloud-pi5:
  loadBalancer:
    passHostHeader: true
    servers:
      - url: "http://nextcloud:80"
```

### Traefik neu laden

```bash
# Auf Pi5 ausführen:
cd /home/hajo/docker/traefik
docker compose restart
```

## 📊 Verwaltung

### Container-Status prüfen

```bash
cd /home/hajo/docker/nextcloud
docker compose ps
```

### Logs anzeigen

```bash
# Alle Container
docker compose logs -f

# Nur Nextcloud
docker compose logs -f nextcloud

# Nur Datenbank
docker compose logs -f nextcloud-db
```

### Container neu starten

```bash
docker compose restart
```

### Container stoppen

```bash
docker compose down
```

### Updates durchführen

```bash
# Images aktualisieren
docker compose pull

# Container neu starten
docker compose up -d
```

## 🔒 Sicherheit

### Berechtigungen

```bash
# Auf Pi5 ausführen:
cd /home/hajo/docker/nextcloud

# Nextcloud-Daten
chown -R www-data:www-data data/
chmod -R 750 data/

# Datenbank
chown -R 999:999 db/
chmod -R 750 db/
```

### Backup

```bash
# Auf Pi5 ausführen:

# Datenbank-Backup
docker exec nextcloud-db mysqldump -u nextcloud -p nextcloud > backup-$(date +%Y%m%d).sql

# Nextcloud-Daten
tar -czf nextcloud-data-$(date +%Y%m%d).tar.gz data/
```

### Restore

```bash
# Datenbank wiederherstellen
docker exec -i nextcloud-db mysql -u nextcloud -p nextcloud < backup-20260311.sql

# Daten wiederherstellen
tar -xzf nextcloud-data-20260311.tar.gz
```

## 🔍 Troubleshooting

### Problem: Nextcloud zeigt "Zugriff über nicht vertrauenswürdige Domain"

**Lösung:**
```bash
# config.php bearbeiten
nano data/config/config.php

# trusted_domains erweitern
'trusted_domains' => 
  array (
    0 => 'nc.hajo63.de',
    1 => 'nc.hajo62.duckdns.org',
    2 => '192.168.178.55',
  ),
```

### Problem: Datenbank-Verbindung fehlgeschlagen

**Lösung:**
```bash
# Datenbank-Status prüfen
docker compose logs nextcloud-db

# Healthcheck prüfen
docker inspect nextcloud-db | grep -A 10 Health

# Container neu starten
docker compose restart nextcloud-db
```

### Problem: Redis-Verbindung fehlgeschlagen

**Lösung:**
```bash
# Redis-Status prüfen
docker compose logs nextcloud-redis

# Redis-Verbindung testen
docker exec nextcloud-redis redis-cli ping
```

### Problem: Langsame Performance

**Lösungen:**
1. Redis-Cache aktivieren (siehe oben)
2. PHP-Memory erhöhen in `data/config/config.php`:
   ```php
   'memcache.local' => '\\OC\\Memcache\\Redis',
   ```
3. Cron-Job einrichten:
   ```bash
   docker exec -u www-data nextcloud php cron.php
   ```

## 📚 Weitere Informationen

- **Nextcloud Dokumentation**: https://docs.nextcloud.com/
- **Docker Hub**: https://hub.docker.com/_/nextcloud
- **Projekt-Regeln**: `/PROJECT-RULES.md`
- **Port-Übersicht**: `/docker/PORTS.md`

## 🔄 Migration von Pi4

### Daten migrieren

```bash
# Auf Pi4: Backup erstellen
ssh hajo@192.168.178.3
cd /home/hajo/docker-volumes/nextcloud
tar -czf nextcloud-backup.tar.gz data/

# Datenbank exportieren
docker exec nextcloud-db mysqldump -u nextcloud -p nextcloud > nextcloud-db.sql

# Auf Pi5: Daten importieren
scp hajo@192.168.178.3:/home/hajo/docker-volumes/nextcloud/nextcloud-backup.tar.gz .
scp hajo@192.168.178.3:/home/hajo/docker-volumes/nextcloud/nextcloud-db.sql .

# Entpacken
tar -xzf nextcloud-backup.tar.gz -C /home/hajo/docker/nextcloud/

# Datenbank importieren
docker exec -i nextcloud-db mysql -u nextcloud -p nextcloud < nextcloud-db.sql
```

### DNS umstellen

1. Traefik-Route auf Pi5 aktivieren
2. Testen: `https://nc.hajo63.de`
3. Pi4 Nextcloud stoppen
4. DNS-Eintrag aktualisieren (falls nötig)

---

**Made with Bob** 🤖
*Zuletzt aktualisiert: 2026-03-11*