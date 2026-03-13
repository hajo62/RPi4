#!/bin/bash
# ============================================
# Backup-Skript für sensible Daten (verschlüsselt)
# ============================================
# Sichert alle sensiblen Daten (Datenbanken, .env, etc.)
# in verschlüsselten Tar-Archiven
#
# Verwendung:
#   ./backup-sensitive.sh
#
# Cronjob (täglich um 3:30 Uhr):
#   30 3 * * * /home/hajo/backup-sensitive.sh >> /var/log/backup-sensitive.log 2>&1
#
# Wiederherstellung:
#   gpg --decrypt sensitive-2026-02-22.tar.gz.gpg | tar -xzf - -C /
# ============================================

set -e  # Bei Fehler abbrechen

# Konfiguration
PROJECT_DIR="/home/hajo"
BACKUP_DIR="/home/hajo/backups/sensitive"
LOG_FILE="/var/log/backup-sensitive.log"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
RETENTION_DAYS=30

# Passwort-Datei (WICHTIG: Sicher aufbewahren!)
# Alternative: Passwort interaktiv eingeben oder aus Umgebungsvariable
PASSWORD_FILE="/home/hajo/.backup-password"

# Zu sichernde Verzeichnisse und Dateien
BACKUP_SOURCES=(
    "$PROJECT_DIR/docker/signal-cli-rest-api/data"
    "$PROJECT_DIR/docker/signal-cli-rest-api/.env"
    "$PROJECT_DIR/docker/signal-cli-rest-api/avatars"
    "$PROJECT_DIR/docker/whats-up-docker/data"
    "$PROJECT_DIR/docker/whats-up-docker/.env"
    "$PROJECT_DIR/docker/ionos-dyndns/data"
    "$PROJECT_DIR/docker/ionos-dyndns/.env"
    "$PROJECT_DIR/docker/this-week-in-past/.env"
)

# Logging-Funktion
log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

log "=== Starte Sensible-Daten-Backup ==="

# Prüfen ob GPG installiert ist
if ! command -v gpg &> /dev/null; then
    log "FEHLER: GPG ist nicht installiert!"
    log "Installation: sudo apt install gnupg"
    exit 1
fi

# Backup-Verzeichnis erstellen
mkdir -p "$BACKUP_DIR"

# Prüfen ob Passwort-Datei existiert
if [ ! -f "$PASSWORD_FILE" ]; then
    log "WARNUNG: Passwort-Datei nicht gefunden: $PASSWORD_FILE"
    log "Erstelle Passwort-Datei mit Zufallspasswort..."
    
    # Zufallspasswort generieren (32 Zeichen)
    openssl rand -base64 32 > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    
    log "WICHTIG: Passwort gespeichert in: $PASSWORD_FILE"
    log "WICHTIG: Sichere diese Datei an einem sicheren Ort!"
    log "WICHTIG: Ohne dieses Passwort können Backups NICHT wiederhergestellt werden!"
fi

# Temporäres Tar-Archiv erstellen
TEMP_TAR="/tmp/backup-sensitive-$DATE.tar.gz"
log "Erstelle Tar-Archiv..."

# Tar-Archiv erstellen (nur existierende Dateien)
EXISTING_SOURCES=()
for source in "${BACKUP_SOURCES[@]}"; do
    if [ -e "$source" ]; then
        EXISTING_SOURCES+=("$source")
    else
        log "WARNUNG: Quelle nicht gefunden: $source"
    fi
done

if [ ${#EXISTING_SOURCES[@]} -eq 0 ]; then
    log "FEHLER: Keine zu sichernden Dateien gefunden!"
    exit 1
fi

tar -czf "$TEMP_TAR" "${EXISTING_SOURCES[@]}" 2>&1 | tee -a "$LOG_FILE"

# Größe des Tar-Archivs
TAR_SIZE=$(du -h "$TEMP_TAR" | cut -f1)
log "Tar-Archiv erstellt: $TAR_SIZE"

# Verschlüsseln mit GPG
ENCRYPTED_FILE="$BACKUP_DIR/sensitive-$DATE.tar.gz.gpg"
log "Verschlüssele Backup..."

gpg --batch --yes \
    --passphrase-file "$PASSWORD_FILE" \
    --symmetric \
    --cipher-algo AES256 \
    --output "$ENCRYPTED_FILE" \
    "$TEMP_TAR" 2>&1 | tee -a "$LOG_FILE"

# Temporäres Tar-Archiv löschen
rm -f "$TEMP_TAR"

# Größe des verschlüsselten Backups
ENCRYPTED_SIZE=$(du -h "$ENCRYPTED_FILE" | cut -f1)
log "Verschlüsseltes Backup erstellt: $ENCRYPTED_SIZE"

# Backup-Integrität prüfen
log "Prüfe Backup-Integrität..."
if gpg --batch --passphrase-file "$PASSWORD_FILE" --decrypt "$ENCRYPTED_FILE" | tar -tzf - > /dev/null 2>&1; then
    log "✓ Backup-Integrität OK"
else
    log "✗ FEHLER: Backup-Integrität fehlgeschlagen!"
    exit 1
fi

# Alte Backups löschen
log "Lösche alte Backups (älter als $RETENTION_DAYS Tage)..."
DELETED_COUNT=$(find "$BACKUP_DIR" -name "sensitive-*.tar.gz.gpg" -mtime +$RETENTION_DAYS -delete -print | wc -l)
log "Gelöscht: $DELETED_COUNT alte Backups"

# Backup-Übersicht
log "=== Backup-Übersicht ==="
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "sensitive-*.tar.gz.gpg" | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log "Anzahl Backups: $BACKUP_COUNT"
log "Gesamtgröße: $TOTAL_SIZE"

log "=== Sensible-Daten-Backup abgeschlossen ==="
log "Backup gespeichert: $ENCRYPTED_FILE"
echo ""

# Optional: Backup auf externe Festplatte kopieren
# Uncomment wenn externe Festplatte gemountet ist
# EXTERNAL_BACKUP="/mnt/external/backups/pi5"
# if [ -d "$EXTERNAL_BACKUP" ]; then
#     log "Kopiere Backup auf externe Festplatte..."
#     cp "$ENCRYPTED_FILE" "$EXTERNAL_BACKUP/"
#     log "✓ Externe Kopie erstellt"
# fi

# Made with Bob
