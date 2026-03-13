#!/bin/bash
# ============================================
# CrowdSec - Erweiterte Scenarios installieren
# ============================================
#
# Dieses Script installiert zusätzliche Scenarios für:
# - HTTP-Angriffe (Bad User-Agent, Crawling, Probing)
# - Nextcloud Brute-Force
# - Home Assistant Brute-Force
# - ownCloud Brute-Force
# - CVE-Schutz
# - DoS-Schutz
#
# Verwendung:
#   chmod +x install-scenarios.sh
#   ./install-scenarios.sh
#
# ============================================

set -e

echo "🛡️  CrowdSec - Erweiterte Scenarios Installation"
echo "================================================"
echo ""

# Prüfen ob CrowdSec läuft
if ! docker compose ps crowdsec | grep -q "Up"; then
    echo "❌ Fehler: CrowdSec Container läuft nicht!"
    echo "   Starte mit: docker compose up -d"
    exit 1
fi

echo "✅ CrowdSec Container läuft"
echo ""

# Funktion zum Installieren von Scenarios
install_scenario() {
    local scenario=$1
    local description=$2
    
    echo "📦 Installiere: $scenario"
    echo "   Beschreibung: $description"
    
    if docker compose exec -T crowdsec cscli scenarios install "$scenario" 2>/dev/null; then
        echo "   ✅ Erfolgreich installiert"
    else
        echo "   ⚠️  Bereits installiert oder nicht verfügbar"
    fi
    echo ""
}

# Funktion zum Installieren von Collections
install_collection() {
    local collection=$1
    local description=$2
    
    echo "📦 Installiere Collection: $collection"
    echo "   Beschreibung: $description"
    
    if docker compose exec -T crowdsec cscli collections install "$collection" 2>/dev/null; then
        echo "   ✅ Erfolgreich installiert"
    else
        echo "   ⚠️  Bereits installiert oder nicht verfügbar"
    fi
    echo ""
}

echo "🔍 HTTP-Angriffe Scenarios"
echo "=========================="
install_scenario "crowdsecurity/http-bad-user-agent" "Erkennt böse User-Agents (Bots, Scanner)"
install_scenario "crowdsecurity/http-crawl-non_statics" "Erkennt aggressive Crawler"
install_scenario "crowdsecurity/http-probing" "Erkennt Probing-Angriffe (Schwachstellen-Scans)"
install_scenario "crowdsecurity/http-sensitive-files" "Erkennt Zugriffe auf sensible Dateien (.env, .git, etc.)"
install_scenario "crowdsecurity/http-generic-bf" "Generischer HTTP Brute-Force Schutz"
install_scenario "crowdsecurity/http-dos" "DoS-Angriffe Erkennung"

echo "🏠 Home Assistant Scenarios"
echo "==========================="
install_scenario "crowdsecurity/home-assistant-bf" "Home Assistant Brute-Force Schutz"

echo "☁️  Nextcloud Scenarios"
echo "======================"
install_scenario "crowdsecurity/nextcloud-bf" "Nextcloud Brute-Force Schutz"

echo "📁 ownCloud Scenarios"
echo "===================="
# ownCloud nutzt ähnliche Patterns wie Nextcloud
install_scenario "crowdsecurity/owncloud-bf" "ownCloud Brute-Force Schutz"
# Falls nicht verfügbar, nutze Nextcloud-Scenario (kompatibel)
if ! docker compose exec -T crowdsec cscli scenarios list | grep -q "owncloud-bf"; then
    echo "   ℹ️  Hinweis: Kein dediziertes ownCloud-Scenario verfügbar"
    echo "   ℹ️  Nextcloud-Scenario ist kompatibel mit ownCloud"
fi

echo "🛡️  CVE-Schutz"
echo "============="
install_collection "crowdsecurity/http-cve" "Schutz vor bekannten HTTP CVEs"

echo "🔧 Basis-Schutz"
echo "==============="
install_scenario "crowdsecurity/http-path-traversal-probing" "Path Traversal Angriffe"
install_scenario "crowdsecurity/http-backdoors-attempts" "Backdoor-Versuche"
install_scenario "crowdsecurity/http-sqli-probing" "SQL Injection Versuche"
install_scenario "crowdsecurity/http-xss-probing" "XSS-Angriffe"

echo ""
echo "🔄 CrowdSec neu starten..."
docker compose restart crowdsec

echo ""
echo "⏳ Warte 5 Sekunden auf Neustart..."
sleep 5

echo ""
echo "📊 Installierte Scenarios:"
echo "=========================="
docker compose exec -T crowdsec cscli scenarios list | grep -E "INSTALLED|NAME" | head -20

echo ""
echo "✅ Installation abgeschlossen!"
echo ""
echo "📝 Nächste Schritte:"
echo "   1. Prüfe installierte Scenarios: docker compose exec crowdsec cscli scenarios list"
echo "   2. Überwache Alerts: docker compose exec crowdsec cscli alerts list"
echo "   3. Prüfe Decisions: docker compose exec crowdsec cscli decisions list"
echo ""
echo "💡 Tipp: Teste die Scenarios mit einem Vulnerability Scanner (z.B. nikto)"
echo ""

# Made with Bob
