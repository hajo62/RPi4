#!/bin/bash
# ============================================
# CrowdSec Whitelist - Externe IP aktualisieren
# ============================================
#
# Liest die externe IP aus ionos-dyndns/data/status.json
# und aktualisiert die CrowdSec Whitelist.
#
# Verwendung:
#   chmod +x update-whitelist.sh
#   ./update-whitelist.sh
#
# Integration in DynDNS-Script:
#   Füge am Ende von update_dyndns.sh hinzu:
#   /home/hajo/docker/crowdsec/scripts/update-whitelist.sh
#
# ============================================

set -e

WHITELIST_FILE="/home/hajo/docker/crowdsec/config/parsers/s02-enrich/whitelists.yaml"
STATUS_FILE="/home/hajo/docker/ionos-dyndns/data/status.json"

echo "🔄 CrowdSec Whitelist Update"
echo "============================"

# Prüfe ob status.json existiert
if [ ! -f "$STATUS_FILE" ]; then
    echo "❌ Fehler: DynDNS Status-Datei nicht gefunden: $STATUS_FILE"
    echo "   Stelle sicher, dass ionos-dyndns läuft."
    exit 1
fi

# Prüfe ob Whitelist-Datei existiert
if [ ! -f "$WHITELIST_FILE" ]; then
    echo "❌ Fehler: Whitelist-Datei nicht gefunden: $WHITELIST_FILE"
    exit 1
fi

# Externe IP aus status.json lesen
EXTERNAL_IP=$(jq -r '.current_ip' "$STATUS_FILE" 2>/dev/null)

# Prüfe ob IP erfolgreich gelesen wurde
if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "null" ]; then
    echo "❌ Fehler: Konnte IP nicht aus status.json lesen"
    echo "   Prüfe ob ionos-dyndns korrekt läuft."
    exit 1
fi

# Validiere IP-Format (IPv4)
if ! echo "$EXTERNAL_IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    echo "❌ Fehler: Ungültige IP-Adresse: $EXTERNAL_IP"
    exit 1
fi

echo "✅ Externe IP aus DynDNS: $EXTERNAL_IP"

# Prüfe ob IP bereits in Whitelist ist
if grep -q -- "- \"$EXTERNAL_IP\"" "$WHITELIST_FILE"; then
    echo "ℹ️  IP ist bereits in Whitelist"
    echo "✅ Keine Änderung nötig"
    exit 0
fi

echo "🔄 Aktualisiere Whitelist..."

# Backup der aktuellen Whitelist erstellen
cp "$WHITELIST_FILE" "${WHITELIST_FILE}.backup"
echo "📦 Backup erstellt: ${WHITELIST_FILE}.backup"

# Entferne alte externe IP-Einträge (alle Zeilen zwischen "# Externe IP" und nächster Leerzeile)
sed -i '/# Externe IP (dynamisch/,/^$/{ /# Externe IP/!d; }' "$WHITELIST_FILE"

# Füge neue externe IP hinzu (nach dem Heimnetzwerk-Eintrag)
sed -i "/- \"192.168.178.0\/24\"/a\\    \\n    # Externe IP (dynamisch aus ionos-dyndns)\\n    - \"$EXTERNAL_IP\"" "$WHITELIST_FILE"

echo "✅ Whitelist aktualisiert"

# CrowdSec neu starten (Parsers haben keinen reload-Befehl)
echo "🔄 Starte CrowdSec neu..."
cd /home/hajo/docker/crowdsec
docker compose restart crowdsec >/dev/null 2>&1
echo "✅ CrowdSec neu gestartet"

echo ""
echo "🎉 Whitelist-Update abgeschlossen!"
echo ""
echo "📋 Aktuelle Whitelist-IPs:"
grep -E '^\s+- "' "$WHITELIST_FILE" | sed 's/^/   /'

# Made with Bob
