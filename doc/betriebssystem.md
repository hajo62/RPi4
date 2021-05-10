# Betriebssystem installieren
Meinen ersten Raspberry 3B+ habe ich im November 2018 mit [Raspbian Stretch with desktop](https://www.raspberrypi.org/downloads/raspbian), weil es zu dem Zeitpunkt noch kein ubuntu-Image gab. Da es inzwischen - November 2020 - ein offizielle ubuntu-Images für den Raspberry-Pi gibt, versuche ich es nun mit mit **ubuntu 20.04** LTS.

Außerdem möchte ich das Betriebssystem von einer ssd-Platte booten, da mir in 2 Jahren bereits 2 SD-Karten _gestorben_ sind. Dazu muss aber das eeprom und die Firmware des Raspberry Pis aktualisert werden. Dies geht wohl mit mit Raspberry Pi OS, so dass dieses kurzzeitig auf der SD-Karte installiert werden muss. Wie **Raspberry Pi OS** installiert wird, habe ich - bis auf das im nächsten Abschnitt beschriebene Flashen der SD-Karte - [hier](./raspbian.md) beschrieben.

Nachdem eeprom und Firmware aktualisiert sind, kann ich nun ubuntu installieren.

## SD-Karte flashen
Eine Anleitung für die ersten Schritte gibt es [hier](https://www.bitblokes.de/ubuntu-20-04-lts-auf-raspberry-pi-installieren-und-einrichten-desktop) oder das _offizielle_ [Tutorial](https://ubuntu.com/tutorials/how-to-install-ubuntu-desktop-on-raspberry-pi-4#1-overview) von ubuntu.com.

ubuntu-Images gibt es auf der offiziellen [ubuntu.com](https://ubuntu.com/download/raspberry-pi)-Website. 
Ich nutze [ubuntu20.04.1 Server 64 bit](https://ubuntu.com/download/raspberry-pi/thank-you?version=20.04.1&architecture=server-arm64+raspi).

Um eine SD-Karte zu brennen, kann man z.B. [Etcher](https://www.balena.io/etcher/) oder den [Raspberry Pi Imager](https://www.raspberrypi.org/downloads/) verwenden. Mit Letzterem ist das ganz einfach:  
Entweder mit **CHOOSE OS** das passende Betriebssystem auswählen oder mit **Use custom** einen vorher gemachten Download auswählen.

## WLAN einrichten
Falls man WLAN aktivieren möchte, muss man nach dem Flashen die SD-Karte erneut auf dem Laptop mounten und die Datei `network-config` editieren. Hier ein Beispiel:
```
wifis:
  wlan0:
  dhcp4: true
  optional: true
  access-points:
    "home network":
      password: "123456789"
```

> Angeblich muss man zweimal booten, ehe die Verbindung über WLAN klappt.

Ich habe mich entschlossen, WLAN nicht zu aktiviert.

## ssh
**ssh** für den Remotezugriff ist per default aktiviert.  
Beim ersten Login muss aber gleich das Kennwort geändert werden. Also am besten vorher eines überlegen. 😏

## USB-Boot ermöglichen
Für das booten von ssd muss ggf. die Firmware im eeprom aktualisiert werden. Bei meinem Raspberry Pi 4B von November 2020 war diese bereits auf dem notwendigen Stand. Es hätte also ausgereicht, nur den Abschnitt **USB boot aktivieren** in [Raspbian](https://github.com/hajo62/RPi4/blob/master/doc/raspbian.md#usb-boot-aktivieren) auszuführen.

Es gibt viele Beschreibungen; zuletzt bin ich dieser [Beschreibung](https://www.pragmaticlinux.com/2020/08/move-the-raspberry-pi-root-file-system-to-a-usb-drive/) gefolgt und habe folgende Schritte ausgeführt:

SSD-Festplatte über USB anschließen, den Pi booten und einloggen.

Anzeigen der Datenträger.  
```
sudo lsblk
```

Mounten der SD-Karten und ssd-Platten-Partitionen.
```
sudo mkdir -p /mnt/usbdrive
sudo mkdir -p /mnt/sdboot
sudo mkdir -p /mnt/sdrootfs
sudo mount /dev/sda1 /mnt/usbdrive
sudo mount /dev/mmcblk0p1 /mnt/sdboot
sudo mount /dev/mmcblk0p2 /mnt/sdrootfs
# Checken
lsblk -p | grep "disk\|part"
```

Kopieren des root-Filesystems von der SD-Karte auf die ssd-Platte.
```
sudo rsync -axv /mnt/sdrootfs/* /mnt/usbdrive
```

Mappen der Filesysteme.
```
# PARTUUID bestimmen
sudo blkid | grep "/dev/sda1"

/dev/sda1: UUID="07aef758-94ed-4792-bc8b-11d0be85746d" TYPE="ext4" PARTUUID="42684546-01"
```

Sichern und Editieren der bootloader-Parameterdatei
```
sudo cp /mnt/sdboot/cmdline.txt /mnt/sdboot/cmdline.org
sudo nano /mnt/sdboot/cmdline.txt
```

Für meinen speziellen sata-usb-Controller muss noch eine spezielle Anpassung in der bootloader-Parameterdatei vorgenommen werden, damit die Platte während des Bootvorgangs erkannt wird.

Den spezifischen Wert für meinen Controller `152d:0578` erhält man über das Kommando `lsusb`:
```
$ lsusb
Bus 002 Device 002: ID 152d:0578 JMicron Technology Corp. / JMicron USA Technology Corp. JMS567 SATA 6Gb/s bridge
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 001 Device 002: ID 2109:3431 VIA Labs, Inc. Hub
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
```

Die bootloader-Parameterdatei muss (vorn) noch um den Wert `
usb-storage.quirks=152d:0578:u` erweitert werden.

Das Ergebnis schaut bei mir dann so aus:
```
$cat /boot/firmware/cmdline.txt

usb-storage.quirks=152d:0578:u net.ifnames=0 dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=PARTUUID=42684546-01 rootfstype=ext4 elevator=deadline rootwait fixrtc
```
Die Datei darf keinen Zeilenumbruch enthalten.

```
# Sichern und Editieren der Filesystem Tabelle
sudo cp /mnt/usbdrive/etc/fstab /mnt/usbdrive/etc/fstab.org
sudo nano /mnt/usbdrive/etc/fstab
```

Bei mir schaut die Datei `fstab` dann so aus:
```
cat /mnt/usbdrive/etc/fstab

PARTUUID=42684546-01	/	 ext4	defaults	0 0
LABEL=system-boot       /boot/firmware  vfat    defaults        0       1
```

Unmount der Partitionen und entfernen der Mountpoints:
```
sudo umount /mnt/usbdrive
sudo umount /mnt/sdboot
sudo umount /mnt/sdrootfs
sudo rmdir /mnt/usbdrive
sudo rmdir /mnt/sdboot
sudo rmdir /mnt/sdrootfs
```

Nach dem nächsten booten _sollte_ der Pi die **boot**-Partition der SD-Karte nutzen und anschließend die **root**-Partition von der ssd-Platte verwenden. Dies kann man überprüfen mit:
```
sudo lsblk -p | grep "disk\|part"
/dev/sda           8:0    0 238.5G  0 disk 
└─/dev/sda1        8:1    0 238.5G  0 part /
/dev/mmcblk0     179:0    0  59.6G  0 disk 
├─/dev/mmcblk0p1 179:1    0   256M  0 part /boot/firmware
└─/dev/mmcblk0p2 179:2    0  59.4G  0 part 
```

Nun ist es an der Zeit, das initiale Setup abzuschließen.

## Betriebssystem aktualisieren
```
sudo apt-get update
sudo apt-get upgrade
```

## Zeitzone und Zeitsynchronisation
### Zeitzone
Nach dem upgrade erschien die Meldung:
```
Current default time zone: 'Etc/UTC'
Local time is now:      Sun Nov  1 14:33:49 UTC 2020.
Universal Time is now:  Sun Nov  1 14:33:49 UTC 2020.
Run 'dpkg-reconfigure tzdata' if you wish to change it.
```

Diesem Hinweis bin ich gefolgt. Bei ubuntu 20.10 habe ich das schon mal mit nachfolgendem Befehl gemacht:
```
sudo timedatectl set-timezone Europe/Berlin
``` 

### Zeitsynchronisation
Da der Raspberry Pi über keine Echtzeituhr ([Real Time Clock - RTC](https://de.wikipedia.org/wiki/Echtzeituhr)) verfügt, sollte man die Zeit mit einem NTP-Zeitdienst automatisch aktualisieren. Mit diesem Kommando lässt sich der Status überprüfen:
```
timedatectl status
```

Nach meiner Interpretation bedeutet die nachfolgende Ausgabe, dass dies per Default aktiviert ist.
```
System clock synchronized: yes
NTP service: active
```

## hostname ändern
Ändern des Hostnamens von `ubuntu` z.B. in `rpi4b`.
```
sudo hostnamectl set-hostname rpi4b
sudo hostnamectl set-hostname "RaspberryPi 4B" --pretty
```

## username ändern
Ändern des Usernamens von `ubuntu` z.B. in `hajo`. Ein Username lässt nicht ändern, wenn der User angemeldet ist. Daher muss man entweder einen anderen User anlegen und diesen nutzen, oder kurzfristig `root` das Recht zum Login geben (`PermitRootLogin yes` in die Datei `/etc/ssh/sshd_config` einfügen) und ein Kennwort vergeben.

```
sudo nano /etc/ssh/sshd_config
sudo service ssh restart
sudo passwd root
```

Nun ausloggen und als root wieder einloggen.
```
usermod -l hajo ubuntu
groupmod -n hajo ubuntu
mv /home/ubuntu/ /home/hajo
usermod -d /home/hajo hajo
```

Nun als `root` abmelden und als `hajo` anmelden.  
Das Kennwort für `root` löschen und den Eintrag ` PermitRootLogin yes` aus der Datei `/etc/ssh/sshd_config` wieder entfernen:
```
sudo passwd -l root
sudo nano /etc/ssh/sshd_config
sudo service ssh restart
```

> Ich bin mir nicht sicher, ob der user `ubuntu` ein `sudo` ohne Kennworteingabe machen konnte, oder nicht. Der umbenannte User kann das jedenfalls nicht mehr!


## Nützliche Pakete
```
sudo apt install make               # Zum Software bauen
sudo apt install net-tools          # Für netstat
sudo apt-get install openssh-client # Wird für VisualStudio Code remote Edit benötigt
sudo apt install npm                # Z.B: zum bauen des homeetomqtt-Images
sudo apt-get install cifs-utils     # Zum mounten von NAS drives
sudo apt-get install keyutils       # Für den Zugriff auf den keyring

# sudo apt install gitsome    # Für github

```

Bei Zeiten mal nachlesen, ob hier noch was nützliches dabei ist:  
http://raspberry.tips/raspberrypi-tutorials/raspberry-pi-performance-tuning-und-tweaks

https://www.proudcommerce.com/devops/buero-dashboard-mit-raspberry-pi-co2-sensor-und-grafana