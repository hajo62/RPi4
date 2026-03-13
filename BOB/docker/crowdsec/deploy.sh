#!/bin/bash
# ============================================
# CrowdSec Deployment-Skript für Pi5
# ============================================
#
# Dieses Skript kopiert alle notwendigen Dateien
# auf den Pi5 und startet die Installation.
#
# Verwendung:
#   chmod +x deploy.sh
#   ./deploy.sh
#
# ============================================

set -e  # Bei Fehler abbrechen

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Konfiguration
PI5_USER="hajo"
PI5_HOST="192.168.178.55"
PI5_PATH="/home/hajo/docker/crowdsec"
LOCAL_PATH="docker/crowdsec"

# Funktionen
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header "CrowdSec Deployment auf Pi5"

# 1. Prüfe ob lokale Dateien existieren
print_info "Prüfe lokale Dateien..."

if [ ! -f "$LOCAL_PATH/docker-compose.yml" ]; then
    print_error "docker-compose.yml nicht gefunden!"
    print_info "Bitte im Hauptverzeichnis des Projekts ausführen"
    exit 1
fi

if [ ! -f "$LOCAL_PATH/.env.example" ]; then
    print_error ".env.example nicht gefunden!"
    exit 1
fi

if [ ! -f "$LOCAL_PATH/install.sh" ]; then
    print_error "install.sh nicht gefunden!"
    exit 1
fi

print_success "Alle lokalen Dateien gefunden"

# 2. Prüfe SSH-Verbindung
print_info "Prüfe SSH-Verbindung zu $PI5_USER@$PI5_HOST..."

if ! ssh -o ConnectTimeout=5 -o BatchMode=yes $PI5_USER@$PI5_HOST exit 2>/dev/null; then
    print_error "SSH-Verbindung fehlgeschlagen!"
    print_info "Prüfe:"
    print_info "  - Ist der Pi5 erreichbar? (ping $PI5_HOST)"
    print_info "  - Sind SSH-Keys eingerichtet?"
    print_info "  - Ist der Hostname/IP korrekt?"
    exit 1
fi

print_success "SSH-Verbindung erfolgreich"

# 3. Erstelle Verzeichnis auf Pi5
print_info "Erstelle Verzeichnis auf Pi5..."
ssh $PI5_USER@$PI5_HOST "mkdir -p $PI5_PATH"
print_success "Verzeichnis erstellt"

# 4. Kopiere Dateien
print_info "Kopiere Dateien auf Pi5..."

# Notwendige Dateien
scp -q $LOCAL_PATH/docker-compose.yml $PI5_USER@$PI5_HOST:$PI5_PATH/
scp -q $LOCAL_PATH/.env.example $PI5_USER@$PI5_HOST:$PI5_PATH/
scp -q $LOCAL_PATH/.gitignore $PI5_USER@$PI5_HOST:$PI5_PATH/
scp -q $LOCAL_PATH/install.sh $PI5_USER@$PI5_HOST:$PI5_PATH/

# Dokumentation (optional, aber empfohlen)
if [ -f "$LOCAL_PATH/README.md" ]; then
    scp -q $LOCAL_PATH/README.md $PI5_USER@$PI5_HOST:$PI5_PATH/
fi

if [ -f "$LOCAL_PATH/QUICKSTART.md" ]; then
    scp -q $LOCAL_PATH/QUICKSTART.md $PI5_USER@$PI5_HOST:$PI5_PATH/
fi

if [ -f "$LOCAL_PATH/INTEGRATION.md" ]; then
    scp -q $LOCAL_PATH/INTEGRATION.md $PI5_USER@$PI5_HOST:$PI5_PATH/
fi

if [ -f "$LOCAL_PATH/DEPLOYMENT.md" ]; then
    scp -q $LOCAL_PATH/DEPLOYMENT.md $PI5_USER@$PI5_HOST:$PI5_PATH/
fi

print_success "Dateien kopiert"

# 5. Setze Ausführungsrechte
print_info "Setze Ausführungsrechte..."
ssh $PI5_USER@$PI5_HOST "chmod +x $PI5_PATH/install.sh"
print_success "Ausführungsrechte gesetzt"

# 6. Zeige nächste Schritte
print_header "Deployment abgeschlossen"

print_success "Alle Dateien wurden erfolgreich auf den Pi5 kopiert!"
echo ""
print_info "Nächste Schritte:"
echo ""
echo "  1. Verbinde dich mit dem Pi5:"
echo "     ${GREEN}ssh $PI5_USER@$PI5_HOST${NC}"
echo ""
echo "  2. Wechsle ins CrowdSec-Verzeichnis:"
echo "     ${GREEN}cd $PI5_PATH${NC}"
echo ""
echo "  3. Starte die Installation:"
echo "     ${GREEN}sudo ./install.sh${NC}"
echo ""
print_info "Oder alles in einem Befehl:"
echo "  ${GREEN}ssh -t $PI5_USER@$PI5_HOST 'cd $PI5_PATH && sudo ./install.sh'${NC}"
echo ""

# 7. Frage ob Installation direkt gestartet werden soll
read -p "Möchtest du die Installation jetzt starten? (j/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Jj]$ ]]; then
    print_info "Starte Installation auf Pi5..."
    ssh -t $PI5_USER@$PI5_HOST "cd $PI5_PATH && sudo ./install.sh"
else
    print_info "Installation übersprungen. Starte sie später manuell."
fi

exit 0

# Made with Bob
