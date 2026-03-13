#!/bin/bash
# ============================================
# CrowdSec Installations-Skript
# ============================================
#
# Dieses Skript installiert:
# - CrowdSec Container (Log-Analyse)
# - Firewall Bouncer auf dem Host (nftables-Integration)
#
# Verwendung:
#   chmod +x install.sh
#   sudo ./install.sh
#
# ============================================

set -e  # Bei Fehler abbrechen

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Root-Check
if [ "$EUID" -ne 0 ]; then 
    print_error "Bitte als root ausführen (sudo ./install.sh)"
    exit 1
fi

# Verzeichnis-Check
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    print_error "docker-compose.yml nicht gefunden!"
    print_info "Bitte im CrowdSec-Verzeichnis ausführen"
    exit 1
fi

print_header "CrowdSec Installation"

# 1. Voraussetzungen prüfen
print_info "Prüfe Voraussetzungen..."

if ! command -v docker &> /dev/null; then
    print_error "Docker ist nicht installiert!"
    exit 1
fi
print_success "Docker gefunden"

if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose ist nicht installiert!"
    exit 1
fi
print_success "Docker Compose gefunden"

if ! command -v nft &> /dev/null; then
    print_error "nftables ist nicht installiert!"
    exit 1
fi
print_success "nftables gefunden"

# 2. Verzeichnisse erstellen
print_info "Erstelle Verzeichnisse..."
mkdir -p "$SCRIPT_DIR/config"
mkdir -p "$SCRIPT_DIR/data"
mkdir -p "$SCRIPT_DIR/db"
print_success "Verzeichnisse erstellt"

# 3. .env erstellen (falls nicht vorhanden)
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    print_info "Erstelle .env Datei..."
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    print_success ".env erstellt"
else
    print_warning ".env existiert bereits (wird nicht überschrieben)"
fi

# 4. CrowdSec Container starten
print_info "Starte CrowdSec Container..."
cd "$SCRIPT_DIR"
docker compose up -d

# Warte auf CrowdSec-Start
print_info "Warte auf CrowdSec-Start (30 Sekunden)..."
sleep 30

# 5. Bouncer API Key generieren
print_info "Generiere Bouncer API Key..."

# Prüfe ob Bouncer bereits existiert
if docker compose exec -T crowdsec cscli bouncers list 2>/dev/null | grep -q "firewall-bouncer"; then
    print_warning "Bouncer 'firewall-bouncer' existiert bereits"
    API_KEY=$(docker compose exec -T crowdsec cscli bouncers list -o raw | grep firewall-bouncer | cut -d',' -f3)
else
    # Generiere neuen API Key
    API_KEY=$(docker compose exec -T crowdsec cscli bouncers add firewall-bouncer -o raw)
    
    if [ -n "$API_KEY" ]; then
        print_success "API Key generiert: $API_KEY"
    else
        print_error "API Key konnte nicht generiert werden"
        exit 1
    fi
fi

# Speichere API Key für später
echo "$API_KEY" > /tmp/crowdsec_api_key.txt

# 6. rsyslog installieren (für Log-Dateien)
print_info "Installiere rsyslog..."
if ! dpkg -l | grep -q rsyslog; then
    apt install -y rsyslog
    systemctl enable rsyslog
    systemctl start rsyslog
    print_success "rsyslog installiert und gestartet"
else
    print_warning "rsyslog bereits installiert"
fi

# Warte bis Logs geschrieben werden
sleep 5

# 7. Firewall Bouncer auf Host installieren
print_info "Installiere Firewall Bouncer auf dem Host..."

# CrowdSec Repository hinzufügen
if [ ! -f /etc/apt/sources.list.d/crowdsec_crowdsec.list ]; then
    print_info "Füge CrowdSec Repository hinzu..."
    
    # Für Debian Trixie (Testing) nutzen wir Bookworm (Stable) Repository
    # da Trixie noch nicht offiziell unterstützt wird
    DEBIAN_VERSION="bookworm"
    
    curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash
    
    # Ersetze trixie mit bookworm falls vorhanden
    if [ -f /etc/apt/sources.list.d/crowdsec_crowdsec.list ]; then
        sed -i 's/trixie/bookworm/g' /etc/apt/sources.list.d/crowdsec_crowdsec.list
    fi
    
    print_success "Repository hinzugefügt (Debian Bookworm)"
else
    print_warning "CrowdSec Repository bereits vorhanden"
fi

# Firewall Bouncer installieren
if ! dpkg -l | grep -q crowdsec-firewall-bouncer-nftables; then
    print_info "Installiere crowdsec-firewall-bouncer-nftables..."
    apt update
    apt install -y crowdsec-firewall-bouncer-nftables
    print_success "Firewall Bouncer installiert"
else
    print_warning "Firewall Bouncer bereits installiert"
fi

# Bouncer konfigurieren
print_info "Konfiguriere Firewall Bouncer..."
cat > /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml << EOF
# CrowdSec API Verbindung
api_url: http://localhost:8080
api_key: $API_KEY

# Firewall-Modus
mode: nftables

# nftables Konfiguration
nftables:
  ipv4:
    enabled: true
    set-only: false
    table: crowdsec
    chain: crowdsec-chain
  ipv6:
    enabled: true
    set-only: false
    table: crowdsec6
    chain: crowdsec6-chain

# Blacklist-Modus
blacklists_ipv4: crowdsec-blacklists
blacklists_ipv6: crowdsec6-blacklists

# Update-Intervall (mit Zeiteinheit!)
update_frequency: 10s

# Log-Einstellungen
log_mode: file
log_dir: /var/log/
log_level: info
log_compression: true
log_max_size: 40
log_max_backups: 3
log_max_age: 30

# Prometheus Metrics
prometheus:
  enabled: false
  listen_addr: 127.0.0.1
  listen_port: 60601
EOF

print_success "Firewall Bouncer konfiguriert"

# Bouncer starten
print_info "Starte Firewall Bouncer..."
systemctl enable crowdsec-firewall-bouncer
systemctl start crowdsec-firewall-bouncer
sleep 5
print_success "Firewall Bouncer gestartet"

# 8. acquis.yaml konfigurieren (Log-Quellen)
print_info "Konfiguriere Log-Quellen..."
docker compose exec -T crowdsec bash -c 'cat > /etc/crowdsec/acquis.yaml << EOF
filenames:
  - /var/log/auth.log
  - /var/log/syslog
labels:
  type: syslog
EOF'
print_success "Log-Quellen konfiguriert"

# 9. Whitelist konfigurieren
print_info "Konfiguriere Whitelist..."

# Whitelist-Parser installieren
docker compose exec -T crowdsec cscli parsers install crowdsecurity/whitelists

# Whitelist-Datei erstellen
docker compose exec -T crowdsec bash -c 'cat > /etc/crowdsec/parsers/s02-enrich/whitelists.yaml << EOF
name: crowdsecurity/whitelists
description: "Whitelist für vertrauenswürdige IPs"
whitelist:
  reason: "Trusted local network and known IPs"
  ip:
    # Lokales Netzwerk
    - "192.168.178.0/24"
    
    # Loopback
    - "127.0.0.1"
    - "::1"
    
    # Docker-Netzwerke
    - "172.20.0.0/16"
    - "172.30.0.0/16"
    
    # Pi4 Backend-Server
    - "192.168.178.3"
    - "192.168.178.33"
EOF'

# CrowdSec neu starten
docker compose restart crowdsec
sleep 5
print_success "Whitelist konfiguriert"

# 10. Installation prüfen
print_header "Installation prüfen"

# CrowdSec Container-Status
print_info "CrowdSec Container-Status:"
docker compose ps

# Bouncer-Verbindung
print_info "\nBouncer-Status (im Container):"
docker compose exec -T crowdsec cscli bouncers list

# Firewall Bouncer Service
print_info "\nFirewall Bouncer Service-Status:"
systemctl status crowdsec-firewall-bouncer --no-pager

# nftables-Tabelle
print_info "\nnftables CrowdSec-Tabelle:"
if nft list table ip crowdsec &> /dev/null; then
    nft list table ip crowdsec
    print_success "nftables-Integration erfolgreich"
else
    print_error "nftables-Tabelle nicht gefunden!"
    print_info "Prüfe Bouncer-Logs:"
    journalctl -u crowdsec-firewall-bouncer -n 20 --no-pager
fi

# 11. Funktionstest
print_header "Funktionstest"

print_info "Blockiere Test-IP 1.2.3.4 für 2 Minuten..."
docker compose exec -T crowdsec cscli decisions add --ip 1.2.3.4 --duration 2m --reason "Installation test"

sleep 2

print_info "Prüfe ob IP in nftables blockiert ist..."
if nft list set ip crowdsec crowdsec-blacklists 2>/dev/null | grep -q "1.2.3.4"; then
    print_success "Test-IP erfolgreich blockiert!"
else
    print_error "Test-IP nicht in nftables gefunden!"
fi

print_info "Entferne Test-IP..."
docker compose exec -T crowdsec cscli decisions delete --ip 1.2.3.4
print_success "Test-IP entfernt"

# 12. Zusammenfassung
print_header "Installation abgeschlossen"

print_success "CrowdSec wurde erfolgreich installiert!"
echo ""
print_info "Komponenten:"
echo "  ✓ CrowdSec Container (Log-Analyse)"
echo "  ✓ Firewall Bouncer auf Host (nftables-Integration)"
echo ""
print_info "Wichtige Befehle:"
echo ""
echo "  CrowdSec (Container):"
echo "    docker compose ps                                    # Status"
echo "    docker compose logs -f                               # Logs"
echo "    docker compose exec crowdsec cscli decisions list    # Geblockte IPs"
echo "    docker compose exec crowdsec cscli alerts list       # Alerts"
echo ""
echo "  Firewall Bouncer (Host):"
echo "    sudo systemctl status crowdsec-firewall-bouncer      # Status"
echo "    sudo journalctl -u crowdsec-firewall-bouncer -f      # Logs"
echo ""
echo "  nftables:"
echo "    sudo nft list table ip crowdsec                      # CrowdSec-Tabelle"
echo "    sudo nft list set ip crowdsec crowdsec-blacklists    # Geblockte IPs"
echo ""
print_info "Dokumentation:"
echo "  README.md                      - Vollständige Anleitung"
echo "  INSTALLATION-HOST-BOUNCER.md   - Bouncer-Details"
echo "  INTEGRATION.md                 - Firewall-Integration"
echo ""
print_warning "Wichtig:"
echo "  - Überwache die Logs in den ersten 24 Stunden"
echo "  - Prüfe regelmäßig auf False Positives"
echo "  - Passe die Whitelist bei Bedarf an"
echo ""
print_info "Nächste Schritte:"
echo "  1. Traefik-Logs einbinden (siehe README.md)"
echo "  2. Community-Intelligence aktivieren (optional)"
echo "  3. Weitere Collections installieren (optional)"
echo ""

# Cleanup
rm -f /tmp/crowdsec_api_key.txt

exit 0

# Made with Bob
