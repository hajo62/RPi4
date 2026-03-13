# 🔐 Backup-System für BOB-Projekt

Vollständiges Backup-System mit Git-Versionierung für Konfiguration und verschlüsselten Backups für sensible Daten.

## 📋 Übersicht

### Zwei-Stufen-Backup-Strategie

1. **Git-Backup** (`backup/backup-config.sh`)
   - Gesamtes `/home/hajo` Verzeichnis
   - Konfigurationsdateien (docker-compose.yml, Scripts, Dokumentation)
   - Versionskontrolle mit vollständiger Historie
   - Optional: Push zu GitHub/GitLab

2. **Verschlüsseltes Backup** (`backup/backup-sensitive.sh`)
   - Sensible Daten (Datenbanken, .env, Avatare)
   - AES256-Verschlüsselung mit GPG
   - Automatische Rotation (30 Tage)

## 🚀 Installation auf Pi5

### 1. Skripte und .gitignore auf Pi5 kopieren

```bash
# Auf deinem Mac (im BOB-Verzeichnis)
scp backup-*.sh BACKUP-README.md .gitignore hajo@pi5:/home/hajo/

# Backup-Verzeichnis erstellen und Dateien verschieben
ssh hajo@pi5
mkdir -p /home/hajo/backup
mv /home/hajo/backup-*.sh /home/hajo/BACKUP-README.md /home/hajo/backup/
chmod +x /home/hajo/backup/backup-*.sh
```

### 2. Abhängigkeiten installieren

```bash
# Git (für Konfigurations-Backup)
sudo apt update
sudo apt install git

# GPG (für verschlüsselte Backups)
sudo apt install gnupg

# Optional: OpenSSL (für Passwort-Generierung)
sudo apt install openssl
```

### 3. Verzeichnisse erstellen

```bash
# Backup-Verzeichnis
mkdir -p /home/hajo/backups/sensitive

# Log-Verzeichnis
sudo mkdir -p /var/log
sudo touch /var/log/backup-config.log
sudo touch /var/log/backup-sensitive.log
sudo chown hajo:hajo /var/log/backup-*.log
```

### 4. Git-Repository initialisieren

```bash
cd /home/hajo

# Git initialisieren mit 'main' als Standard-Branch
git init -b main

# Oder: Git-Konfiguration global setzen (empfohlen)
git config --global init.defaultBranch main

# Benutzer konfigurieren
git config user.name "Hans-Joachim"
git config user.email "hajo62@gmail.com"

# .gitignore ist bereits vorhanden
# Ersten Commit erstellen
git add -A
git commit -m "Initial backup"
```

### 5. Optional: Remote-Repository einrichten

```bash
# GitHub/GitLab Repository erstellen, dann:
cd /home/hajo
git remote add origin https://github.com/DEIN-USERNAME/pi5-backup.git
git push -u origin main
```

## 📅 Automatisierung mit Cron

### Crontab bearbeiten

```bash
crontab -e
```

### Cron-Jobs hinzufügen

```cron
# Konfigurations-Backup (täglich um 3:00 Uhr)
0 3 * * * /home/hajo/backup/backup-config.sh >> /var/log/backup-config.log 2>&1

# Sensible-Daten-Backup (täglich um 3:30 Uhr)
30 3 * * * /home/hajo/backup/backup-sensitive.sh >> /var/log/backup-sensitive.log 2>&1

# Wöchentlicher Backup-Report (Sonntag 8:00 Uhr)
0 8 * * 0 /home/hajo/backup/backup-report.sh
```

## 🔧 Verwendung

### Manuelles Backup erstellen

```bash
# Konfigurations-Backup
/home/hajo/backup/backup-config.sh

# Sensible-Daten-Backup
/home/hajo/backup/backup-sensitive.sh
```

### Backup wiederherstellen

```bash
# Backup-Inhalt anzeigen (Preview)
/home/hajo/backup/backup-restore.sh sensitive-2026-02-22.tar.gz.gpg --preview

# Backup wiederherstellen
/home/hajo/backup/backup-restore.sh sensitive-2026-02-22.tar.gz.gpg
```

### Verfügbare Backups anzeigen

```bash
# Sensible-Daten-Backups
ls -lh /home/hajo/backups/sensitive/

# Git-Historie
cd /home/hajo
git log --oneline --graph --all
```

## 🔐 Sicherheit

### Passwort-Datei

Das Verschlüsselungs-Passwort wird automatisch generiert und gespeichert in:
```
/home/hajo/.backup-password
```

**WICHTIG:**
- ⚠️ Diese Datei ist **essentiell** für die Wiederherstellung!
- ⚠️ Sichere diese Datei an einem **sicheren Ort** (USB-Stick, Passwort-Manager)
- ⚠️ Ohne diese Datei können Backups **NICHT** wiederhergestellt werden!

### Passwort sichern

```bash
# Passwort anzeigen
cat /home/hajo/.backup-password

# Passwort auf USB-Stick kopieren
cp /home/hajo/.backup-password /media/usb-stick/

# Passwort in Passwort-Manager speichern
cat /home/hajo/.backup-password
# → Kopiere den Inhalt in deinen Passwort-Manager
```

## 📊 Was wird gesichert?

### Git-Backup (Konfiguration)

✅ **Gesichert** (gesamtes `/home/hajo`):
- `docker-compose.yml`
- `docker/*/docker-compose.yml`
- `docker/*/scripts/`
- `docker/*/README.md`
- `.gitignore`, `.gitkeep`
- Dokumentation (*.md)
- `backup/` Verzeichnis mit Skripten
- Zukünftige Konfigurationsdateien im Home-Verzeichnis

❌ **Nicht gesichert** (via .gitignore):
- `.env` Dateien
- `data/` Verzeichnisse
- `avatars/` Verzeichnisse
- Log-Dateien
- `.backup-password`
- `backups/` Verzeichnis
- `.ssh/` Verzeichnis

### Verschlüsseltes Backup (Sensible Daten)

✅ **Gesichert:**
- `/home/hajo/docker/signal-cli-rest-api/data/`
- `/home/hajo/docker/signal-cli-rest-api/.env`
- `/home/hajo/docker/signal-cli-rest-api/avatars/`
- `/home/hajo/docker/whats-up-docker/data/`
- `/home/hajo/docker/whats-up-docker/.env`
- `/home/hajo/docker/ionos-dyndns/data/`
- `/home/hajo/docker/ionos-dyndns/.env`
- `/home/hajo/docker/this-week-in-past/.env`

## 🔄 Backup-Rotation

### Automatische Löschung

- **Sensible-Daten-Backups**: Älter als 30 Tage werden automatisch gelöscht
- **Git-Historie**: Unbegrenzt (komprimiert gespeichert)

### Manuelle Bereinigung

```bash
# Alte Backups manuell löschen
find /home/hajo/backups/sensitive/ -name "sensitive-*.tar.gz.gpg" -mtime +60 -delete

# Git-Historie komprimieren
cd /home/hajo
git gc --aggressive --prune=now
```

## 📈 Monitoring

### Backup-Status prüfen

```bash
# Letzte Backups anzeigen
tail -n 50 /var/log/backup-config.log
tail -n 50 /var/log/backup-sensitive.log

# Backup-Größen
du -sh /home/hajo/backups/sensitive/
du -sh /home/hajo/.git/

# Anzahl Backups
ls /home/hajo/backups/sensitive/ | wc -l
```

### Backup-Report-Skript (optional)

Erstelle `/home/hajo/backup/backup-report.sh`:

```bash
#!/bin/bash
echo "=== Backup-Report $(date) ==="
echo ""
echo "Git-Commits: $(cd /home/hajo && git rev-list --count HEAD)"
echo "Git-Größe: $(du -sh /home/hajo/.git/ | cut -f1)"
echo ""
echo "Sensible-Backups: $(ls /home/hajo/backups/sensitive/ | wc -l)"
echo "Backup-Größe: $(du -sh /home/hajo/backups/sensitive/ | cut -f1)"
echo ""
echo "Letztes Konfig-Backup:"
tail -n 3 /var/log/backup-config.log
echo ""
echo "Letztes Sensible-Backup:"
tail -n 3 /var/log/backup-sensitive.log
```

## 🆘 Notfall-Wiederherstellung

### Komplette Wiederherstellung nach System-Neuinstallation

1. **System neu installieren** (RaspberryOS auf Pi5)

2. **Docker installieren**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker hajo
   ```

3. **Backup-Skripte kopieren**
   ```bash
   scp backup-restore.sh hajo@pi5:/home/hajo/
   scp .backup-password hajo@pi5:/home/hajo/
   ```

4. **Git-Repository klonen** (falls Remote vorhanden)
   ```bash
   # Klont direkt nach /home/hajo
   cd /home
   git clone https://github.com/DEIN-USERNAME/pi5-backup.git hajo
   cd hajo
   ```

5. **Sensible Daten wiederherstellen**
   ```bash
   # Backup-Datei von externer Festplatte kopieren
   cp /mnt/external/backups/sensitive-2026-02-22.tar.gz.gpg /home/hajo/
   
   # Wiederherstellen
   /home/hajo/backup/backup-restore.sh sensitive-2026-02-22.tar.gz.gpg
   ```

6. **Docker-Container starten**
   ```bash
   cd /home/hajo/docker
   docker compose up -d
   ```

## 🎯 Best Practices

### 3-2-1 Backup-Regel

✅ **3 Kopien:**
1. Original auf Pi5
2. Git-Backup (lokal + Remote)
3. Verschlüsseltes Backup

✅ **2 verschiedene Medien:**
1. SSD auf Pi5
2. Cloud (GitHub) + externe Festplatte

✅ **1 Offsite-Backup:**
- GitHub/GitLab (Konfiguration)
- Externe Festplatte an anderem Ort

### Regelmäßige Tests

```bash
# Monatlich: Wiederherstellung testen
./backup-restore.sh sensitive-$(date +%Y-%m-%d).tar.gz.gpg --preview

# Vierteljährlich: Komplette Wiederherstellung in Test-Umgebung
```

## 📞 Support

Bei Problemen:
1. Logs prüfen: `/var/log/backup-*.log`
2. Berechtigungen prüfen: `ls -la /home/hajo/`
3. Passwort-Datei prüfen: `test -f /home/hajo/.backup-password && echo "OK"`
4. Git-Status prüfen: `cd /home/hajo && git status`

## 🎯 Vorteile dieser Struktur

### Git-Repository in `/home/hajo`

✅ **Vorteile:**
- Sichert **gesamtes** Home-Verzeichnis (nicht nur Docker)
- Zukünftige Dateien automatisch erfasst
- Backup-Skripte selbst versioniert
- Dokumentation versioniert
- Einfache Wiederherstellung des kompletten Systems

✅ **Was wird zusätzlich gesichert:**
- Alle Konfigurationsdateien im Home-Verzeichnis
- Bash-Profile (`.bashrc`, `.profile`)
- Zukünftige Projekte und Scripts
- Systemkonfigurationen

### Backup-Skripte in `/home/hajo/backup/`

✅ **Vorteile:**
- Übersichtliche Organisation
- Skripte selbst werden mit Git gesichert
- Einfach zu finden und zu warten
- Dokumentation direkt dabei

---

**Erstellt:** 2026-02-23
**Für:** Raspberry Pi 5 BOB-Projekt
**Autor:** Bob