# KOMPLETT-ANLEITUNG: RASPBERRY PI 5 SETUP (TRIXIE, SSD & LAN-TO-WLAN)

Diese Anleitung führt dich vom aktuellen System (SD-Karte) zum neuen System (SSD). Wir nutzen ein LAN-Kabel für den Erstkontakt, um die WLAN-Sperren (rfkill) ohne lokale Tastatur zu lösen.

## 1. IMAGE LADEN (AUF DER AKTUELLEN SD-KARTE)
mkdir ~/trixie_install && cd ~/trixie_install
wget --no-proxy -O trixie_lite.img.xz https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz

## 2. INSTALLATION AUF DIE SSD
lsblk # Identifiziere SSD (nvme0n1)
xzcat trixie_lite.img.xz | sudo dd of=/dev/nvme0n1 bs=4M status=progress conv=fsync

## 3. HEADLESS-KONFIGURATION (BOOT-PARTITION)
sudo mkdir -p /mnt/trixie_boot
sudo mount /dev/nvme0n1p1 /mnt/trixie_boot

### A) SSH & HOSTNAME SETZEN
sudo touch /mnt/trixie_boot/ssh
echo "rpi5" | sudo tee /mnt/trixie_boot/hostname

### B) USER 'hajo' ANLEGEN (Passwort wird bei Ausführung abgefragt)
echo "hajo:$(openssl passwd -6)" | sudo tee /mnt/trixie_boot/userconf.txt

sudo umount /mnt/trixie_boot

## 4. BOOT-REIHENFOLGE (EEPROM)
sudo rpi-eeprom-config --edit
# Kopiere diese Zeilen in den [all] Block:
BOOT_ORDER=0xf641
PCIE_PROBE=1
BOOT_RETRY_DELAY=1000

## 5. DER PHYSISCHE WECHSEL & LAN-ANSCHLUSS oder TASTATUR und MONITOR
1. sudo halt -> Strom ab.
2. SD-KARTE PHYSISCH ENTFERNEN.
3. LAN-KABEL von der FRITZ!Box zum Pi 5 einstecken.
4. Strom an -> Der Pi bootet nun von SSD und ist per LAN online.

## 6. SSH-LOGIN & WLAN-FREISCHALTUNG (VIA LAN)
### Logge dich per SSH ein (IP in FRITZ!Box suchen, z.B. 192.168.178.55):
ssh hajo@192.168.178.55

A) WLAN-Land setzen (Löst die rfkill-Sperre)
sudo raspi-config nonint do_wifi_country DE

B) WLAN-Verbindung einrichten
sudo nmcli device wifi connect "Luftnetz" password "25812359343499210922"

C) RF-Kill Check (Sollte nun 'unblocked' sein)  
Falls es noch immer nicht funktioniert
`sudo rfkill unblock all`

## 7. SSH-HARDENING (NUR LOGIN PER KEY)
# A) AN DEINEM PC (Terminal oder PowerShell):
# 1. Neuen sicheren Key generieren:
#    ssh-keygen -t ed25519 -C "hajo@rpi5"
# 2. Den Public-Key auf den Pi übertragen:
#    ssh-copy-id -i ~/.ssh/id_ed25519.pub hajo@192.168.178.55

# B) AM PI (Prüfen und Passwort-Login abschalten):
# 1. Teste den Login in einem NEUEN Terminal am PC: ssh hajo@192.168.178.5
# 2. Wenn der Login ohne Pi-Passwort klappt, am Pi ausführen:
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh


## 8. Localization einstellen
Dazu in der Datei `/etc/default/locale` Folgendes eintragen.
`sudo nano /etc/default/locale`

```
LANG=de_DE.UTF-8
LC_CTYPE=de_DE.UTF-8
LC_MESSAGES=de_DE.UTF-8
LC_ALL=de_DE.UTF-8
```
Anschließend `sudo dpkg-reconfigure locales` und dort nach `de_DE.UTF-8 UTF-8` suchen und mit Leertaste markieren. Mit Enter bestätigen. Wähle im nächsten Fenster `de_DE.UTF-8` als Standard aus und bestätige mit Enter.
Ausloggen, einloggen, geht 😀

### Zeitzone einstellen
```
sudo timedatectl set-timezone Europe/Berlin
# ggf. prüfen mit 
date
```


## 9. System-Setting und -Tuning
### Software-Updates einspielen
```
sudo apt update
sudo apt upgrade

# GIT
sudo apt install git

# Smartmon-Tools
sudo apt update && sudo apt install smartmontools -y
```


### Swap auf 4 GB erhöhen
Eine Swap-Partition ist nicht mehr notwendig; Swapfile ist ausreichend.

1. Alten Swap (falls vorhanden) ausschalten: sudo swapoff -a
2. 4GB Datei erstellen: sudo fallocate -l 4G /swapfile
3. Rechte setzen: sudo chmod 600 /swapfile
4. Formatieren: sudo mkswap /swapfile
5. Aktivieren: sudo swapon /swapfile
6. Dauerhaft machen:  
Füge die Zeile `/swapfile none swap sw 0 0` am Ende der Datei /etc/fstab hinzu:  
`echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab`
7. Prüfen mit `free -h`

### Swappiness auf 10 setzen (schont SSD)
```
sudo bash -c 'echo "vm.swappiness=10" >> /etc/sysctl.conf' && sudo sysctl -p
# Prüfen mit:
cat /proc/sys/vm/swappiness
# oder 
sysctl vm.swappiness
```

**oder besser** - dann allerdings ohne die Einstellung in /etc/sysctl.conf manuell vorzunehmen :
```
sudo tee /etc/sysctl.d/99-server-tuning.conf <<EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=15
EOF
```

### PCIe Gen 3 für die Intenso SSD setzen
PCI Gen 3 scheint nicht zu funktionieren.
```
sudo nano /boot/firmware/config.txt
```
Am Ende der Datei diese neue Zeile hinzufügen und rebooten:
```
dtparam=pciex1_gen=3
```


## 10 Konfigurationen für Pironman 5 Gehäuses
Siehe Anleitung [hier(https://docs.sunfounder.com/projects/pironman5/de/latest/pironman5_max/set_up/set_up_rpi_os.html#)]
Falls bei dem Prozess die Meldung `Try updating the rpi-eeprom APT package` erscheint, folgendes durchführen (Siehe [hier](https://wiki.geekworm.com/How_to_update_eeprom_firmware)):
```
sudo apt update
sudo apt upgrade -y
sudo rpi-eeprom-update
```
Ggf. muss in dem _Tool_ bei `Advanced Options` die neuste Version angewählt werden.

Wie die Software für das Pironman5 Modul zu installieren ist, steht [hier](https://docs.sunfounder.com/projects/pironman5/de/latest/pironman5_max/set_up/set_up_rpi_os.html#download-und-installation-des-moduls-pironman5) beschrieben.

Das Pironman-Dashboard öffnet man über: http://192.168.178.55:34001


# 11 Linux-Updates automatisch einspielen
1. Benötigte Pakete installieren.
```bash
sudo apt update
sudo apt install unattended-upgrades apt-listchanges
```

2. Konfiguration der Intervalle (20auto-upgrades)
```
sudo bash -c 'cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF'
```

3. Konfiguration der Updates (50unattended-upgrades)
**Ich habe den automatischen Reebboot nicht aktiviert**
Suche in der Datei `/etc/apt/apt.conf.d/50unattended-upgrades` nach diesen Zeilen und passe sie an:
```
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
```

4. Sicherheitspatches automatisch einspielen
```
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

```
Unattended-Upgrade::Origins-Pattern {
        // Codename based matching:
        // This will follow the migration of a release through different
        // archives (e.g. from testing to stable and later oldstable).
        // Software will be the latest available for the named release,
        // but the Debian release itself will not be automatically upgraded.
//      "origin=Debian,codename=${distro_codename}-updates";
//      "origin=Debian,codename=${distro_codename}-proposed-updates";
//      "origin=Debian,codename=${distro_codename},label=Debian";
//      "origin=Debian,codename=${distro_codename},label=Debian-Security";
        "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
```

5. Reboot-Check im MOTD
Damit du beim Login siehst, ob ein Neustart aussteht.
**Script korrekt; so erstellen geht irgendwie nicht.**
```
sudo bash -c 'cat > /etc/update-motd.d/98-reboot-required <<EOF
#!/bin/sh
if [ -f /var/run/reboot-required ]; then
    echo "-----------------------------------------------"
    echo " *** NEUSTART ERFORDERLICH ***"
    if [ -f /var/run/reboot-required.pkgs ]; then
        echo " Ursache: $(cat /var/run/reboot-required.pkgs | tr '\n' ' ')"
    fi
    echo "-----------------------------------------------"
fi
EOF'
sudo chmod +x /etc/update-motd.d/98-reboot-required

```

## 12 Bequemlichkeiten
### Promt
`PS1="\\[\\e[1;37;41m\\]𝜋5:\\[\\e[0m\\] \\w \\$ "`

### GUI Shortcuts
Mit dem Kommando `nano ~/.bashrc` die Stelle `#some more ls aliases` finden und 
die Eintrage für `ll` auf  
`alias ll='ls -lF'`  
ändern.


# ~~Zweite SSD verschlüsselt und für das automatische Entsperren via Keyfile vorbereiten~~
Hat nicht funktioniert.
## 1. Vorbereitung: Keyfile auf der ersten SSD (Boot-Laufwerk) erstellen
Das Keyfile erlaubt dem Pi das automatische Entsperren ohne Passworteingabe.
```
sudo mkdir -p /etc/keys
sudo dd if=/dev/urandom of=/etc/keys/home_ssd.key bs=1 count=4096
sudo chmod 400 /etc/keys/home_ssd.key
```

## 2. LUKS-Verschlüsselung initialisieren
HINWEIS: Hier musst du einmalig ein Master-Passwort für den Notfall-Zugriff vergeben!
```
sudo apt update && sudo apt install cryptsetup -y
sudo cryptsetup luksFormat /dev/nvme1n1
```

## 3. Keyfile als Zugangsberechtigung hinzufügen
Damit wird das zuvor erstellte Keyfile im LUKS-Header der zweiten SSD registriert. Dazu das Kennwort/die Passphrase aus 2. eingeben.
```
sudo cryptsetup luksAddKey /dev/nvme1n1 /etc/keys/home_ssd.key
```

## 4. Den verschlüsselten "Tresor" öffnen und das Dateisystem (ext4) erstellen
```
sudo cryptsetup open /dev/nvme1n1 home_crypt --key-file /etc/keys/home_ssd.key
sudo mkfs.ext4 /dev/mapper/home_crypt
```

## 5. Automatische Entsperrung beim Booten konfigurieren (crypttab)
Wir ermitteln die UUID der SSD und tragen sie in die /etc/crypttab ein.
```
SSD_UUID=$(sudo blkid /dev/nvme1n1 -s UUID -o value)
echo "home_crypt UUID=$SSD_UUID /etc/keys/home_ssd.key luks" | sudo tee -a /etc/crypttab
```

## 6. Dateisystem (ext4) auf dem geöffneten Tresor erstellen
```
sudo mkfs.ext4 /dev/manual/home_crypt
```

## 7. Den neuen Speicher temporär einhängen und Daten spiegeln
rsync kopiert alle Rechte, Zeitstempel und versteckten Dateien.
```
sudo mount /dev/mapper/home_crypt /mnt
sudo rsync -aXS --progress /home/hajo/ /mnt/
```

## 8. Das alte Home-Verzeichnis umbenennen und den neuen Mountpoint vorbereiten
HINWEIS: Ab hier liegen deine Daten sicher auf der neuen SSD.
```
sudo mv /home/hajo /home/hajo_old
sudo mkdir /home/hajo
sudo chown hajo:hajo /home/hajo
sudo umount /mnt
```

## 9. Dauerhafte Einbindung in die Konfiguration (fstab) vornehmen
Dies sorgt dafür, dass die SSD bei jedem Start unter /home/hajo erscheint.
```
echo "/dev/mapper/home_crypt /home/hajo ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
```

## 10 Systemkonfiguration aktualisieren und SSD final einhängen
```
sudo systemctl daemon-reload
sudo mount /home/hajo
```

## 11. Die alten Daten löschen
Erfolgskontrolle. 
Zeigt an, ob /home/hajo nun wirklich auf dem verschlüsselten Mapper liegt.
```
df -h /home/hajo
# Löschen
sudo rm -rf /home/hajo_old
```












## 12. DOCKER & VERA-CRYPT
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
sudo usermod -aG docker hajo
sudo apt update && sudo apt install libfuse2 fuse device-mapper -y





#########
## zu löschende Schnippsel
