# Zentrale Logrotate-Konfiguration für Docker-Container

Dieses Verzeichnis enthält zentrale Logrotate-Konfigurationen für alle Docker-Container im System.

## 📁 Struktur

```
logrotate/
├── README.md              # Diese Datei
├── configs/               # Logrotate-Konfigurationsdateien
│   └── traefik           # Traefik Access-Log Rotation
└── scripts/               # Installations- und Verwaltungs-Scripts
    └── setup-logrotate.sh # Installations-Script
```

## 🎯 Zweck

Zentrale Verwaltung aller Logrotate-Konfigurationen für Docker-Container:
- **Einheitliche Konfiguration**: Alle Container-Logs an einem Ort verwaltet
- **Einfache Wartung**: Neue Container-Logs können einfach hinzugefügt werden
- **Konsistente Richtlinien**: Gleiche Aufbewahrungsfristen und Komprimierung

## 📋 Verfügbare Konfigurationen

### Traefik
- **Log-Datei**: `/home/hajo/docker/traefik/logs/access.json`
- **Rotation**: Monatlich (alle 4 Wochen)
- **Aufbewahrung**: 1 alte Log-Datei (= 2 Monate Historie gesamt)
- **Komprimierung**: Ja (gzip, sofort)
- **Besonderheit**: Sendet SIGUSR1 an Traefik-Container zum Wiedereröffnen der Log-Datei

## 🚀 Installation

### Alle Konfigurationen installieren

```bash
cd /home/hajo/BOB/logrotate
sudo ./scripts/setup-logrotate.sh
```

### Einzelne Konfiguration installieren

```bash
cd /home/hajo/BOB/logrotate
sudo ./scripts/setup-logrotate.sh traefik
```

## 🔧 Manuelle Installation

Falls du eine Konfiguration manuell installieren möchtest:

```bash
# Konfiguration kopieren
sudo cp configs/traefik /etc/logrotate.d/traefik

# Berechtigungen setzen
sudo chmod 644 /etc/logrotate.d/traefik

# Konfiguration testen
sudo logrotate -d /etc/logrotate.d/traefik
```

## 🧪 Testen

### Testlauf (Dry-Run)
Zeigt was passieren würde, ohne tatsächlich zu rotieren:

```bash
sudo logrotate -d /etc/logrotate.d/traefik
```

### Rotation erzwingen
Führt die Rotation sofort aus (für Tests):

```bash
sudo logrotate -f /etc/logrotate.d/traefik
```

### Status prüfen
Zeigt wann die letzte Rotation stattgefunden hat:

```bash
cat /var/lib/logrotate/status | grep traefik
```

## 📅 Zeitplan

Logrotate läuft automatisch täglich über:
- **Debian/Raspbian**: `/etc/cron.daily/logrotate` (normalerweise um 6:25 Uhr)
- **Systemd**: `logrotate.timer` (falls systemd verwendet wird)

## ➕ Neue Container hinzufügen

Um Logrotate für einen neuen Container hinzuzufügen:

1. **Konfigurationsdatei erstellen** in `configs/`:

```bash
# Beispiel: configs/nextcloud
/home/hajo/docker/nextcloud/logs/nextcloud.log {
    daily
    rotate 28
    notifempty
    missingok
    compress
    delaycompress
    create 0644 www-data www-data
    dateext
    dateformat -%Y%m%d
    dateyesterday
    
    postrotate
        docker kill --signal=SIGUSR1 nextcloud 2>/dev/null || true
    endscript
    
    sharedscripts
}
```

2. **Installation ausführen**:

```bash
sudo ./scripts/setup-logrotate.sh nextcloud
```

## 📊 Aufbewahrungsrichtlinien

### Empfohlene Aufbewahrungsfristen

| Log-Typ | Aufbewahrung | Begründung |
|---------|--------------|------------|
| Access-Logs | 1-3 Monate | Balance zwischen Historie und Disk-Nutzung |
| Error-Logs | 3-6 Monate | Längere Aufbewahrung für Fehleranalysen |
| Application-Logs | 1-2 Monate | Je nach Wichtigkeit |
| Debug-Logs | 1-2 Wochen | Nur für aktive Fehlersuche |

### Aktuelle Konfiguration: Traefik

**Warum monatliche Rotation mit 1 alter Datei?**
- ✅ Einfache Verwaltung (nur 2 Dateien: aktuell + 1 alt)
- ✅ 2 Monate Historie für Troubleshooting
- ✅ Minimale Disk-Nutzung
- ✅ Alte Datei wird sofort komprimiert (ca. 90% Platzersparnis)
- ✅ Übersichtlich und wartungsarm

**Beispiel nach 2 Monaten:**
```
logs/
├── access.json              # Aktueller Monat (unkomprimiert)
└── access.json-20260213.gz  # Letzter Monat (komprimiert)
```

## 🔍 Monitoring

### Disk-Nutzung prüfen

```bash
# Größe des Log-Verzeichnisses
du -sh /home/hajo/docker/traefik/logs/

# Detaillierte Auflistung
ls -lh /home/hajo/docker/traefik/logs/
```

### Rotierte Logs anzeigen

```bash
# Alle Log-Dateien anzeigen (sollten nur 2 sein: aktuell + 1 alt)
ls -lht /home/hajo/docker/traefik/logs/access.json*
```

### Komprimierte Logs lesen

```bash
# Altes komprimiertes Log lesen
zcat /home/hajo/docker/traefik/logs/access.json-*.gz | jq .

# Im alten Log suchen
zgrep "192.168.178" /home/hajo/docker/traefik/logs/access.json-*.gz
```

## 🛠️ Troubleshooting

### Logrotate läuft nicht

```bash
# Cron-Status prüfen
sudo systemctl status cron

# Logrotate manuell ausführen
sudo /etc/cron.daily/logrotate
```

### Konfigurationsfehler

```bash
# Syntax prüfen
sudo logrotate -d /etc/logrotate.d/traefik

# Verbose-Modus
sudo logrotate -v /etc/logrotate.d/traefik
```

### Berechtigungsprobleme

```bash
# Log-Verzeichnis-Berechtigungen prüfen
ls -ld /home/hajo/docker/traefik/logs/

# Falls nötig, Berechtigungen korrigieren
sudo chown -R root:root /home/hajo/docker/traefik/logs/
sudo chmod 755 /home/hajo/docker/traefik/logs/
```

### Traefik öffnet Log-Datei nicht neu

Das `postrotate`-Script sendet SIGUSR1 an den Traefik-Container. Falls das nicht funktioniert:

```bash
# Container-Name prüfen
docker ps | grep traefik

# Manuell Signal senden
docker kill --signal=SIGUSR1 traefik

# Alternative: Container neu starten (nicht empfohlen)
docker restart traefik
```

## 📝 Best Practices

1. **Teste immer zuerst**: Verwende `-d` (dry-run) vor der ersten Rotation
2. **Überwache Disk-Nutzung**: Prüfe regelmäßig die Log-Größen
3. **Passe Aufbewahrung an**: Je nach Disk-Platz und Anforderungen
4. **Dokumentiere Änderungen**: Halte diese README aktuell
5. **Backup wichtiger Logs**: Vor dem Löschen alter Logs

## 🔗 Weiterführende Links

- [Logrotate Man Page](https://linux.die.net/man/8/logrotate)
- [Traefik Logging Documentation](https://doc.traefik.io/traefik/observability/logs/)
- [CrowdSec Log Parsing](https://docs.crowdsec.net/docs/next/parsers/intro)

## 📄 Lizenz

Teil des BOB (Raspberry Pi) Projekts - Made with Bob

---

**Letzte Aktualisierung**: 2026-03-13