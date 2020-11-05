# Betriebssystem installieren
Meinen ersten Raspberry 3B+ habe ich im November 2018 mit [Raspbian Stretch with desktop](https://www.raspberrypi.org/downloads/raspbian), weil es zu dem Zeitpunkt noch kein ubuntu-Image gab. Da es inzwischen - November 2020 - ein offizielle ubuntu-Images für den Raspberry-Pi gibt, versuche ich es nun mit mit **ubuntu 20.04**.

Außerdem möchte ich das Betriebssyste von einer ssd-Platte booten, da mir in 2 Jahren bereits 2 SD-Karten _gestorben_ sind. Dazu muss aber das eeprom und die Firmware des Raspberry Pis aktualisert werden. Dies geht wohl mit mit Raspberry Pi OS, so dass dieses kurzzeitig auf der SD-Karte installiert werden muss. Wie **Raspberry Pi OS** installiert wird, habe ich - bis auf das im nächsten Abschnitt beschriebene Flashen der SD-Karte - [hier](./raspbian.md) beschrieben.

Nachdem eeprom und Firmware aktualisiert sind, kann ich nun ubuntu installieren.

## SD-Karte flashen
Eine Anleitung für die ersten Schritte gibt es [hier](https://www.bitblokes.de/ubuntu-20-04-lts-auf-raspberry-pi-installieren-und-einrichten-desktop) oder das _offizielle_ [Tutorial von ubuntu.com](https://ubuntu.com/tutorials/how-to-install-ubuntu-desktop-on-raspberry-pi-4#1-overview) die von ubuntu.com.

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
Beim ersten Login muss aber gleich das Kennwort geändert werden.

## USB-Boot ermöglichen
Für das booten von ssd muss ggf. die Firmeware im eeprom aktualisiert werden. Bei meinem Raspberry Pi 4 B von November 2020 war diese bereits auf dem notwendigen Stand. Es hätte also ausgereicht, nur den Abschnitt **USB boot aktivieren** in [Raspbian](./raspbian.mb) auszuführen.

Es gibt viele Bescheibungen; zuletzt bin ich dieser [Beschreibung](https://www.pragmaticlinux.com/2020/08/move-the-raspberry-pi-root-file-system-to-a-usb-drive/) und habe folgende Schritte ausgeführt:

SSD-Festplatte über USB anschließen, den Pi booten und einloggen.

Anzeigen der Datenträger.  
```
sudo lsblk
```

Mounten der SD-Karten und ssd-Platteb-Partitionen.
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

Kopieren des root-Filesystemd von der SD-Karte auf die ssd-Platte.
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

Unmount der Partitionen und entfernen der Mountpoints
```
sudo umount /mnt/usbdrive
sudo umount /mnt/sdboot
sudo umount /mnt/sdrootfs
sudo rmdir /mnt/usbdrive
sudo rmdir /mnt/sdboot
sudo rmdir /mnt/sdrootfs
```

Nach dem nächsten booten _sollte_ der Pi die boot-Partition der SD-Karte nutzen und anschließend die root-Partition von der ssd-Platte verwenden. Dies kann man überprüfen mit:
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
sudo hostnamectl set-hostname "RaspberryPi 4 B" --pretty
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
Das Kennwort für `root` löschen und den Eintrag ` PermitRootLogin yes` aus der Datei `/etc/ssh/sshd_config` entfernen:
```
sudo passwd -l root
sudo nano /etc/ssh/sshd_config
sudo service ssh restart
```

> Ich bin mir nicht sicher, ob der user `ubuntu` eine sudo ohne Kennworteingabe machen konnte, oder nicht. Der umbenannte User kann das jedenfalls nicht mehr!


## Nützliche Pakete
```
sudo apt install make       # Zum Software bauen
sudo apt install net-tools  # Für netstat
```

---
---
---
---
---

# RPi absichern
## ssh Standartport 22 verändern

Dazu in der Konfigurationsdatei `/etc/ssh/sshd_config` einen Port oberhalb von 1023 eintragen.  

```
[...]
Port 53022
#AddressFamily any
[...]
```

Nun noch mit `sudo service ssh restart` den ssh-Dämon neu starten, damit die geänderte Konfiguration aktiv wird. Ab jetzt muss bei jedem Remote Login der Port mit angegeben werden:  
`ssh ubuntu@192.168.178.112 -p 53022`

## ssh über Schlüsselpaar - ohne Kennwort
### OpenSSH Public Key Authentifizierung konfigurieren

Zuerst wird auf dem **_Client_** das Schlüsselpaar - bestehend aus public und private key - generiert und anschließend wird der public key zum Server übertragen. Der Private Schlüssel sollte mit einem Kennwort gesichert werden.  

Schlüsselpaar generieren:  
`ssh-keygen -b 4096 -f ~/.ssh/pi_rsa`

Öffentlichen Schlüssel auf den Ziel-Server übertragen:  
`ssh-copy-id -i ~/.ssh/pi_rsa.pub -p 53022 ubuntu@192.168.178.112`  

#### Privaten Schlüssel in keychain speichern
Da es lästig ist, immer wieder das Kennwort für den private key eingeben zu müssen, kann man diesen in der keychain des eigenen Clients speichern. Unter MacOS sieht geschieht dies mit:  
`ssh-add -K ~/.ssh/pi_rsa`

Von nun an ist es möglich, von diesem Client den RPi ohne Eingabe eines Kennwortes zu erreichen. Auch das _passende_ Zertifikat wird automatisch _gefunden_. Hier ein paar Beispielaufrufe:  

```
ssh ubuntu@192.168.178.112 -p 53022
sftp ubuntu@192.168.178.112 -p 53022
scp /tmp/tst ubuntu@192.168.178.112:/tmp/tst -p 53022
```

#### Permission denied (publickey)

Nach einem Update meines Macs funktionierte der ssh-Login nicht mehr. Abhilfe schaft das Kommando:  

```
ssh-add ~/.ssh/pi_rsa
Enter passphrase for /Users/hajo/.ssh/pi_rsa:
Identity added: /Users/hajo/.ssh/pi_rsa (/Users/hajo/.ssh/pi_rsa)
```

### ssh-login mit Kennwort deaktivieren

> **Achtung:** Wenn dies durchgeführt ist, kann man den Pi über ssh nicht mehr ohne die Private-Key-Datei erreichen!

In der Konfigurationsdatei `/etc/ssh/sshd_config` den Schlüssel `PasswordAuthentication` auf `no` setzen.

```
[...]
# To disable tunneled clear text passwords, change to no here!
PasswordAuthentication no
#PermitEmptyPasswords no
[...]
```

Nun wie schon bekannt, den ssh-Dämon neu starten:  
`sudo service ssh restart`

Ein Anmeldeversuch von einem Rechner ohne Zertifikat führt nun zu:  
`pi@192.168.178.112: Permission denied (publickey).`  

Wenn man nun einen weiteren Client zulassen möchte, muss man kurzfristig den ssh-login mit Kennwort wieder aktivieren.  


---
---
---

# Installation von Raspbian - (alt)

## Betriebssystem installieren
Ich hatte meinen Laptop viele Jahre mit ubuntu betrieben, so dass ich den Raspberry auch gern mit diesem Betriebssystem betrieben möchte. Im November 2018 ist aber leider noch keine [offizielles Image](https://www.raspberrypi.org/downloads/) für meinen Raspberry Pi 3 B+ verfügbar. Es gibt diverse Beschreibungen und ein inoffizielles [Image](https://pi-buch.info/ubuntu-mate-18-04-fuer-den-raspberry-pi-3b/) für ubuntu mate 18.04; ich war damit aber leider nicht erfolgreich.

Deshalb nutze ich bis auf weiteres [Raspbian Stretch with desktop](https://www.raspberrypi.org/downloads/raspbian). Die Installation geht mit diesem Image sehr einfach und hat darüber hinaus den Vorteil, dass man weder einen Monitor, noch eine Tastatur an den Raspberry anschließen muss.
* Download des [Images](https://downloads.raspberrypi.org/raspbian_latest). Das kleinere **Strech Lite** ohne Desktop wäre auch ausreichend.

* Das Image auf eine SD-Karte flashen.
Hierzu wird [Etcher](https://www.balena.io/etcher/) empfohlen.

* **ssh** für den Remotezugriff aktivieren:
Dazu muss man lediglich mit `touch /Volumes/boot/ssh` eine leere Datei `ssh` auf der boot-Partition auf der sd anlegen. (Je nach genutztem Rechner kann sich der Mount-Point "/Volumes" unterscheiden.)
* **wlan** aktivieren und konfigurieren:
Ein Beschreibung dazu findet sich [hier](https://pi-buch.info/wlan-schon-vor-der-installation-konfigurieren).
Dazu mit `nano /Volumes/boot/wpa_supplicant.conf` eine Datei im root-Verzeichnis der boot-Partition auf der SD-Karte anlegen und folgenden Inhalt eingeben:
```
country=DE
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
network={
       ssid="wlan-bezeichnung"
       psk="passwort"
       key_mgmt=WPA-PSK
}
```
Die SD-Karte in den Raspberry einlegen und diesen einschalten. Nach vielleicht einer Minute sollte sich der Raspberry im Netzwerk angemeldet haben und über `ssh pi@<ip-adresse>` erreichbar sein. Das Kennwort für den User pi lautet `raspberry` und sollte natürlich sofort geändert werden.

### Raspi konfigurieren
Mit `sudo raspi-config` die passenden Einstellungen vornehmen:
- Localization: de_DE.UTF-8 UTF-8
- Timezone Europe / Berlin

Ggf. noch die `locale` z.B. auf `de_DE.UTF-8 UTF-8` setzten. Dazu in der Datei `/etc/locale.gen` die entsprechende Zeile entkommentieren.
```
sudo nano /etc/locale.gen
sudo /usr/sbin/locale-gen
```

### Updates
Nun gilt es noch ggf. vorhandene Updates einzuspielen:
Dazu einloggen auf dem Raspberry Pi und mit apt-get aktualisieren.
```
sudo apt-get update
sudo apt-get upgrade
```

### Zeitsynchronisation
Da der Raspberry Pi über keine Echtzeituhr ([Real Time Clock - RTC](https://de.wikipedia.org/wiki/Echtzeituhr)) verfügt, sollte man die Zeit mit einem NTP-Zeitdienst automatisch aktualisieren. Mit dem Kommando `timedatectl status` lässt sich der Status überprüfen.
```
$ timedatectl status
      Local time: Mo 2018-11-12 10:38:32 CET
  Universal time: Mo 2018-11-12 09:38:32 UTC
        RTC time: n/a
       Time zone: Europe/Berlin (CET, +0100)
 Network time on: yes
NTP synchronized: yes
 RTC in local TZ: no
```
Nach meiner Interpretation bedeuten  `Network time on: yes` und `NTP synchronized: yes`, dass dies per Default aktiviert ist.  
Sollte die Zeitzone nicht korrekt sein, diese mit `sudo dpkg-reconfigure tzdata` korrigieren.  


### aliases einrichten
Ich bin gewohnt, dass man `ls -l` durch das Kommando `ll` abkürzen kann.

Hierfür einfach die gewünschten aliases mit dem Kommando `nano .bash_aliases` in die Datei `.bash_aliases` eintragen. Die Syntax für solche Einträge lautet:
```
alias ll='/bin/ls -l'
```

### Remote Desktop
Um auch den Desktop des Raspberry Pi remote öffnen zu können, installiert man einfach [VNC](https://wiki.ubuntuusers.de/VNC/).
```
sudo apt-get install realvnc-vnc-server realvnc-vnc-viewer
sudo raspi-config
```

Zum Menüpunkt **Interfacing Options** gehen;  anschließend zur Option **VNC** und dieses aktivieren.
<img src="./images/activate-vnc.jpg" width="700">

Den VNC-Viewer für MAC gibt es [hier](https://www.realvnc.com/en/connect/download/viewer).


### swap vergrößern
```
sudo swapon --show              # Zeigt swap-filename und aktuelle swap-Größe
sudo swapoff -av                # Leert swap-file und schaltet swap aus
sudo fallocate -l 1G /swap      # Vergößert die Swap-Datei auf 1G
sudo mkswap /swap
sudo swapon -av /swap
free -h
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab  # Swapfile permanent machen
```

### Zusätzliche Software-Pakete

> Da ich auf docker _umgestiegen_ bin, bin ich nicht sicher, ob davon noch etwas benötigt wird. 
#### node
Ein Beschreibung findet sich z.B. [hier](https://www.instructables.com/id/Install-Nodejs-and-Npm-on-Raspberry-Pi/):
```
cd /tmp
wget https://nodejs.org/dist/v10.14.2/node-v10.14.2-linux-armv6l.tar.xz
tar -xf node-v10.14.2-linux-armv6l.tar.xz
cd node-v10.14.2-linux-armv6l/
sudo cp -R * /usr/local/
```
Überprüfen mit `npm -v` und `node -v`.

Nun kann man eine erste minimale Hello World Web-Applikation erstellen:  
```
mkdir ~/Documents/HelloWorld
cd ~/Documents/HelloWorld
nano app.js
```
In die Datei `app.js` folgenden Inhalt eingeben:  
```node
const http = require('http');

const hostname = '127.0.0.1';
const port = 3000;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end('Hello World\n');
});

server.listen(port, hostname, () => {
  console.log(`Server running at http://${hostname}:${port}/`);
});

```

Bei Bedarf die kleine Web-App mit `node ~/Documents/HelloWorld/app.js` starten und mit `http://127.0.0.1:3000` prüfen.

---

Als nächstes gilt es, den Raspberry Pi [abzusichern](./security.md).
