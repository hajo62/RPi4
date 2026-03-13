# What's Up Docker (WUD) - Container Update Monitoring

WUD überwacht deine Docker-Container und zeigt verfügbare Updates im Dashboard an. Bei Updates wird automatisch eine Signal-Benachrichtigung gesendet.

## 🚀 Schnellstart

### 1. Verzeichnis vorbereiten
```bash
cd docker/whats-up-docker
```

### 2. Scripts ausführbar machen
```bash
chmod +x scripts/send_signal.sh
chmod +x webhook-server.sh
```

### 3. Umgebungsvariablen konfigurieren
```bash
cp .env.example .env
nano .env  # Passe SIGNAL_RECIPIENT_NUMBER an
```

### 4. Signal-Empfänger in Script anpassen
```bash
nano scripts/send_signal.sh
# Ändere SIGNAL_RECIPIENT="+49123456789" zu deiner Nummer
```

### 5. Container starten
```bash
docker-compose up -d
```

### 6. Dashboard öffnen
Öffne im Browser: **http://localhost:3000**

## 📊 Architektur

```
┌─────────────┐         ┌──────────────┐         ┌─────────────────┐
│    WUD      │ ──────> │ wud-webhook  │ ──────> │ send_signal.sh  │
│  (Monitor)  │ HTTP    │ (Alpine+Bash)│ exec    │   (Bash)        │
└─────────────┘         └──────────────┘         └─────────────────┘
      │                                                    │
      │ überwacht                                          │ sendet
      ▼                                                    ▼
┌─────────────┐                                   ┌─────────────────┐
│   Docker    │                                   │  Signal-CLI     │
│  Container  │                                   │   REST API      │
└─────────────┘                                   └─────────────────┘
```

## 🔔 Benachrichtigungen

### Signal-Benachrichtigung

Wenn ein Update verfügbar ist:
1. WUD erkennt das Update
2. WUD sendet HTTP POST an `wud-webhook:8080/webhook`
3. Webhook-Server führt `send_signal.sh` aus
4. Script sendet Signal-Nachricht mit Update-Info

**Beispiel-Nachricht:**
```
🔄 Docker Update verfügbar

Container: nginx
Aktuell: 1.24
Neu: 1.25

Dashboard: http://localhost:3000
```

## ⚙️ Konfiguration

### Standard-Einstellungen

- **WUD Dashboard:** Port 3000
- **Webhook Server:** Port 8091
- **Update-Check:** Alle 6 Stunden
- **Überwachung:** Alle Container automatisch
- **Modus:** Nur Anzeige + Benachrichtigung (keine automatischen Updates)
- **Webhook-Server:** Alpine 3.23 (gleiche Version wie ionos-dyndns)

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

### Signal-Empfänger ändern

**Option 1: In .env**
```bash
SIGNAL_RECIPIENT_NUMBER=+49123456789
```

**Option 2: Direkt in send_signal.sh**
```bash
SIGNAL_RECIPIENT="+49123456789"
```

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

### Webhook-Server anpassen

Die Datei `webhook-server.sh` kann erweitert werden für:
- Zusätzliche Logging
- Andere Benachrichtigungsdienste
- Datenbank-Logging
- Automatische Updates (nicht empfohlen!)

### Script anpassen

Die Datei `scripts/send_signal.sh` kann erweitert werden für:
- E-Mail-Benachrichtigungen
- Slack/Discord Webhooks
- Log-Dateien
- Automatische Backups vor Updates

## 📝 Logs anzeigen

```bash
# WUD Logs
docker-compose logs -f wud

# Webhook-Server Logs
docker-compose logs -f wud-webhook

# Beide zusammen
docker-compose logs -f
```

## 🛠️ Wartung

### Container neu starten
```bash
docker-compose restart
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

## 🧪 Webhook testen

### Health-Check
```bash
curl http://localhost:8091/health
```

### Manuellen Webhook-Call testen
```bash
curl -X POST http://localhost:8091/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-container",
    "result": {"tag": "1.0"},
    "updateAvailable": {"tag": "2.0"}
  }'
```

## 🔗 Nützliche Links

- [WUD Dokumentation](https://fmartinou.github.io/whats-up-docker/)
- [GitHub Repository](https://github.com/fmartinou/whats-up-docker)
- [Docker Hub](https://hub.docker.com/r/fmartinou/whats-up-docker)

## 💡 Tipps

1. **Dashboard als Bookmark** - Speichere `http://localhost:3000` als Lesezeichen
2. **Wöchentliche Routine** - Prüfe jeden Sonntag das Dashboard
3. **Signal-Test** - Teste die Benachrichtigung mit dem manuellen Webhook-Call
4. **Kombiniere mit Dockge** - Nutze Dockge für komfortable Updates

## ⚠️ Wichtig

- WUD führt **KEINE automatischen Updates** durch
- Es zeigt nur verfügbare Updates an und benachrichtigt dich
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

### Signal-Benachrichtigung funktioniert nicht
```bash
# Webhook-Server Logs prüfen
docker-compose logs wud-webhook

# Script manuell testen
docker-compose exec wud-webhook bash /scripts/send_signal.sh "test" "1.0" "2.0"

# Signal-CLI REST API erreichbar?
curl http://signal-cli-rest-api:8080/v1/about
```

### Webhook-Server startet nicht
```bash
# Logs prüfen
docker-compose logs wud-webhook

# Script existiert?
ls -la scripts/send_signal.sh

# Script ausführbar?
chmod +x scripts/send_signal.sh
docker-compose restart wud-webhook
```

### WARN: Cannot find module 'script'
Diese Warnung ist normal und kann ignoriert werden. WUD nutzt jetzt den HTTP-Webhook statt des Script-Triggers.

## 📋 Checkliste nach Installation

- [ ] `chmod +x scripts/send_signal.sh` ausgeführt
- [ ] `chmod +x webhook-server.sh` ausgeführt
- [ ] `.env` erstellt und `SIGNAL_RECIPIENT_NUMBER` angepasst
- [ ] Signal-Empfänger in `send_signal.sh` angepasst
- [ ] Container gestartet: `docker-compose up -d`
- [ ] Dashboard erreichbar: http://localhost:3000
- [ ] Webhook-Health-Check: `curl http://localhost:8091/health`
- [ ] Signal-Test durchgeführt
- [ ] Container werden im Dashboard angezeigt