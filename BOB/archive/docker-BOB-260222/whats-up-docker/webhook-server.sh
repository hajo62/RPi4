#!/bin/bash

# WUD Webhook Server - Bash-basierter HTTP-Server
# Empfängt Webhooks von WUD und führt send_signal.sh aus

PORT="${PORT:-8091}"
SCRIPT_PATH="/scripts/send_signal.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting webhook server on port $PORT"
log "Script path: $SCRIPT_PATH"

if [ ! -f "$SCRIPT_PATH" ]; then
    log "ERROR: Script not found at $SCRIPT_PATH"
    exit 1
fi

if [ ! -x "$SCRIPT_PATH" ]; then
    log "WARNING: Script is not executable, trying to make it executable"
    chmod +x "$SCRIPT_PATH" 2>/dev/null || log "ERROR: Cannot make script executable"
fi

log "Webhook server ready"

# Einfacher HTTP-Server mit netcat
while true; do
    # Empfange HTTP-Request
    REQUEST=$(echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n" | nc -l -p "$PORT" -q 1)
    
    # Prüfe ob es ein POST-Request ist
    if echo "$REQUEST" | grep -q "POST /webhook"; then
        log "Webhook received"
        
        # Extrahiere JSON-Body (nach den Headers)
        BODY=$(echo "$REQUEST" | sed -n '/^{/,/^}/p')
        
        if [ -n "$BODY" ]; then
            # Extrahiere Container-Informationen aus JSON
            CONTAINER_NAME=$(echo "$BODY" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
            CURRENT_VERSION=$(echo "$BODY" | grep -o '"result":{"tag":"[^"]*"' | cut -d'"' -f6)
            NEW_VERSION=$(echo "$BODY" | grep -o '"updateAvailable":{"tag":"[^"]*"' | cut -d'"' -f6)
            
            # Fallback-Werte
            CONTAINER_NAME="${CONTAINER_NAME:-unknown}"
            CURRENT_VERSION="${CURRENT_VERSION:-unknown}"
            NEW_VERSION="${NEW_VERSION:-unknown}"
            
            log "Container: $CONTAINER_NAME"
            log "Current: $CURRENT_VERSION → New: $NEW_VERSION"
            
            # Führe Script aus
            if [ -x "$SCRIPT_PATH" ]; then
                log "Executing script..."
                bash "$SCRIPT_PATH" "$CONTAINER_NAME" "$CURRENT_VERSION" "$NEW_VERSION" &
                log "Script execution started in background"
            else
                log "ERROR: Script not executable"
            fi
        else
            log "WARNING: No JSON body found in request"
        fi
        
    elif echo "$REQUEST" | grep -q "GET /health"; then
        log "Health check received"
        
    else
        log "Unknown request received"
    fi
    
    # Kurze Pause vor nächstem Request
    sleep 0.1
done

# Made with Bob
