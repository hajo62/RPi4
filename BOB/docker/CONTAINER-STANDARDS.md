# 📋 Container Standards für BOB Projekt

Dieses Dokument definiert die **verbindlichen Standards** für alle Docker Container im BOB-Projekt.

## 🎯 Zweck

Stelle sicher, dass **jeder neue Container** diese Standards erfüllt, um:
- ✅ Konsistente Überwachung (WUD)
- ✅ Automatische Updates (Watchtower)
- ✅ Einheitliche Konfiguration
- ✅ Wartbarkeit und Dokumentation

---

## 📦 Pflicht-Labels für JEDEN Container

### 1. What's Up Docker (WUD) Labels

**IMMER hinzufügen** - für Update-Überwachung:

```yaml
labels:
  # What's Up Docker: Überwachung aktivieren
  - "wud.watch=true"
  - "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"  # Semantic Versioning
  - "wud.display.name=Container-Name"
  - "wud.display.icon=si:icon-name"  # Simple Icons
```

**Anpassungen:**
- `wud.display.name`: Sprechender Name (z.B. "CrowdSec", "Signal CLI")
- `wud.display.icon`: Icon von [Simple Icons](https://simpleicons.org/)
- `wud.tag.include`: Regex für erlaubte Tags (Standard: Semantic Versioning)

### 2. Watchtower Labels

**Optional** - nur wenn Auto-Updates gewünscht:

```yaml
labels:
  # Watchtower: Auto-Updates aktivieren
  - "com.centurylinklabs.watchtower.enable=true"
```

**Hinweis:** Nicht für alle Container empfohlen (z.B. Datenbanken)!

---

## 🏗️ Standard Container-Struktur

### Verzeichnis-Layout

```
docker/
├── container-name/
│   ├── docker-compose.yml      # Hauptkonfiguration
│   ├── .env.example            # Umgebungsvariablen-Template
│   ├── .gitignore              # Git-Ausschlüsse
│   ├── README.md               # Dokumentation
│   ├── config/                 # Konfigurationsdateien
│   ├── data/                   # Persistente Daten
│   └── scripts/                # Helper-Scripts
```

### docker-compose.yml Template

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

services:
  service-name:
    image: vendor/image:latest
    container_name: container-name
    restart: unless-stopped
    
    environment:
      - TZ=Europe/Berlin
      # Weitere Umgebungsvariablen
    
    volumes:
      - ./config:/config:rw
      - ./data:/data:rw
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
    
    networks:
      - proxy  # oder eigenes Netzwerk
    
    ports:
      - "8080:8080"
    
    labels:
      # Watchtower: Auto-Updates (optional)
      - "com.centurylinklabs.watchtower.enable=true"
      
      # What's Up Docker: Überwachung (PFLICHT!)
      - "wud.watch=true"
      - "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"
      - "wud.display.name=Container Name"
      - "wud.display.icon=si:icon-name"
    
    # Resource Limits (empfohlen)
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.1'
          memory: 64M
    
    # Healthcheck (empfohlen)
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  proxy:
    external: true

# Made with Bob
```

---

## 📝 Pflicht-Dateien

### 1. README.md

**Mindestinhalt:**
- Beschreibung des Containers
- Voraussetzungen
- Installation
- Konfiguration
- Verwendung
- Troubleshooting

### 2. .env.example

**Template für Umgebungsvariablen:**
```bash
# Container Name - Umgebungsvariablen
# Kopiere diese Datei nach .env und passe die Werte an

# API Keys
API_KEY=your_api_key_here

# Ports
PORT=8080

# Weitere Variablen...
```

### 3. .gitignore

**Standard-Ausschlüsse:**
```gitignore
# Umgebungsvariablen
.env

# Daten
data/
db/
logs/

# Secrets
*.key
*.pem
*.crt

# Temporäre Dateien
*.tmp
*.log
```

---

## 🔧 Weitere Best Practices

### Zeitzone

**IMMER** setzen:
```yaml
environment:
  - TZ=Europe/Berlin
volumes:
  - /etc/localtime:/etc/localtime:ro
  - /etc/timezone:/etc/timezone:ro
```

### Netzwerke

**Bevorzugt:** Externes `proxy` Netzwerk
```yaml
networks:
  proxy:
    external: true
```

**Alternativ:** Eigenes Netzwerk für Isolation
```yaml
networks:
  container-net:
    name: container-net
    driver: bridge
```

### Resource Limits

**Empfohlen** für alle Container:
```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'      # Max CPU
      memory: 256M     # Max RAM
    reservations:
      cpus: '0.1'      # Min CPU
      memory: 64M      # Min RAM
```

### Healthchecks

**Empfohlen** für Monitoring:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

---

## ✅ Checkliste für neue Container

Beim Erstellen eines neuen Containers:

- [ ] Verzeichnisstruktur angelegt
- [ ] docker-compose.yml erstellt
- [ ] **WUD Labels hinzugefügt** ⚠️ WICHTIG!
- [ ] Watchtower Label (falls gewünscht)
- [ ] Zeitzone konfiguriert
- [ ] Resource Limits gesetzt
- [ ] Healthcheck definiert
- [ ] README.md erstellt
- [ ] .env.example erstellt
- [ ] .gitignore erstellt
- [ ] In zentrale docker-compose.yml eingebunden
- [ ] Dokumentation aktualisiert
- [ ] Getestet (start, stop, restart)
- [ ] WUD-Erkennung verifiziert

---

## 🎨 Icon-Auswahl

### Beliebte Icons für Container:

| Container-Typ | Icon | Code |
|--------------|------|------|
| CrowdSec | 🛡️ | `si:crowdsec` |
| Signal | 💬 | `si:signal` |
| Traefik | 🔀 | `si:traefikproxy` |
| nginx | 🌐 | `si:nginx` |
| PostgreSQL | 🐘 | `si:postgresql` |
| Redis | 🔴 | `si:redis` |
| Docker | 🐳 | `si:docker` |
| Python | 🐍 | `si:python` |
| Node.js | 🟢 | `si:nodedotjs` |

**Suche Icons:** https://simpleicons.org/

---

## 🚨 Häufige Fehler

### ❌ Fehler 1: WUD Labels vergessen
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
  # ❌ WUD Labels fehlen!
```

### ✅ Richtig:
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
  - "wud.watch=true"  # ✅ WUD aktiviert
  - "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"
  - "wud.display.name=Container Name"
  - "wud.display.icon=si:icon-name"
```

### ❌ Fehler 2: Falsche Regex-Escaping
```yaml
- "wud.tag.include=^\d+\.\d+\.\d+$"  # ❌ Falsch!
```

### ✅ Richtig:
```yaml
- "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"  # ✅ Doppelte Backslashes!
```

### ❌ Fehler 3: Zeitzone vergessen
```yaml
environment:
  - API_KEY=xyz
  # ❌ TZ fehlt!
```

### ✅ Richtig:
```yaml
environment:
  - TZ=Europe/Berlin  # ✅ Zeitzone gesetzt
  - API_KEY=xyz
```

---

## 📚 Weitere Ressourcen

- [What's Up Docker Dokumentation](https://fmartinou.github.io/whats-up-docker/)
- [Watchtower Dokumentation](https://containrrr.dev/watchtower/)
- [Docker Compose Best Practices](https://docs.docker.com/compose/compose-file/)
- [Simple Icons](https://simpleicons.org/)

---

## 🔄 Updates

Dieses Dokument wird bei Bedarf aktualisiert. Letzte Änderung: 2026-02-25

---

**Made with Bob** 🤖