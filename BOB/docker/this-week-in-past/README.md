# This Week in Past - Docker Setup für Pi5

Dieses Projekt zeigt Fotos aus der Vergangenheit, die in der aktuellen Kalenderwoche aufgenommen wurden. Es verwendet den NFS-Mount `/srv/nfs/photos` vom Pi4 als Bildquelle.

## Übersicht

Das Setup enthält zwei Container:
- **this-week-in-past**: Hauptinstanz mit allen öffentlichen Fotos (Port 8180)
- **this-week-in-past-priv**: Private Instanz mit ausgewählten privaten Fotos (Port 8280)

## Voraussetzungen

### 1. NFS-Mount einrichten

Der NFS-Mount vom Pi4 muss auf dem Pi5 unter `/srv/nfs/photos` verfügbar sein.

**Siehe detaillierte Anleitung in:** `nfs_Pi5_von_Pi4.md`

```bash
# NFS-Mount prüfen
mount | grep /srv/nfs/photos
```

### 2. Umgebungsvariablen konfigurieren

```bash
# .env Datei erstellen
cp .env.example .env

# API-Keys eintragen
nano .env
```

Benötigte API-Keys:
- **BigData Cloud API**: https://www.bigdatacloud.com/ (für Geolocation)
- **OpenWeatherMap API**: https://openweathermap.org/api (für Wetterdaten)

## Installation

```bash
# In das Projektverzeichnis wechseln
cd docker/this-week-in-past

# Container starten
docker-compose up -d

# Logs anzeigen
docker-compose logs -f

# Status prüfen
docker-compose ps
```

## Zugriff

- **Hauptinstanz**: http://pi5-ip:8180
- **Private Instanz**: http://pi5-ip:8280

## Konfiguration

### Hauptinstanz (this-week-in-past)

- **Port**: 8180
- **Ressourcen**: 2 CPU, 1GB RAM
- **Bildquelle**: `/srv/nfs/photos` (NFS-Mount vom Pi4)
- **Pfade**: Alle Jahrzehnte von 1962-2025 + Fotoalben
- **Slideshow-Intervall**: 120 Sekunden
- **Wetter**: Aktiviert

### Private Instanz (this-week-in-past-priv)

- **Port**: 8280
- **Ressourcen**: 1 CPU, 384MB RAM
- **Bildquelle**: `/srv/nfs/photos` (NFS-Mount vom Pi4)
- **Pfade**: Nur ausgewählte private Ordner
- **Slideshow-Intervall**: 145 Sekunden
- **Wetter**: Deaktiviert
- **Random Slideshow**: Aktiviert

## Umgebungsvariablen

| Variable | Beschreibung | Standard |
|----------|--------------|----------|
| `BIGDATA_CLOUD_API_KEY` | API-Key für Geolocation | - |
| `OPEN_WEATHER_MAP_API_KEY` | API-Key für Wetterdaten | - |
| `DATE_FORMAT` | Datumsformat | `%a %d.%m.%Y` |
| `IGNORE_FOLDER_MARKER_FILES` | Marker-Dateien zum Ignorieren | `.twipignore` |
| `IGNORE_FOLDER_REGEX` | Regex für zu ignorierende Ordner | siehe docker-compose.yml |
| `PRELOAD_IMAGES` | Bilder vorladen | `true` |
| `RESOURCE_PATHS` | Komma-getrennte Liste der Bildpfade | siehe docker-compose.yml |
| `SLIDESHOW_INTERVAL` | Intervall in Sekunden | `120` / `145` |
| `SHOW_HIDE_BUTTON` | Hide-Button anzeigen | `true` |
| `WEATHER_ENABLED` | Wetter anzeigen | `true` / `false` |
| `WEATHER_LANGUAGE` | Sprache für Wetter | `de` |
| `TZ` | Zeitzone | `Europe/Berlin` |
| `PUID` / `PGID` | User/Group ID | `33` (www-data) |

## Ordnerstruktur auf NFS-Mount

```
/srv/nfs/photos/
├── 2025/
├── 2024/
├── 2023/
├── ...
├── 2010-2019/
│   ├── 2019/
│   ├── 2018/
│   └── ...
├── 2000-2009/
├── 1990-1999/
├── 1980-1989/
├── 1970-1979/
├── 1962-1969/
├── Fotoalben/
├── Sammelsurium/
└── Eltern/
```

## Ignorierte Ordner

Folgende Ordner werden automatisch ignoriert:
- Ordner mit `.twipignore` Datei
- Ordner mit "Ignorieren" oder "Privat" im Namen
- Ordner mit "Originale" oder "xcf" im Namen

## Verwaltung

```bash
# Container stoppen
docker-compose stop

# Container neu starten
docker-compose restart

# Container entfernen
docker-compose down

# Logs anzeigen
docker-compose logs -f [service-name]

# In Container einsteigen (Debug)
docker exec -it this-week-in-past sh
```

## Troubleshooting

### NFS-Mount nicht verfügbar

```bash
# Mount-Status prüfen
mount | grep /srv/nfs/photos

# NFS-Service auf Pi4 prüfen
ssh pi4 "sudo systemctl status nfs-server"

# Mount neu laden
sudo umount /srv/nfs/photos
sudo mount -a
```

### Container startet nicht

```bash
# Logs prüfen
docker-compose logs

# Berechtigungen prüfen
ls -la /srv/nfs/photos

# Container neu bauen
docker-compose down
docker-compose up -d
```

### Keine Bilder werden angezeigt

1. Prüfe, ob der NFS-Mount korrekt ist
2. Prüfe die RESOURCE_PATHS in docker-compose.yml
3. Prüfe die Ordnerstruktur auf dem NFS-Mount
4. Prüfe die Container-Logs auf Fehler

## Anpassungen

### Weitere Pfade hinzufügen

Bearbeite `RESOURCE_PATHS` in der docker-compose.yml:

```yaml
RESOURCE_PATHS: /resources/2025,/resources/2024,/resources/neuer-ordner
```

### Slideshow-Intervall ändern

```yaml
SLIDESHOW_INTERVAL: 180  # 3 Minuten
```

### Wetter deaktivieren

```yaml
WEATHER_ENABLED: false
```

## Links

- **Projekt-Repository**: https://github.com/rouhim/this-week-in-past
- **Docker Hub**: https://hub.docker.com/r/rouhim/this-week-in-past
- **Dokumentation**: https://github.com/rouhim/this-week-in-past/blob/main/README.md

## Basiert auf

Diese Konfiguration basiert auf der Pi4-Setup aus `docker-compose-Pi4-NEW.yaml` und wurde für den Pi5 mit NFS-Mount angepasst.