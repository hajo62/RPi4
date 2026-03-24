#!/bin/bash
# ============================================
# Zentrale Logrotate-Einrichtung für Docker-Container
# ============================================
#
# Dieses Script installiert und konfiguriert logrotate für alle Docker-Container
#
# Verwendung:
#   sudo ./setup-logrotate.sh [container-name]
#   
#   Ohne Parameter: Installiert alle verfügbaren Konfigurationen
#   Mit Parameter:  Installiert nur die angegebene Konfiguration
#
# Beispiele:
#   sudo ./setup-logrotate.sh          # Alle installieren
#   sudo ./setup-logrotate.sh traefik  # Nur Traefik
#
# ============================================

set -e

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Keine Farbe

# Prüfen ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Fehler: Dieses Script muss als root ausgeführt werden (verwende sudo)${NC}"
    exit 1
fi

# Script-Verzeichnis ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGROTATE_BASE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIGS_DIR="$LOGROTATE_BASE_DIR/configs"
SYSTEM_LOGROTATE_DIR="/etc/logrotate.d"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Zentrale Logrotate-Einrichtung für Docker     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# Prüfen ob logrotate installiert ist
if ! command -v logrotate &> /dev/null; then
    echo -e "${YELLOW}Installiere logrotate...${NC}"
    apt-get update -qq
    apt-get install -y logrotate
    echo -e "${GREEN}✓ logrotate installiert${NC}\n"
else
    echo -e "${GREEN}✓ logrotate ist bereits installiert${NC}\n"
fi

# Funktion zum Installieren einer Konfiguration
install_config() {
    local config_name=$1
    local config_file="$CONFIGS_DIR/$config_name"
    local target_file="$SYSTEM_LOGROTATE_DIR/$config_name"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}✗ Konfiguration nicht gefunden: $config_file${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Installiere $config_name...${NC}"
    
    # Konfiguration kopieren
    cp "$config_file" "$target_file"
    chmod 644 "$target_file"
    
    # Konfiguration testen
    if logrotate -d "$target_file" 2>&1 | grep -qi "error"; then
        echo -e "${RED}✗ Konfigurationstest fehlgeschlagen für $config_name${NC}"
        echo -e "${YELLOW}  Führe 'logrotate -d $target_file' aus für Details${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ $config_name erfolgreich installiert${NC}"
    return 0
}

# Funktion zum Anzeigen der Konfigurationsdetails
show_config_details() {
    local config_name=$1
    local config_file="$CONFIGS_DIR/$config_name"
    
    echo -e "\n${BLUE}─────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Konfiguration: $config_name${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────${NC}"
    
    # Log-Pfad extrahieren
    local log_path=$(grep -E "^/.*\{" "$config_file" | sed 's/ {//')
    echo -e "Log-Datei:       $log_path"
    
    # Rotation extrahieren
    local rotation=$(grep -E "^\s*(daily|weekly|monthly)" "$config_file" | tr -d ' ')
    echo -e "Rotation:        ${rotation:-täglich}"
    
    # Aufbewahrung extrahieren
    local rotate=$(grep -E "^\s*rotate" "$config_file" | awk '{print $2}')
    echo -e "Aufbewahrung:    ${rotate:-28} Tage"
    
    # Komprimierung prüfen
    if grep -q "compress" "$config_file"; then
        echo -e "Komprimierung:   Ja (gzip)"
    else
        echo -e "Komprimierung:   Nein"
    fi
    
    echo -e "Konfig-Datei:    $SYSTEM_LOGROTATE_DIR/$config_name"
}

# Hauptlogik
if [ -n "$1" ]; then
    # Einzelne Konfiguration installieren
    CONTAINER_NAME=$1
    if install_config "$CONTAINER_NAME"; then
        show_config_details "$CONTAINER_NAME"
    else
        exit 1
    fi
else
    # Alle Konfigurationen installieren
    echo -e "${YELLOW}Installiere alle verfügbaren Konfigurationen...${NC}\n"
    
    success_count=0
    fail_count=0
    
    for config_file in "$CONFIGS_DIR"/*; do
        if [ -f "$config_file" ]; then
            config_name=$(basename "$config_file")
            if install_config "$config_name"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        fi
    done
    
    echo -e "\n${BLUE}─────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Erfolgreich installiert: $success_count${NC}"
    if [ $fail_count -gt 0 ]; then
        echo -e "${RED}Fehlgeschlagen: $fail_count${NC}"
    fi
    echo -e "${BLUE}─────────────────────────────────────────────${NC}\n"
    
    # Details für alle installierten Konfigurationen anzeigen
    for config_file in "$CONFIGS_DIR"/*; do
        if [ -f "$config_file" ]; then
            config_name=$(basename "$config_file")
            show_config_details "$config_name"
        fi
    done
fi

# Logrotate-Zeitplan anzeigen
echo -e "\n${BLUE}─────────────────────────────────────────────${NC}"
echo -e "${GREEN}Logrotate-Zeitplan${NC}"
echo -e "${BLUE}─────────────────────────────────────────────${NC}"

if [ -f /etc/cron.daily/logrotate ]; then
    echo -e "Logrotate läuft täglich über: ${YELLOW}/etc/cron.daily/logrotate${NC}"
elif systemctl is-active --quiet logrotate.timer 2>/dev/null; then
    echo -e "Logrotate läuft über systemd timer:"
    systemctl status logrotate.timer --no-pager 2>/dev/null | grep -E "(Active|Trigger)" || true
else
    echo -e "${YELLOW}Warnung: Konnte Logrotate-Zeitplan nicht ermitteln${NC}"
fi

# Manuelle Test-Optionen
echo -e "\n${BLUE}─────────────────────────────────────────────${NC}"
echo -e "${GREEN}Manuelles Testen${NC}"
echo -e "${BLUE}─────────────────────────────────────────────${NC}"
echo -e "Testlauf (ohne Änderungen):"
echo -e "  ${YELLOW}sudo logrotate -d /etc/logrotate.d/traefik${NC}"
echo ""
echo -e "Rotation jetzt erzwingen:"
echo -e "  ${YELLOW}sudo logrotate -f /etc/logrotate.d/traefik${NC}"
echo ""
echo -e "Status aller Rotationen anzeigen:"
echo -e "  ${YELLOW}cat /var/lib/logrotate/status${NC}"

echo -e "\n${GREEN}✓ Einrichtung abgeschlossen!${NC}"
echo -e "${YELLOW}Hinweis: Logs werden automatisch durch den täglichen Cron-Job rotiert${NC}\n"

# Made with Bob
