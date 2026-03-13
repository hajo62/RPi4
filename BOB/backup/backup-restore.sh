#!/bin/bash
# ============================================
# Wiederherstellungs-Skript für Backups
# ============================================
# Stellt verschlüsselte Backups wieder her
#
# Verwendung:
#   ./backup-restore.sh sensitive-2026-02-22.tar.gz.gpg
#   ./backup-restore.sh sensitive-2026-02-22.tar.gz.gpg --preview  # Nur anzeigen
# ============================================

set -e

# Konfiguration
BACKUP_DIR="/home/hajo/backups/sensitive"
PASSWORD_FILE="/home/hajo/.backup-password"

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Hilfe anzeigen
show_help() {
    echo "Verwendung: $0 <backup-datei> [--preview]"
    echo ""
    echo "Optionen:"
    echo "  --preview    Zeigt nur den Inhalt des Backups an (keine Wiederherstellung)"
    echo ""
    echo "Beispiele:"
    echo "  $0 sensitive-2026-02-22.tar.gz.gpg"
    echo "  $0 sensitive-2026-02-22.tar.gz.gpg --preview"
    echo ""
    echo "Verfügbare Backups:"
    ls -lh "$BACKUP_DIR"/sensitive-*.tar.gz.gpg 2>/dev/null || echo "  Keine Backups gefunden"
}

# Parameter prüfen
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

BACKUP_FILE="$1"
PREVIEW_MODE=false

if [ "$2" == "--preview" ]; then
    PREVIEW_MODE=true
fi

# Backup-Datei suchen
if [ ! -f "$BACKUP_FILE" ]; then
    # Versuche im Backup-Verzeichnis zu finden
    if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
    else
        echo -e "${RED}FEHLER: Backup-Datei nicht gefunden: $BACKUP_FILE${NC}"
        echo ""
        show_help
        exit 1
    fi
fi

# Passwort-Datei prüfen
if [ ! -f "$PASSWORD_FILE" ]; then
    echo -e "${RED}FEHLER: Passwort-Datei nicht gefunden: $PASSWORD_FILE${NC}"
    echo "Ohne Passwort kann das Backup nicht entschlüsselt werden!"
    exit 1
fi

echo -e "${GREEN}=== Backup-Wiederherstellung ===${NC}"
echo "Backup-Datei: $BACKUP_FILE"
echo "Größe: $(du -h "$BACKUP_FILE" | cut -f1)"
echo ""

# Preview-Modus
if [ "$PREVIEW_MODE" = true ]; then
    echo -e "${YELLOW}=== Backup-Inhalt (Preview) ===${NC}"
    gpg --batch --passphrase-file "$PASSWORD_FILE" --decrypt "$BACKUP_FILE" | tar -tzf -
    echo ""
    echo -e "${GREEN}Preview abgeschlossen${NC}"
    exit 0
fi

# Sicherheitsabfrage
echo -e "${YELLOW}WARNUNG: Diese Aktion überschreibt existierende Dateien!${NC}"
echo -n "Möchten Sie fortfahren? (yes/no): "
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Wiederherstellung abgebrochen"
    exit 0
fi

# Backup entschlüsseln und extrahieren
echo ""
echo -e "${GREEN}Entschlüssele und extrahiere Backup...${NC}"

gpg --batch --passphrase-file "$PASSWORD_FILE" --decrypt "$BACKUP_FILE" | tar -xzvf - -C /

echo ""
echo -e "${GREEN}=== Wiederherstellung abgeschlossen ===${NC}"
echo ""
echo "Nächste Schritte:"
echo "1. Docker-Container neu starten: docker compose restart"
echo "2. Berechtigungen prüfen: ls -la /home/hajo/docker-volumes/"
echo "3. Services testen"

# Made with Bob
