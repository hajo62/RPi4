
## Externe HDD
Nach anstöppseln wurde diese aautomatisch unter `/media/hajo/Expansions` gemountet. 
Dateisystemtyp anzeigen: `lsblk -f` oder `df -hT`.  
Mit `gparted` habe ich die beiden vorhanden Partitionen gelöscht und eine neue mit Dateisystem `exfat` angelegt.

## Installation von VeraCrypt
System aktualisieren.
```
sudo apt update && sudo apt upgrade
```
Anschließend Pi-Apps installieren und starten:
```
wget -qO- https://raw.githubusercontent.com/Botspot/pi-apps/master/install | bash

pi-apps
```
Im sich öffnenden X-Fenster nach VeraCrypt suchen und installieren.

## Festplatte verschlüsseln
Tipp für den Pi 5: Nutzen Sie für die Verschlüsselung den Standard aes-xts-plain64, da der Raspberry Pi 5 über Hardware-Beschleunigung verfügt, die dies sehr performant macht. Bin nicht sicher, ob die Befehle unten das berücksichtigt haben, da ich diesen Hinweis erst später erhalten habe.

Die Festplatte mit folgendem Kommando verschlüsseln. Für die 5TB-Platte am Pi dauerte das ca. 9 h.
```
sudo nohup sudo veracrypt -t --create /dev/sda1 \
    --volume-type normal \
    --encryption AES \
    --hash sha512 \
    --filesystem exfat \
    --password X7Hf3RZfzbDa^4qmLmHKqy7PLW79 \
    --pim 0 \
    --keyfiles "" \
    --random-source /dev/urandom \
    --non-interactive > /home/hajo/encrypt.log 2>&1 &
```

## Verschlüsselte Festplatte mounten
Damit Kennwort nicht in `ps -aux` sichtbar ist:
```
# Passwort in die Datei schreiben
echo 'VC_PASSWORD=X7Hf3RZfzbDa^4qmLmHKqy7PLW79' > veracrypt.env

# Zugriffsberechtigungen einschränken (nur Besitzer darf lesen/schreiben)
chmod 600 veracrypt.env
```

```
grep '^VC_PASSWORD=' veracrypt.env | cut -d'=' -f2- | sudo veracrypt -t --non-interactive --stdin /dev/sda1 /mnt/Backup

# ggf. noch Parameter: --fs-options="iocharset=utf8"
grep '^VC_PASSWORD=' veracrypt.env | cut -d'=' -f2- | sudo veracrypt -t --non-interactive --stdin --fs-options="iocharset=utf8" /dev/sda1 /mnt/Backup
```

## Verschlüsselte Festplatte un-mounten
```
sudo veracrypt -t -d /mnt/Backup
```

## Daten vom Synology-NAS sichern
Mounten des NAS-Verzeichnisses:
```
sudo mkdir /mnt/Synology
sudo chown hajo:hajo /mnt/Synology
sudo mount -t cifs //192.168.178.2/homes/hajo /mnt/Synology -o username=hajo
```

Kopieren der Daten vom NAS:
Wenn beim Quell-Verzeichnis am Ende ein "/" steht, werden nur die Unterverzeichnisse im Ziel abgelegt.

```
rsync -a --info=progress2 --partial --exclude='._*' --exclude='Icon?' --exclude='.DS_Store' /mnt/Synology/Documents /mnt/Backup

rsync -av --no-p --no-o --no-g --partial --info=progress2 --exclude='._*' --exclude='Icon?' --exclude='.DS_Store' /mnt/Synology/Documents /mnt/Backup/Documents
```

# Auf dem Mac
Wird [FUSE-T](https://www.fuse-t.org/) für den Einsatz von [VeraCrypt](https://veracrypt.io/en/Downloads.html) benötigt.