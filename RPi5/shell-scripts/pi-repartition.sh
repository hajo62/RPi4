#!/usr/bin/env bash
# pi-repartition.sh
# Repartitioniert eine Raspberry-Pi-SD-Karte im Live-System:
# - Root (ext4) sicher verkleinern (Minimum + Sicherheitsmarge)
# - 4GB Swap-Partition anlegen
# - Rest als /home (ext4) anlegen, Inhalte kopieren, fstab des Zielsystems anpassen
# Nutzung: sudo ./pi-repartition.sh /dev/mmcblk0
# Achtung: Gerät MUSS korrekt angegeben werden und darf nicht gemountet sein!

# Debug optional aktivieren: DEBUG=1 sudo ./pi-repartition.sh /dev/mmcblk0
if [ "${DEBUG:-0}" = "1" ]; then set -x; fi
set -euo pipefail

# -------------------------
# Einstellungen / Defaults
# -------------------------
DEVICE="${1:-}"
SWAP_SIZE_GB="${SWAP_SIZE_GB:-4}"            # Zielgröße Swap in GiB
ROOT_MARGIN_MB="${ROOT_MARGIN_MB:-512}"      # Sicherheitsmarge Root (MB)
TARGET_MOUNT="${TARGET_MOUNT:-/mnt/target}"  # Mountpunkt für Ziel-Root
STATE_TMP="/tmp/pi-repartition"
LOG() { printf "[pi-repartition] %s\n" "$*"; }

usage() {
  echo "Usage: sudo $0 /dev/mmcblk0"
  echo "Environment overrides: SWAP_SIZE_GB=<int GiB> ROOT_MARGIN_MB=<int MB> TARGET_MOUNT=<path>"
}

# -------------------------
# Vorabprüfungen
# -------------------------
if [ -z "$DEVICE" ]; then
  usage; exit 1
fi
if [ ! -b "$DEVICE" ]; then
  LOG "Gerät nicht gefunden: $DEVICE"; exit 1
fi

# Prüfen, dass keine Partition des Geräts gemountet ist
if lsblk -nr -o MOUNTPOINT "$DEVICE" | grep -qE '/'; then
  LOG "Partitions dieses Geräts sind gemountet. Bitte alle Partitionen unmounten und erneut starten."
  exit 1
fi

mkdir -p "$STATE_TMP"

# -------------------------
# Partitionsermittlung
# -------------------------
# Annahme: p1 = boot (FAT32), p2 = root (ext4)
# (Für mmcblk/nvme ist 'p' üblich; bei sda/sdb wäre es ohne 'p')
SUF=""
case "$DEVICE" in
  *mmcblk*|*nvme*) SUF="p" ;;
esac

BOOT_PART="${DEVICE}${SUF}1"
ROOT_PART="${DEVICE}${SUF}2"

for p in "$BOOT_PART" "$ROOT_PART"; do
  if [ ! -b "$p" ]; then
    LOG "Erwartete Partition fehlt: $p"
    exit 1
  fi
done

# Dateisystem-Typ Root verifizieren
ROOT_FS_TYPE=$(sudo blkid -o value -s TYPE "$ROOT_PART" || true)
if [ "$ROOT_FS_TYPE" != "ext4" ]; then
  LOG "Root-Partition ist kein ext4 (gefunden: '${ROOT_FS_TYPE:-<none>}'). Abbruch."
  exit 1
fi

# -------------------------
# Minimalgröße des ext4 ermitteln
# -------------------------
LOG "Prüfe ext4-Dateisystem auf Root-Partition ($ROOT_PART) ..."
sudo e2fsck -f "$ROOT_PART" || true

LOG "Ermittle Minimalgröße (Blöcke) des ext4-Dateisystems ..."
MIN_BLOCKS=$(sudo resize2fs -P "$ROOT_PART" 2>/dev/null | awk '{print $NF}')
if [ -z "$MIN_BLOCKS" ]; then
  LOG "Konnte Minimalgröße nicht ermitteln."; exit 1
fi

# Blockgröße auslesen (ext4: meist 4096)
BLOCK_SIZE=$(sudo dumpe2fs -h "$ROOT_PART" 2>/dev/null | awk -F': ' '/Block size:/ {print $2}' || echo 4096)
case "$BLOCK_SIZE" in
  ''|*[!0-9]*) BLOCK_SIZE=4096 ;;
esac

MIN_BYTES=$(( MIN_BLOCKS * BLOCK_SIZE ))
MARGIN_BYTES=$(( ROOT_MARGIN_MB * 1024 * 1024 ))
TARGET_ROOT_BYTES=$(( MIN_BYTES + MARGIN_BYTES ))

# Runde auf MiB
TARGET_ROOT_MIB=$(( (TARGET_ROOT_BYTES + (1024*1024-1)) / (1024*1024) ))

LOG "Minimalgröße: $MIN_BLOCKS Blöcke á $BLOCK_SIZE Byte = $((MIN_BYTES/1024/1024)) MiB"
LOG "Sicherheitsmarge: ${ROOT_MARGIN_MB} MiB"
LOG "Zielgröße Root-Dateisystem: ${TARGET_ROOT_MIB} MiB"

# -------------------------
# Root-Dateisystem offline verkleinern
# -------------------------
LOG "Verkleinere ext4-Dateisystem auf ~${TARGET_ROOT_MIB} MiB ..."
sudo resize2fs "$ROOT_PART" "${TARGET_ROOT_MIB}M"

# -------------------------
# Root-Partition (Eintrag in Tabelle) verkleinern
# -------------------------
LOG "Lese aktuelle Partitionstabelle ..."
PART_INFO=$(sudo parted -s "$DEVICE" unit MiB print)
ROOT_START_MIB=$(echo "$PART_INFO" | awk '/^[[:space:]]*2[[:space:]]/ {gsub("MiB","",$2); print $2}')
if [ -z "$ROOT_START_MIB" ]; then
  LOG "Konnte Start der Root-Partition nicht ermitteln."; exit 1
fi

ROOT_NEW_END_MIB=$(( ROOT_START_MIB + TARGET_ROOT_MIB ))
if [ "$ROOT_NEW_END_MIB" -le "$ROOT_START_MIB" ]; then
  LOG "Neues Ende liegt vor oder gleich dem Start. Abbruch."
  exit 1
fi

LOG "Setze Root-Partition-Ende auf ${ROOT_NEW_END_MIB} MiB (Start: ${ROOT_START_MIB} MiB) ..."
# Bestätigung für das riskante Shrink automatisch liefern
printf "Yes\n" | sudo parted ---pretend-input-tty "$DEVICE" unit MiB resizepart 2 "${ROOT_NEW_END_MIB}MiB"

# Kernel über neue Tabelle informieren
sudo partprobe "$DEVICE" || true
sleep 2

# -------------------------
# Swap + Home Partitionen anlegen
# -------------------------
SWAP_SIZE_MIB=$(( SWAP_SIZE_GB * 1024 ))
SWAP_START_MIB=$(( ROOT_NEW_END_MIB + 1 ))
SWAP_END_MIB=$(( SWAP_START_MIB + SWAP_SIZE_MIB ))

LOG "Erzeuge Swap-Partition: Start ${SWAP_START_MIB} MiB, Ende ${SWAP_END_MIB} MiB (~${SWAP_SIZE_GB} GiB) ..."
sudo parted -s "$DEVICE" unit MiB mkpart primary linux-swap "${SWAP_START_MIB}MiB" "${SWAP_END_MIB}MiB"

HOME_START_MIB=$(( SWAP_END_MIB + 1 ))
LOG "Erzeuge Home-Partition: Start ${HOME_START_MIB} MiB, Ende 100% ..."
sudo parted -s "$DEVICE" unit MiB mkpart primary ext4 "${HOME_START_MIB}MiB" 100%

sudo partprobe "$DEVICE" || true
sleep 2

# Neue Partitionsbezeichnungen finden:
SWAP_PART="${DEVICE}${SUF}3"
HOME_PART="${DEVICE}${SUF}4"
for p in "$SWAP_PART" "$HOME_PART"; do
  if [ ! -b "$p" ]; then
    LOG "Neue Partition nicht gefunden: $p"; exit 1
  fi
done

# -------------------------
# Formatieren: swap + home
# -------------------------
LOG "Formatiere Swap ($SWAP_PART) ..."
sudo mkswap "$SWAP_PART"

LOG "Formatiere Home ($HOME_PART) als ext4 ..."
sudo mkfs.ext4 -L home "$HOME_PART"

SWAP_UUID=$(sudo blkid -o value -s UUID "$SWAP_PART")
HOME_UUID=$(sudo blkid -o value -s UUID "$HOME_PART")
if [ -z "$SWAP_UUID" ] || [ -z "$HOME_UUID" ]; then
  LOG "Konnte UUIDs der neuen Partitionen nicht ermitteln."; exit 1
fi
LOG "Swap-UUID: $SWAP_UUID"
LOG "Home-UUID: $HOME_UUID"

# -------------------------
# Root des Zielsystems mounten, Home migrieren, fstab schreiben
# -------------------------
LOG "Mount Ziel-Root ($ROOT_PART) nach $TARGET_MOUNT ..."
sudo mkdir -p "$TARGET_MOUNT"
sudo mount "$ROOT_PART" "$TARGET_MOUNT"

# Sicherstellen, dass /home existiert
sudo mkdir -p "$TARGET_MOUNT/home"

LOG "Mount neue Home-Partition ($HOME_PART) nach $TARGET_MOUNT/home.new ..."
sudo mkdir -p "$TARGET_MOUNT/home.new"
sudo mount "$HOME_PART" "$TARGET_MOUNT/home.new"

LOG "Kopiere vorhandenes /home -> neue Partition (rsync -aHAX --numeric-ids) ..."
sudo rsync -aHAX --numeric-ids "$TARGET_MOUNT/home/" "$TARGET_MOUNT/home.new/"

LOG "Sicherung des alten /home als /home.bak und Mountpunkt vorbereiten ..."
sudo mv "$TARGET_MOUNT/home" "$TARGET_MOUNT/home.bak"
sudo mkdir "$TARGET_MOUNT/home"

LOG "Unmount /home.new und als /home neu einhängen ..."
sudo umount "$TARGET_MOUNT/home.new"
sudo mount "$HOME_PART" "$TARGET_MOUNT/home"

# fstab des Zielsystems aktualisieren (UUID-basiert)
FSTAB="$TARGET_MOUNT/etc/fstab"
LOG "Schreibe Einträge in $FSTAB ..."
sudo cp "$FSTAB" "$FSTAB.bak.$(date +%Y%m%d-%H%M%S)"
{
  echo ""
  echo "# --- Added by pi-repartition.sh ---"
  echo "UUID=${HOME_UUID}  /home  ext4  defaults,noatime  0  2"
  echo "UUID=${SWAP_UUID}  none   swap  sw                0  0"
} | sudo tee -a "$FSTAB" >/dev/null

LOG "Sync & Aufräumen ..."
sync
sudo umount "$TARGET_MOUNT/home" || true
sudo umount "$TARGET_MOUNT" || true

LOG "Fertig: Swap + Home angelegt und fstab aktualisiert."
LOG "Du kannst jetzt das Live-System herunterfahren und den Pi normal booten."