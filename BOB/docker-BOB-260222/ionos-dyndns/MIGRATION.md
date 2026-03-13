# Migration zur neuen State-Persistierung

## Änderungen

Die State-Persistierung wurde verbessert:

### Vorher
- State-File: `./scripts/state/prev_ipv4.txt`
- Scripts und Daten gemischt

### Nachher
- State-File: `./data/prev_ipv4.txt`
- Klare Trennung: Scripts (read-only) vs. Daten (read-write)
- Health-Check hinzugefügt
- `.gitignore` für sensitive Daten

## Migrations-Schritte

### 1. Altes State-File verschieben (falls vorhanden)

```bash
cd docker/ionos-dyndns

# State-File verschieben, falls es existiert
if [ -f scripts/state/prev_ipv4.txt ]; then
  mkdir -p data
  mv scripts/state/prev_ipv4.txt data/
  echo "✓ State-File verschoben"
else
  echo "ℹ Kein altes State-File gefunden"
fi
```

### 2. Container neu starten

```bash
# Container stoppen und entfernen
docker compose down

# Container mit neuer Konfiguration starten
docker compose up -d

# Logs prüfen
docker compose logs -f
```

### 3. Funktionalität prüfen

```bash
# Health-Check Status prüfen
docker inspect ionos-dyndns --format='{{.State.Health.Status}}'
# Sollte "healthy" anzeigen nach ~10 Sekunden

# State-File prüfen
ls -la data/prev_ipv4.txt
cat data/prev_ipv4.txt
```

## Neue Verzeichnisstruktur

```
docker/ionos-dyndns/
├── .env                    # Deine Konfiguration (nicht in Git!)
├── .env.example            # Beispiel-Konfiguration
├── .gitignore              # Schützt sensitive Daten
├── docker-compose.yml      # Aktualisiert
├── README.md
├── MIGRATION.md            # Diese Datei
├── scripts/
│   └── update_dyndns.sh    # Aktualisiert
└── data/                   # NEU - Persistente Daten
    ├── .gitkeep
    └── prev_ipv4.txt       # Wird automatisch erstellt
```

## Vorteile

✅ **Sicherheit**: Scripts sind read-only gemountet  
✅ **Persistenz**: State überlebt Container-Neustarts  
✅ **Monitoring**: Health-Check zeigt Status an  
✅ **Git-sicher**: Sensitive Daten werden nicht committed  
✅ **Struktur**: Klare Trennung von Code und Daten

## Troubleshooting

### Container startet nicht
```bash
# Logs prüfen
docker compose logs ionos-dyndns

# Berechtigungen prüfen
ls -la scripts/update_dyndns.sh
ls -la data/
```

### Health-Check schlägt fehl
```bash
# Prüfen ob State-File erstellt wurde
docker exec ionos-dyndns ls -la /app/data/

# Manuell erstellen falls nötig
docker exec ionos-dyndns touch /app/data/prev_ipv4.txt
```

### State-File wird nicht persistiert
```bash
# Volume-Mapping prüfen
docker inspect ionos-dyndns --format='{{json .Mounts}}' | jq

# Sollte zeigen:
# - ./data -> /app/data
# - ./scripts -> /app/scripts (ro)
```

## Rollback (falls nötig)

Falls Probleme auftreten, kannst du zur alten Version zurückkehren:

```bash
# Alte docker-compose.yml wiederherstellen
git checkout HEAD~1 docker-compose.yml scripts/update_dyndns.sh

# Container neu starten
docker compose down
docker compose up -d