# What's Up Docker (WUD) - Container Update Monitoring

WUD überwacht deine Docker-Container und zeigt verfügbare Updates im Dashboard an.

## 🚀 Schnellstart

### 1. Verzeichnis vorbereiten
```bash
cd docker/whats-up-docker
```

### 2. Umgebungsvariablen konfigurieren (optional)
```bash
cp .env.example .env
# Bearbeite .env nach Bedarf
```

### 3. Container starten
```bash
docker-compose up -d
```

### 4. Dashboard öffnen
Öffne im Browser: **http://localhost:3000**

## 📊 Dashboard

Das WUD-Dashboard zeigt:
- ✅ Alle überwachten Container
- 🔄 Verfügbare Updates
- 📦 Aktuelle vs. neueste Version
- 🏷️ Image-Tags und Registry-Informationen

## ⚙️ Konfiguration

### Standard-Einstellungen

- **Port:** 3000
- **Update-Check:** Alle 6 Stunden
- **Überwachung:** Alle Container automatisch
- **Modus:** Nur Anzeige (keine automatischen Updates)

### Container von Überwachung ausschließen

Füge einem Container folgendes Label hinzu:

```yaml
services:
  mein-service:
    image: nginx:latest
    labels:
      - "wud.watch=false"
```

### Nur bestimmte Container überwachen

In `docker-compose.yml` ändern:
```yaml
environment:
  - WUD_WATCHER_LOCAL_WATCHBYDEFAULT=false
```

Dann bei gewünschten Containern:
```yaml
labels:
  - "wud.watch=true"
```

### Update-Check Intervall ändern

In `.env` oder `docker-compose.yml`:
```yaml
# Täglich um 6 Uhr morgens
WUD_WATCHER_LOCAL_CRON=0 6 * * *

# Alle 12 Stunden
WUD_WATCHER_LOCAL_CRON=0 */12 * * *
```

## 🔔 Benachrichtigungen (Optional)

### Telegram einrichten

1. Bot erstellen: [@BotFather](https://t.me/botfather) → `/newbot`
2. Chat-ID ermitteln: [@userinfobot](https://t.me/userinfobot)
3. In `.env` eintragen:
```bash
WUD_TRIGGER_TELEGRAM_BOTTOKEN=123456:ABC-DEF...
WUD_TRIGGER_TELEGRAM_CHATID=123456789
```
4. Container neu starten: `docker-compose up -d`

### ntfy.sh (ohne eigenen Server)

1. In `.env` eintragen:
```bash
WUD_TRIGGER_NTFY_URL=https://ntfy.sh/mein-homeserver-updates
```
2. ntfy App installieren und Topic abonnieren
3. Container neu starten

### Weitere Optionen

Siehe `.env.example` für:
- E-Mail (SMTP)
- Discord
- Gotify
- Und mehr...

## 🔍 Erweiterte Konfiguration

### Semver-Filter (nur bestimmte Versionen)

```yaml
services:
  nginx:
    image: nginx:latest
    labels:
      # Nur Major.Minor Updates (z.B. 1.24 → 1.25, nicht 1.24.1 → 1.24.2)
      - "wud.tag.include=^\\d+\\.\\d+$"
      
      # Keine Beta/RC Versionen
      - "wud.tag.exclude=.*(beta|rc|alpha).*"
```

### Private Registry

```yaml
environment:
  - WUD_REGISTRY_MYREGISTRY_URL=https://registry.example.com
  - WUD_REGISTRY_MYREGISTRY_LOGIN=username
  - WUD_REGISTRY_MYREGISTRY_PASSWORD=password
```

## 📝 Logs anzeigen

```bash
# Live-Logs
docker-compose logs -f wud

# Letzte 100 Zeilen
docker-compose logs --tail=100 wud
```

## 🛠️ Wartung

### Container neu starten
```bash
docker-compose restart wud
```

### Container aktualisieren
```bash
docker-compose pull
docker-compose up -d
```

### Container stoppen
```bash
docker-compose down
```

### Daten löschen (Reset)
```bash
docker-compose down
rm -rf data/
docker-compose up -d
```

## 🔗 Nützliche Links

- [WUD Dokumentation](https://fmartinou.github.io/whats-up-docker/)
- [GitHub Repository](https://github.com/fmartinou/whats-up-docker)
- [Docker Hub](https://hub.docker.com/r/fmartinou/whats-up-docker)

## 💡 Tipps

1. **Dashboard als Bookmark** - Speichere `http://localhost:3000` als Lesezeichen
2. **Wöchentliche Routine** - Prüfe jeden Sonntag das Dashboard
3. **Benachrichtigungen** - Richte Telegram/ntfy ein für automatische Alerts
4. **Kombiniere mit Dockge** - Nutze Dockge für komfortable Updates

## ⚠️ Wichtig

- WUD führt **KEINE automatischen Updates** durch
- Es zeigt nur verfügbare Updates an
- Du behältst die volle Kontrolle
- Perfekt für HomeServer mit kritischen Diensten

## 🆘 Troubleshooting

### Dashboard nicht erreichbar
```bash
# Container-Status prüfen
docker-compose ps

# Logs prüfen
docker-compose logs wud

# Port-Konflikt? Ändere Port in docker-compose.yml
ports:
  - "3001:3000"  # Statt 3000:3000
```

### Keine Container werden angezeigt
```bash
# Docker Socket Berechtigung prüfen
ls -la /var/run/docker.sock

# Container neu starten
docker-compose restart wud
```

### Updates werden nicht erkannt
```bash
# Manuellen Check triggern (im Container)
docker-compose exec wud wget -O- http://localhost:3000/api/watcher/local/watch