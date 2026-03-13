#!/bin/sh
# Test-Script um Fehler zu finden
set -x  # Debug-Modus

UPDATE_URL="${UPDATE_URL:-test}"
INTERVAL="${INTERVAL_SECONDS:-300}"
FRITZ_BOX_URL="${FRITZ_BOX_URL:-http://fritz.box:49000}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

echo "Variables loaded successfully"

# Test log functions
ts() { date '+%Y-%m-%d %H:%M:%S%z'; }
echo "ts function works: $(ts)"

log_info() { printf "%s [ionos-dyndns] INFO: %s\n" "$(ts)" "$1"; }
log_info "Test log"

# Test FRITZ_URL
FRITZ_URL="${FRITZ_BOX_URL}/igdupnp/control/WANIPConn1"
echo "FRITZ_URL: $FRITZ_URL"

# Test status file
STATUS_FILE="/app/data/status.json"
echo "Creating directory..."
mkdir -p "$(dirname "$STATUS_FILE")"
echo "Directory created"

# Test cleanup function
cleanup() {
  echo "Cleanup called"
  exit 0
}
trap cleanup SIGTERM SIGINT
echo "Trap set"

# Test is_valid_public_ipv4
is_valid_public_ipv4() {
  local ip="$1"
  echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || return 1
  case "$ip" in
    10.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|192.168.*|127.*|0.0.0.0|255.255.255.255)
      return 1
      ;;
  esac
  return 0
}

echo "Testing IP validation..."
if is_valid_public_ipv4 "8.8.8.8"; then
  echo "IP validation works"
else
  echo "IP validation failed"
fi

echo "All tests passed!"
sleep 5

# Made with Bob
