# Raspberry Pi OS installieren

Um den Raspberry Pi 4 B von einer ssd-Platte (ohne SD-Karte) booten zu können, muss (Stand November 2020) das eeprom aktualisiert werden. Mit ubuntu scheint das (nicht so einfach) zu gehen, weshalb ich hierfür **Raspberry Pi OS** installiere.

Da ich dies ausschließlich zum Aktualisieren des eeproms nutze und anschließend gleich durch ubuntu ersetzen möchte, ist [Raspberry Pi OS (32-bit) Lite](https://www.raspberrypi.org/downloads/raspbian) ausreichend.

## Das Image auf eine SD-Karte flashen
Siehe Abschnitt SD-Karte flashen in [Betriebssystem](./betriebssystem.md).

## Remote-Zugriff
Im Gegensatz zu ubuntu ist **ssh** bei Raspberry Pi OS nicht standartmäßig aktiviert. Zum Aktivieren muss man mit `touch /Volumes/boot/ssh` eine leere Datei `ssh` auf der boot-Partition auf der sd-Karte anlegen.  
(Je nach genutztem Client-Rechner kann sich der Mount-Point "/Volumes" unterscheiden.)

Die SD-Karte in den Raspberry einlegen und diesen einschalten. Nach vielleicht einer Minute sollte sich der Raspberry im Netzwerk angemeldet haben und über `ssh pi@<ip-adresse>` erreichbar sein. Das Kennwort für den User `pi` lautet `raspberry` und sollte _eigentlich_ sofort geändert werden.

## Betriebssystem, Kernel und eeprom updaten
### Betriebssystem
Nun gilt es noch vorhandene Linux-Updates einzuspielen:
Dazu einloggen auf dem Raspberry Pi und mit apt-get aktualisieren:
```
sudo apt-get update
sudo apt-get upgrade
```

### Kernel
Kernel aktualisieren:
```
sudo rpi-udpate
sudo reboot
```

### Firmware -  eeprom
Nachdem der Pi neu gestartet wurde, kann die Firmware aktualisiert werden. 
```
sudo rpi-eeprom-update
```
Bei mir stellt sich heraus, dass die Firmware bereits auf dem aktuellsten Stand gewesen ist.

```
$ sudo rpi-eeprom-update
BCM2711 detected
VL805 firmware in bootloader EEPROM
BOOTLOADER: up-to-date
CURRENT: Thu Sep  3 12:11:43 UTC 2020 (1599135103)
 LATEST: Thu Sep  3 12:11:43 UTC 2020 (1599135103)
 FW DIR: /lib/firmware/raspberrypi/bootloader/critical
VL805: up-to-date
CURRENT: 000138a1
 LATEST: 000138a1
```

## USB boot aktivieren
Hierfür wir die Datei `/boot/config.txt` um den Eintrag `program_usb_boot_mode=1` erweitert und der Pi einmal rebootet, damit die Einstellung in die Firmware des Pi übernommen wird.

Das eeprom und die Firmware des Pi ist nun aktualisiert und dieser kann nun von usb-Speichern booten.


---


## Alte Aufzeichnungs-Schnippsel
Ab hier Aufzeichnungsreste für das booten von Raspbian Pi OS von ssd-Karte.


net.ifnames=0 dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=LABEL=writable rootfstype=ext4 elevator=deadline rootwait fixrtc


net.ifnames=0 dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=LABEL=writable rootfstype=ext4 elevator=deadline rootwait fixrtc root=/dev/sda1 rootfstype=ext4 rootwait


Bootet von SD:
net.ifnames=0 dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 elevator=deadline rootwait fixrtc root=/dev/mmcblk0p2 rootfstype=ext4 rootwait


