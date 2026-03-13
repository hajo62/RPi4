#!/bin/bash
# ============================================
# Backup-Skript für Konfigurationsdateien (Git)
# ============================================
# Sichert alle Konfigurationsdateien in Git
# Sensible Daten werden durch .gitignore ausgeschlossen
#
# Verwendung:
#   ./backup-config.sh
#
# Cronjob (täglich um 3:00 Uhr):
#   0 3 * * * /home/hajo/backup-config.sh >> /var/log/backup-config.log 2>&1
# ============================================

set -e  # Bei Fehler abbrechen

# Konfiguration
PROJECT_DIR="/home/hajo"
LOG_FILE="/var/log/backup-config.log"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Logging-Funktion
log() {
    echo "[$DATE] $1" | tee -a "$LOG_FILE"
}

log "=== Starte Konfigurations-Backup ==="

# Prüfen ob Git installiert ist
if ! command -v git &> /dev/null; then
    log "FEHLER: Git ist nicht installiert!"
    log "Installation: sudo apt install git"
    exit 1
fi

# Ins Projekt-Verzeichnis wechseln
cd "$PROJECT_DIR" || {
    log "FEHLER: Verzeichnis $PROJECT_DIR nicht gefunden!"
    exit 1
}

# Git initialisieren (falls noch nicht geschehen)
if [ ! -d ".git" ]; then
    log "Initialisiere Git-Repository..."
    git init -b main
    git config user.name "Hans-Joachim"
    git config user.email "hajo62@gmail.com"
fi

# Änderungen hinzufügen
log "Füge Änderungen hinzu..."
git add -A

# Prüfen ob es Änderungen gibt
if git diff --cached --quiet; then
    log "Keine Änderungen gefunden - Backup übersprungen"
    exit 0
fi

# Commit erstellen
COMMIT_MSG="Auto-Backup $(date +%Y-%m-%d_%H:%M:%S)"
log "Erstelle Commit: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"

# Anzahl der Commits anzeigen
COMMIT_COUNT=$(git rev-list --count HEAD)
log "Backup erfolgreich! Gesamt-Commits: $COMMIT_COUNT"

# Optional: Push zu Remote (falls konfiguriert)
if git remote get-url origin &> /dev/null; then
    log "Pushe zu Remote-Repository..."
    if git push origin main 2>&1 | tee -a "$LOG_FILE"; then
        log "Remote-Push erfolgreich"
    else
        log "WARNUNG: Remote-Push fehlgeschlagen (wird beim nächsten Mal erneut versucht)"
    fi
fi

log "=== Konfigurations-Backup abgeschlossen ==="
echo ""

# Made with Bob
