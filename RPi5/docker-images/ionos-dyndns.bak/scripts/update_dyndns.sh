#!/bin/sh
set -eu

UPDATE_URL="${UPDATE_URL:?UPDATE_URL not set}"
INTERVAL="${INTERVAL_SECONDS:-300}"

# Log-Funktion mit Zeitstempel (lokale Zeit, inkl. Zeitzone)
ts() { date '+%Y-%m-%d %H:%M:%S%z'; }
log() { printf "%s [ionos-dyndns] %s\n" "$(ts)" "$1"; }

FRITZ_URL="http://fritz.box:49000/igdupnp/control/WANIPConn1"
SOAP_ACTION="urn:schemas-upnp-org:service:WANIPConnection:1#GetExternalIPAddress"
SOAP_BODY="<?xml version='1.0' encoding='utf-8'?>
<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
  <s:Body>
    <u:GetExternalIPAddress xmlns:u='urn:schemas-upnp-org:service:WANIPConnection:1' />
  </s:Body>
</s:Envelope>"

STATE_FILE="/app/state/prev_ipv4.txt"
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

# IP aus FRITZ!Box holen
get_ipv4() {
  wget -qO- "$FRITZ_URL" \
    --header="Content-Type: text/xml; charset=utf-8" \
    --header="SoapAction: $SOAP_ACTION" \
    --post-data="$SOAP_BODY" \
  | grep -Eo '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -n1
}

log "Starting DynDNS updater (interval=${INTERVAL}s)"
log "Using FRITZ!Box endpoint: $FRITZ_URL"

while true; do
  CURRENT_IP="$(get_ipv4 || true)"

  if [ -z "$CURRENT_IP" ]; then
    log "Could not retrieve IPv4 from FRITZ!Box. Retrying in ${INTERVAL}s..."
    sleep "$INTERVAL"
    continue
  fi

  PREV_IP="$(cat "$STATE_FILE" 2>/dev/null || true)"
  if [ "$CURRENT_IP" = "$PREV_IP" ] && [ -n "$PREV_IP" ]; then
    log "No change: IPv4 still ${CURRENT_IP}. Skipping update."
  else
    log "IPv4 changed: ${PREV_IP:-<none>} -> ${CURRENT_IP}. Calling update URL..."
    if wget -qO- "$UPDATE_URL" >/dev/null 2>&1; then

      log "Update successful."
      printf "%s" "$CURRENT_IP" > "$STATE_FILE"
    else
      log "Update failed. Will retry in ${INTERVAL}s."
    fi
  fi

  sleep "$INTERVAL"
done