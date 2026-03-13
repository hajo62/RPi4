#!/bin/bash
# ============================================
# Traefik Backup-Skript
# ============================================
# Sichert wichtige Traefik-Konfigurationen und Zertifikate

set -e

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Konfiguration
BACKUP_DIR="../../../backup/traefik"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="traefik-backup-${DATE}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Traefik Backup${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Backup-Verzeichnis erstellen
mkdir -p "${BACKUP_PATH}"

# ============================================
# 1. Konfigurationsdateien
# ============================================
echo -e "${YELLOW}[1/4] Sichere Konfigurationsdateien...${NC}"
cp -r config "${BACKUP_PATH}/"
cp docker-compose.yml "${BACKUP_PATH}/"
cp .env "${BACKUP_PATH}/"
echo -e "${GREEN}✓ Konfiguration gesichert${NC}"

# ============================================
# 2. SSL-Zertifikate
# ============================================
echo -e "${YELLOW}[2/4] Sichere SSL-Zertifikate...${NC}"
if [ -d "letsencrypt" ]; then
    cp -r letsencrypt "${BACKUP_PATH}/"
    echo -e "${GREEN}✓ Zertifikate gesichert${NC}"
else
    echo -e "${YELLOW}⚠ Keine Zertifikate gefunden${NC}"
fi

# ============================================
# 3. Logs (optional, nur letzte 100 Zeilen)
# ============================================
echo -e "${YELLOW}[3/4] Sichere Logs (Auszug)...${NC}"
if [ -d "logs" ]; then
    mkdir -p "${BACKUP_PATH}/logs"
    if [ -f "logs/traefik.log" ]; then
        tail -n 100 logs/traefik.log > "${BACKUP_PATH}/logs/traefik.log"
    fi
    if [ -f "logs/access.log" ]; then
        tail -n 100 logs/access.log > "${BACKUP_PATH}/logs/access.log"
    fi
    echo -e "${GREEN}✓ Logs gesichert${NC}"
else
    echo -e "${YELLOW}⚠ Keine Logs gefunden${NC}"
fi

# ============================================
# 4. Komprimieren
# ============================================
echo -e "${YELLOW}[4/4] Komprimiere Backup...${NC}"
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
rm -rf "${BACKUP_NAME}"
cd - > /dev/null

# Backup-Größe
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✓ Backup abgeschlossen!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Backup-Datei: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo -e "Größe:        ${BACKUP_SIZE}"
echo ""

# ============================================
# 5. Alte Backups löschen (älter als 30 Tage)
# ============================================
echo -e "${YELLOW}Lösche alte Backups (älter als 30 Tage)...${NC}"
find "${BACKUP_DIR}" -name "traefik-backup-*.tar.gz" -mtime +30 -delete
echo -e "${GREEN}✓ Alte Backups gelöscht${NC}"
echo ""

# ============================================
# 6. Backup-Liste anzeigen
# ============================================
echo -e "${YELLOW}Verfügbare Backups:${NC}"
ls -lh "${BACKUP_DIR}"/traefik-backup-*.tar.gz 2>/dev/null || echo "Keine Backups gefunden"
echo ""

# Made with Bob
