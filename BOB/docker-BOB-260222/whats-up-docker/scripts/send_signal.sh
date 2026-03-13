#!/bin/bash

# WUD Webhook Script - Sendet Signal-Benachrichtigung bei Container-Updates
# Parameter:
#   $1 = Container-Name
#   $2 = Aktuelle Version
#   $3 = Neue Version

CONTAINER_NAME="${1:-unknown}"
CURRENT_VERSION="${2:-unknown}"
NEW_VERSION="${3:-unknown}"

# Timestamp für Logging
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Update detected:"
echo "  Container: $CONTAINER_NAME"
echo "  Current:   $CURRENT_VERSION"
echo "  New:       $NEW_VERSION"

# Signal-Nachricht zusammenstellen (mit \n für Zeilenumbrüche)
MESSAGE="🔄 Docker Update verfügbar\n\nContainer: $CONTAINER_NAME\nAktuell: $CURRENT_VERSION\nNeu: $NEW_VERSION\n\nDashboard: http://localhost:3000"

# Signal-CLI REST API Endpoint (anpassen an deine Installation)
SIGNAL_API_URL="http://signal-cli-rest-api:8080/v2/send"

# Signal-Absender (registrierte Nummer in Signal-CLI)
SIGNAL_SENDER="+491637928873"

# Signal-Empfänger (deine Telefonnummer)
SIGNAL_RECIPIENT="+491704532333"

# Optional: Aus Umgebungsvariablen lesen
if [ -n "$SIGNAL_RECIPIENT_NUMBER" ]; then
    SIGNAL_RECIPIENT="$SIGNAL_RECIPIENT_NUMBER"
fi

# Signal-Nachricht senden
echo "[$TIMESTAMP] Sending Signal notification..."
echo "[$TIMESTAMP] From: $SIGNAL_SENDER To: $SIGNAL_RECIPIENT"

RESPONSE=$(curl -s -X POST "$SIGNAL_API_URL" \
    -H "Content-Type: application/json" \
    -d "{
        \"message\": \"$MESSAGE\",
        \"number\": \"$SIGNAL_SENDER\",
        \"recipients\": [\"$SIGNAL_RECIPIENT\"]
    }")

if [ $? -eq 0 ]; then
    echo "[$TIMESTAMP] Signal notification sent successfully"
    echo "Response: $RESPONSE"
else
    echo "[$TIMESTAMP] ERROR: Failed to send Signal notification"
    echo "Response: $RESPONSE"
    exit 1
fi

# Optional: Zusätzliche Aktionen hier hinzufügen
# z.B. Log-Datei schreiben, E-Mail senden, etc.

exit 0

# Made with Bob
