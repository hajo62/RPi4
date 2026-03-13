#!/bin/sh
set -eu

UPDATE_URL="${UPDATE_URL:?UPDATE_URL not set}"
INTERVAL="${INTERVAL_SECONDS:-300}"
FRITZ_BOX_URL="${FRITZ_BOX_URL:-http://fritz.box:49000}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Log-Funktionen mit verschiedenen Levels
ts() { date '+%Y-%m-%d %H:%M:%S%z'; }
log_debug() { [ "$LOG_LEVEL" = "DEBUG" ] && printf "%s [ionos-dyndns] DEBUG: %s\n" "$(ts)" "$1" || true; }
log_info() { printf "%s [ionos-dyndns] INFO: %s\n" "$(ts)" "$1"; }
log_warn() { printf "%s [ionos-dyndns] WARN: %s\n" "$(ts)" "$1"; }
log_error() { printf "%s [ionos-dyndns] ERROR: %s\n" "$(ts)" "$1"; }

FRITZ_URL="${FRITZ_BOX_URL}/igdupnp/control/WANIPConn1"
SOAP_ACTION="urn:schemas-upnp-org:service:WANIPConnection:1#GetExternalIPAddress"
SOAP_BODY="<?xml version='1.0' encoding='utf-8'?>
<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
  <s:Body>
    <u:GetExternalIPAddress xmlns:u='urn:schemas-upnp-org:service:WANIPConnection:1' />
  </s:Body>
</s:Envelope>"

STATUS_FILE="/app/data/status.json"
mkdir -p "$(dirname "$STATUS_FILE")"

# Graceful Shutdown Handler
cleanup() {
  log_info "Received shutdown signal, exiting gracefully..."
  exit 0
}
trap cleanup SIGTERM SIGINT

# IP-Validierung: Prüft ob IP eine gültige öffentliche IPv4 ist
is_valid_public_ipv4() {
  local ip="$1"
  
  # Format prüfen
  echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || return 1
  
  # Private IP-Bereiche ausschließen
  case "$ip" in
    10.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|192.168.*|127.*|0.0.0.0|255.255.255.255)
      return 1
      ;;
  esac
  
  return 0
}

# IP aus FRITZ!Box holen
get_ipv4() {
  wget -qO- "$FRITZ_URL" \
    --header="Content-Type: text/xml; charset=utf-8" \
    --header="SoapAction: $SOAP_ACTION" \
    --post-data="$SOAP_BODY" \
  | grep -Eo '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -n1
}

# Status in JSON-Datei schreiben
write_status() {
  local status="$1"
  local ip="${2:-}"
  local message="${3:-}"
  local timestamp="$(date -Iseconds)"
  
  cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$timestamp",
  "status": "$status",
  "current_ip": "$ip",
  "message": "$message",
  "fritz_box_url": "$FRITZ_BOX_URL",
  "update_interval": $INTERVAL
}
EOF
}

# Vorherige IP aus Status-Datei lesen
get_previous_ip() {
  if [ -f "$STATUS_FILE" ]; then
    grep -o '"current_ip": "[^"]*"' "$STATUS_FILE" 2>/dev/null | cut -d'"' -f4
  fi
}

log_info "Starting DynDNS updater (interval=${INTERVAL}s)"
log_info "Using FRITZ!Box endpoint: $FRITZ_URL"
log_info "Status file: $STATUS_FILE"
log_debug "Log level: $LOG_LEVEL"

RETRY_COUNT=0

while true; do
  log_debug "Fetching current IP from FRITZ!Box..."
  CURRENT_IP="$(get_ipv4 || true)"

  if [ -z "$CURRENT_IP" ]; then
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log_error "Could not retrieve IPv4 from FRITZ!Box (attempt $RETRY_COUNT)"
    write_status "error" "" "Failed to retrieve IP from FRITZ!Box (attempt $RETRY_COUNT)"
    sleep "$INTERVAL" &
    wait $!
    continue
  fi

  log_debug "Retrieved IP: $CURRENT_IP"

  # IP-Validierung
  if ! is_valid_public_ipv4 "$CURRENT_IP"; then
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log_error "Invalid or private IP received: $CURRENT_IP (attempt $RETRY_COUNT)"
    write_status "error" "$CURRENT_IP" "Invalid or private IP address"
    sleep "$INTERVAL" &
    wait $!
    continue
  fi

  # Reset retry counter bei erfolgreicher IP-Abfrage
  if [ $RETRY_COUNT -gt 0 ]; then
    log_info "Successfully recovered after $RETRY_COUNT failed attempts"
    RETRY_COUNT=0
  fi

  PREV_IP="$(get_previous_ip)"
  
  if [ "$CURRENT_IP" = "$PREV_IP" ] && [ -n "$PREV_IP" ]; then
    log_info "No change: IPv4 still ${CURRENT_IP}. Skipping update."
    write_status "ok" "$CURRENT_IP" "No change detected"
  else
    log_info "IPv4 changed: ${PREV_IP:-<none>} -> ${CURRENT_IP}. Calling update URL..."
    
    if wget -qO- "$UPDATE_URL" >/dev/null 2>&1; then
      log_info "Update successful."
      write_status "ok" "$CURRENT_IP" "Update successful"
    else
      log_error "Update failed. Will retry in ${INTERVAL}s."
      write_status "error" "$CURRENT_IP" "DynDNS update failed"
    fi
  fi

  sleep "$INTERVAL" &
  wait $!
done

# Made with Bob
