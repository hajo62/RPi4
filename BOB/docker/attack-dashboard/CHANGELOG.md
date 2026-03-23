# Attack Dashboard - Changelog

## 2026-03-23 - Logrotate-Kompatibilität

### Geändert
- **`_find_rotated_logs()` Funktion erweitert** (server.py, Zeile 243-268)
  - Unterstützt jetzt beide Logrotate-Formate:
    1. Nummeriert: `access.json.1`, `access.json.2.gz` (Standard)
    2. Datiert: `access.json-20260323.gz` (mit `dateext` Option)
  - Sortierung nach Datei-Änderungszeit statt Namens-Parsing (robuster)

### Warum?
- Traefik verwendet jetzt Logrotate mit monatlicher Rotation und Datumsformat
- Dashboard muss rotierte Logs lesen können, um 7-Tage-Historie anzuzeigen
- Ohne diese Änderung würde das Dashboard nach der ersten Rotation nur noch den aktuellen Monat anzeigen

### Test
Nach der Änderung:
```bash
# Dashboard neu starten
cd /home/hajo/docker/attack-dashboard
docker compose restart

# Logs prüfen - sollte rotierte Dateien finden
docker compose logs attack-dashboard | grep "rotierte Datei"
```

### Kompatibilität
- ✅ Abwärtskompatibel mit altem nummeriertem Format
- ✅ Funktioniert mit neuem Datumsformat
- ✅ Keine Breaking Changes