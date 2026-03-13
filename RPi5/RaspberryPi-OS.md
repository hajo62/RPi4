################################################################################

# Raspberry Pi OS
2. Runde mit ssd

# Raspberry Pi 5 Headless NVMe-Installation

## SCHRITT 0: SSD FINDEN (Manuelle Prüfung)
# Führe diesen Befehl aus und schau nach der 128GB Platte:
lsblk

# Wenn deine SSD NICHT 'nvme0n1' heißt (z.B. 'sda'), 
# musst du den Namen im folgenden Skript anpassen!

## SCHRITT 1: INSTALLATION (Auf der SD-Karte ausführen)
# 1. Image auf SSD schreiben
curl -L https://downloads.raspberrypi.com | sudo dd of=/dev/nvme0n1 bs=4M status=progress conv=fsync

# 2. SSD-Partitionen mounten
sudo mkdir -p /mnt/ssd_boot /mnt/ssd_root
sudo mount /dev/nvme0n1p1 /mnt/ssd_boot
sudo mount /dev/nvme0n1p2 /mnt/ssd_root

# 3. Hostname und SSH aktivieren
echo "rpi5" | sudo tee /mnt/ssd_root/etc/hostname
sudo touch /mnt/ssd_boot/ssh

# 4. User 'hajo' anlegen
echo "hajo:$(openssl passwd -6 'Passwort123')" | sudo tee /mnt/ssd_boot/userconf.txt

# 5. SSH Public Key kopieren
sudo mkdir -p /mnt/ssd_root/home/hajo/.ssh
[ -f ~/.ssh/authorized_keys ] && sudo cp ~/.ssh/authorized_keys /mnt/ssd_root/home/hajo/.ssh/
sudo chown -R 1000:1000 /mnt/ssd_root/home/hajo/.ssh

# 6. WLAN vorkonfigurieren (Ersetze 'WLAN_PASSWORT'!)
sudo bash -c 'cat <<EOF > /mnt/ssd_boot/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=DE
network={
    ssid="Luftnetz"
    psk="WLAN_PASSWORT"
}
EOF'

# 7. Boot-Reihenfolge & Performance (Gen 3)
sudo raspi-config non-int do_boot_order B2
sudo bash -c 'echo "dtparam=pciex1_gen=3" >> /mnt/ssd_boot/config.txt'

# 8. Abschluss
sudo umount /mnt/ssd_boot /mnt/ssd_root
echo "FERTIG! SD-Karte jetzt entfernen und Pi neu starten."
sudo poweroff

## SCHRITT 2: NACHARBEIT (Nach Boot von SSD via 'ssh hajo@192.168.178.55')
# 1. Localization & Swap
sudo raspi-config non-int do_change_locale de_DE.UTF-8
sudo raspi-config non-int do_configure_keyboard de
sudo raspi-config non-int do_tz_europe_berlin
sudo sed -i "s/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=4096/" /etc/dphys-swapfile
sudo dphys-swapfile swapoff && sudo dphys-swapfile setup && sudo dphys-swapfile swapon
















## Download Raspberry Pi OS
Für Home Assistant wird (12.2025) ein **Raspberry Pi OS** auf Basis von Debian **Bookworm** empfohlen.  
Die Images hierfür gibt es [hier](https://www.raspberrypi.com/software/operating-systems/) zum Download.  
Ich verwende: Raspberry Pi OS (Legacy, 64-bit) with desktop. 

## Schreiben des Images auf SD-Karte
Am einfachsten geht dies mit dem Raspberry Pi Imager, den es [hier](https://www.raspberrypi.com/software/) zum downloaden gibt. Wenn man den Imager verwendet, muss man das Disk-Image nicht vorher herunterladen.  
Rechner-Name: rpi5  
Benutzer: hajo  
WLAN: Luftnetz  
SSH: Public Key  

Anschließend kann man sich mit `ssh hajo@192.168.178.5 -p 22` einloggen. IP auf Fritzbox nachschauen. Public und Private Key-Pair muss vorhanden sein.  
Ich habe auf der Fritzbox nach dem ersten Kontakt die `.55` für die WLAN-Verbindung fest vergeben.

## Partitionen ändern
Bootreihenfolge ändern:   
`sudo raspi-config`   
Reihenfolge für USB-Boot wählen.


Der ssh-Login wird erstmal nicht funktionieren.  
Kommando `ssh-keygen -R 192.168.178.55` ausführen.

`pi-repartition.sh` - Das [Script](./shell-scripts/pi-repartition.sh) habe ich mit Copilot für 64GB SD-Karte generiert - Werte für SSD anpassen:  

Anschließend wieder von ssd booten. `sudo raspi-config`  
Reihenfolge für SSD-Boot wählen.

`Advanced Options / Boot Order / NVMe/USB Boot Boot from NVMe before trying USB and then SD Card` 

`sudo shutdown now`

---

## Konfigurationen für Pironman 5 Gehäuses
Siehe Anleitung [hier(https://docs.sunfounder.com/projects/pironman5/de/latest/pironman5_max/set_up/set_up_rpi_os.html#)]
Falls bei dem Prozess die Meldung `Try updating the rpi-eeprom APT package` erscheint, folgendes durchführen (Siehe [hier](https://wiki.geekworm.com/How_to_update_eeprom_firmware)):
```
sudo apt update
sudo apt upgrade -y
sudo rpi-eeprom-update
```
Ggf. muss in dem _Tool_ bei `Advanced Options` die neuste Version angewählt werden.

Ich habe danach nicht gebootet.

Wie die Software für das Pironman5 Modul zu installieren ist, steht [hier](https://docs.sunfounder.com/projects/pironman5/de/latest/pironman5_max/set_up/set_up_rpi_os.html#download-und-installation-des-moduls-pironman5) beschrieben.

## Localization einstellen
Dazu in der Datei `/etc/default/locale` Folgendes eintragen.
```
LANG=de_DE.UTF-8
LC_CTYPE=de_DE.UTF-8
LC_MESSAGES=de_DE.UTF-8
LC_ALL=de_DE.UTF-8
```

## swap-file vergrößern
Swapfile ist ausreichend; eigene Partition ist nicht nötig.

Swap vergrößern: Siehe [hier](RPi5/swapfile.md)

Ab hier ältere Versuche - ggf. löschen
```
# Disable the swap file:
sudo swapoff /var/swap 

# Delete the old swapfile:
sudo rm /var/swap 

# Create a new file with the desired size,  initialize and set permission:
sudo fallocate -l 8G /swapfile
sudo mkswap /swapfile 
sudo chmod 600 /swapfile

# Kontrolle:
sudo swapon --show
free -m
ls -l /swapfile 

# Make the changes permanent:
sudo nano /etc/fstab
# Einfügen der folgenden Zeile
/swapfile swap swap defaults 0 0
```

### Swapiness auf 20 verringern
```
sudo nano /etc/sysctl.conf
```

Add or modify the line `vm.swappiness=20`.  
Alternativ:
```
sudo bash -c "echo 'vm.swappiness = 15' >> /etc/sysctl.conf"
```

oder

Kernel-Tuning (sehr empfehlenswert)
```
sudo tee /etc/sysctl.d/99-server-tuning.conf <<EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=15
EOF
```

## Automatische Prüfung auf Linux-Updates
```
sudo apt update
sudo apt install unattended-upgrades apt-listchanges
```
```
sudo nano /etc/apt/apt.conf.d/20auto-upgrades
```
```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
```

sudo nano /etc/apt/apt.conf.d/50unattended-upgrades

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

```
sudo nano /etc/update-motd.d/98-reboot-required
```

```sh
#!/bin/sh
if [ -f /var/run/reboot-required ]; then
    echo "-----------------------------------------------"
    echo " *** NEUSTART ERFORDERLICH ***"
    if [ -f /var/run/reboot-required.pkgs ]; then
        echo " Ursache: $(cat /var/run/reboot-required.pkgs | tr '\n' ' ')"
    fi
    echo "-----------------------------------------------"
fi

# Hole die Liste der aktualisierbaren Pakete (ohne die Header-Zeile)
UPGRADABLE_LIST=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | grep -v "Auflistung...")

if [ -n "$UPGRADABLE_LIST" ]; then
    # Gesamtzahl berechnen
    TOTAL=$(echo "$UPGRADABLE_LIST" | wc -l)
    
    # Zähle die Pakete, die aus dem Security-Repository kommen (deine Konfiguration)
    AUTO_COUNT=$(echo "$UPGRADABLE_LIST" | grep -ic "security")
    
    # Die Differenz sind die manuell zu installierenden Pakete
    MANUAL_COUNT=$((TOTAL - AUTO_COUNT))

    echo "-------------------------------------------------"
    echo " Update-Zusammenfassung:"
    echo "  Gesamt verfügbar:    $TOTAL"
    echo "  Davon automatisch:   $AUTO_COUNT (Sicherheit)"
    echo "  Manuell erforderlich: $MANUAL_COUNT"
    
    if [ "$MANUAL_COUNT" -gt 0 ]; then
        echo ""
        echo " Nutzen Sie 'sudo apt upgrade' für die manuellen Updates."
    fi
    echo "-------------------------------------------------"
fi
```
Diese Datei zeigt an, ob Updates verfügbar sind.
### Wichtiger Hinweis zur Geschwindigkeit:
Der Befehl apt list --upgradable ist für ein Login-Skript gerade noch akzeptabel, braucht aber auf einem Raspberry Pi ca. 1–2 Sekunden. Falls dich die Verzögerung beim Login stört, könnte man das Skript so umbauen, dass es das Ergebnis in einer temporären Datei zwischenspeichert, die von einem Cronjob aktualisiert wird. Aber für 5–10 Pakete ist die obige Lösung die direkteste und einfachste.
```
sudo chmod +x /etc/update-motd.d/98-reboot-required
```

### Anzeige ob reboot required
```
sudo apt update && sudo apt install needrestart
```


## Bequemlichkeiten
### Promt
`PS1="\\[\\e[1;37;41m\\]𝜋5:\\[\\e[0m\\] \\w \\$ "`

### GUI Shortcuts
Mit dem Kommando `nano ~/.bashrc` die Stelle `#some more ls aliases` finden und 
die Eintrage für `ll` auf  
`alias ll='ls -lF'`  
ändern.

# Installation von Docker
Siehe https://docs.docker.com/engine/install/debian/#install-using-the-repository

```
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

# Install the Docker packages.
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# To verify that Docker is running, use:
sudo systemctl status docker
```

Nun noch den User `hajo` als docker Nutzer eintragen und `docker run` ohne `sudo` ausführen.
```
sudo adduser $USER docker
newgrp docker

docker run hello-world
```

## Memory
Das Kommando `docker info` fehlenden Memory Limit support:
```
...
WARNING: No memory limit support
WARNING: No swap limit support
```
Testen, wenn der erste richtige Container läuft.


Dies sorgt dafür, dass z.B. das Kommando `docker stats` keine Memory-Informationen anzeigt. Aus diesem Grund zeigt auch die [Monitor Docker component](https://github.com/ualex73/monitor_docker) keine Informationen zu Speicher-Nutzung, CPU, etc. an. Abhilfe schafft hier das Aktivieren der `memory cgroup` on Ubuntu 20.04  
Siehe dazu [hier](https://askubuntu.com/a/1237856).
In der Datei `/boot/firmware/cmdline.txt` den Wert `cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1` an den vorhandenen Eintrag anhängen:
```
usb-storage.quirks=152d:0578:u net.ifnames=0 dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=PARTUUID=42684546-01 rootfstype=ext4 elevator=deadline rootwait fixrtc cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
```


---

Dynamisches DNS einrichten bei IONOS:
https://www.ionos.de/hilfe/domains/ip-adresse-konfigurieren/dynamisches-dns-ddns-einrichten-bei-company-name/




Traefik:
Derzeit läuft traefik-nginx-bundle-hajo63


# Klären:
## Kernel Page Size: 
Achte darauf, dass der Pi 5 standardmäßig eine 16kb Page Size nutzt. Einige Docker-Anwendungen (insbesondere Datenbanken oder spezialisierte Bibliotheken wie jemalloc, die oft von HA genutzt werden) können damit Probleme haben. Falls Container abstürzen, kann ein Wechsel auf 4kb Pages in der config.txt notwendig sein.






