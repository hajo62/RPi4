#!/bin/bash
# ============================================
# Traefik Setup-Skript
# ============================================
# Automatische Einrichtung von Traefik mit CrowdSec

set -e  # Bei Fehler abbrechen

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Traefik Setup für Pi5${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# ============================================
# 1. Verzeichnisse erstellen
# ============================================
echo -e "${YELLOW}[1/6] Erstelle Verzeichnisse...${NC}"
mkdir -p letsencrypt logs
chmod 600 letsencrypt
echo -e "${GREEN}✓ Verzeichnisse erstellt${NC}"
echo ""

# ============================================
# 2. .env prüfen
# ============================================
echo -e "${YELLOW}[2/6] Prüfe .env Datei...${NC}"
if [ ! -f .env ]; then
    echo -e "${RED}✗ .env Datei nicht gefunden!${NC}"
    echo -e "${YELLOW}Kopiere .env.example nach .env und passe die Werte an:${NC}"
    echo -e "  cp .env.example .env"
    echo -e "  nano .env"
    exit 1
fi
echo -e "${GREEN}✓ .env Datei gefunden${NC}"
echo ""

# ============================================
# 3. CrowdSec API-Key prüfen
# ============================================
echo -e "${YELLOW}[3/6] Prüfe CrowdSec API-Key...${NC}"
source .env
if [ -z "$CROWDSEC_TRAEFIK_BOUNCER_API_KEY" ] || [ "$CROWDSEC_TRAEFIK_BOUNCER_API_KEY" = "your_crowdsec_api_key_here" ]; then
    echo -e "${RED}✗ CrowdSec API-Key nicht konfiguriert!${NC}"
    echo -e "${YELLOW}Generiere API-Key mit:${NC}"
    echo -e "  cd ../crowdsec"
    echo -e "  docker compose exec crowdsec cscli bouncers add traefik-bouncer"
    echo -e "  # API-Key in .env eintragen"
    exit 1
fi
echo -e "${GREEN}✓ CrowdSec API-Key konfiguriert${NC}"
echo ""

# ============================================
# 4. Dashboard Auth prüfen
# ============================================
echo -e "${YELLOW}[4/6] Prüfe Dashboard Auth...${NC}"
if [ -z "$TRAEFIK_DASHBOARD_AUTH" ] || [ "$TRAEFIK_DASHBOARD_AUTH" = "admin:\$apr1\$..." ]; then
    echo -e "${RED}✗ Dashboard Auth nicht konfiguriert!${NC}"
    echo -e "${YELLOW}Generiere Auth mit:${NC}"
    echo -e "  htpasswd -nb admin your_password"
    echo -e "  # Oder online: https://hostingcanada.org/htpasswd-generator/"
    echo -e "  # Ergebnis in .env eintragen ($ escapen mit $$)"
    exit 1
fi
echo -e "${GREEN}✓ Dashboard Auth konfiguriert${NC}"
echo ""

# ============================================
# 5. CrowdSec-Netzwerk prüfen
# ============================================
echo -e "${YELLOW}[5/6] Prüfe CrowdSec-Netzwerk...${NC}"
if ! docker network inspect crowdsec-net >/dev/null 2>&1; then
    echo -e "${RED}✗ CrowdSec-Netzwerk nicht gefunden!${NC}"
    echo -e "${YELLOW}Starte CrowdSec zuerst:${NC}"
    echo -e "  cd ../crowdsec"
    echo -e "  docker compose up -d"
    exit 1
fi
echo -e "${GREEN}✓ CrowdSec-Netzwerk gefunden${NC}"
echo ""

# ============================================
# 6. Traefik starten
# ============================================
echo -e "${YELLOW}[6/6] Starte Traefik...${NC}"
docker compose up -d

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✓ Setup abgeschlossen!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Nächste Schritte:${NC}"
echo -e "  1. Logs prüfen:     docker compose logs -f traefik"
echo -e "  2. Dashboard:       https://${TRAEFIK_DOMAIN}"
echo -e "  3. Services testen: https://${HA_DOMAIN}"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo -e "  - Logs:             docker compose logs traefik"
echo -e "  - Status:           docker compose ps"
echo -e "  - Neustart:         docker compose restart traefik"
echo ""

# Made with Bob
