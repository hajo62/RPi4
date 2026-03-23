# Traefik Log-Rotation

## 📍 Zentrale Konfiguration

Die Logrotate-Konfiguration für Traefik befindet sich im **zentralen Logrotate-Verzeichnis**:

```
/home/hajo/BOB/logrotate/
├── configs/traefik          # Logrotate-Konfiguration
├── scripts/setup-logrotate.sh  # Installations-Script
└── README.md                # Ausführliche Dokumentation
```

## 🚀 Schnellstart

### Installation

```bash
cd /home/hajo/BOB/logrotate
sudo ./scripts/setup-logrotate.sh traefik
```

### Testen

```bash
# Testlauf (ohne Änderungen)
sudo logrotate -d /etc/logrotate.d/traefik

# Rotation jetzt erzwingen
sudo logrotate -f /etc/logrotate.d/traefik
```

## ⚙️ Konfiguration

- **Log-Datei**: `/home/hajo/docker/traefik/logs/access.json`
- **Rotation**: Monatlich (alle 4 Wochen, automatisch via Cron)
- **Aufbewahrung**: 1 alte Log-Datei (= 2 Monate Historie gesamt)
- **Komprimierung**: Ja (gzip, sofort)
- **Format**: `access.json-YYYYMMDD.gz`

## 📊 Beispiel

Nach 2 Monaten sieht das Log-Verzeichnis so aus:

```
logs/
├── access.json              # Aktueller Monat (unkomprimiert)
└── access.json-20260213.gz  # Letzter Monat (komprimiert)
```

**Einfach und übersichtlich!** Nur 2 Dateien, minimale Disk-Nutzung.

## 🔍 Logs durchsuchen

```bash
# Aktuelles Log (aktueller Monat)
cat logs/access.json | jq .

# Altes Log (letzter Monat, komprimiert)
zcat logs/access.json-*.gz | jq .

# Nach IP im alten Log suchen
zgrep "192.168.178" logs/access.json-*.gz
```

## 📚 Weitere Informationen

Siehe die ausführliche Dokumentation im zentralen Logrotate-Verzeichnis:

```bash
cat /home/hajo/BOB/logrotate/README.md
```

---

**Hinweis**: Diese Konfiguration ist Teil der zentralen Logrotate-Verwaltung für alle Docker-Container.