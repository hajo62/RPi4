# Xiaomi Mijia BT Hygrothermo - Temperatur- und Luftfeuchtigkeitssensor

## ubuntu 22.04
Probeme mit Blutooth  
Bluettooth war unter Linux nicht mehr verfügbar.  
Siehe https://forums.dolphin-emu.org/Thread-howto-disable-apparmor-for-bluetooth-wiimote-support-in-ubuntu


`sudo hcitool lescan` liefert Fehler `Device not found`.

```
sudo hciconfig hci0 down
sudo hciconfig hci0 up
```



## Installation (ubuntu 20.04)

Anscheinend funktioniert Bluetooth unter ubuntu 20.04 nach der Installation nicht richtig. `sudo hcitool lescan` liefert Fehler `Device not found`.


Erster Tipp, den ich dazu gefunden habe:
```
sudo snap install bluez
# oder 
sudo apt-get install bluez
```

Hat aber nicht zum Erfolg geführt. Ob man das braucht, oder ob der nachfolgende Befehl allein ausreicht, weiß ich nicht:
```
sudo apt install pi-bluetooth
sudo reboot
```

Es gibt zwei Integration.  
Die z.B. über HACS verfügbare [Integration](https://github.com/custom-components/sensor.mitemp_bt) scheint mir die neuere/bessere zu sein.  
Installation einfach über HACS.  
Hier ein Beispiel für die `configuration.yaml`:  
```
  - platform: mitemp_bt
    rounding: True
    decimals: 1
    period: 60
    log_spikes: False
    use_median: False
    active_scan: False
    hci_interface: 0
    batt_entities: True
#    encryptors:
#              'A4:C1:38:2F:86:6C'
    report_unknown: False
    whitelist: False
```




---

## (Vorherige) Installation auf Raspbian
Die Beschreibung der Sensor-Platform findet sich [hier](https://www.home-assistant.io/components/mitemp_bt/).  
Und [hier](https://github.com/dolezsa/Xiaomi_Hygrothermo) gibt es die benötigte `sensor.py`-Datei. Diese kopiert man z.B. mit curl in das Verzeichnis `/home/pi/homeassistant/custom_components/xiaomi_hygrothermo`.  
```
curl https://github.com/dolezsa/Xiaomi_Hygrothermo/blob/master/custom_components/xiaomi_hygrothermo/sensor.py -o sensor.py
```

Wie die Mac-Adresse des Sensors bestimmt wird, wird ebenfalls in obigem Link beschrieben:
```
$ sudo hcitool lescan
LE Scan ...
[...]
71:AB:1A:xx:xx:xx (unknown)
4C:65:A8:DD:xx:xx MJ_HT_V1
[...]
```

Anschließend muss man den Sensor noch bekannt machen, indem man in die Datei `sensors.yaml` folgenden Eintrag einfügt:
```
- name: Hygrothermo_1
  mac: '4C:65:A8:DD:xx:xx'
  scan_interval: 60
  monitored_conditions:
    - temperature
    - humidity
    - battery
```

Nach dem Restart erscheinen die Sensoren:  
<img src="../images/sensors/xiaomi_mijia_temp_humidity.jpg" width="300" border="1">

## Unregelmäßiger Verbindungsabbruch

Von Zeit zu Zeit verliert der RPi die Verbindung zum Sensor. Zum erneuten Verbinden muss der RPi gebootet werden. Ein Restart des Bluetooth Modems reicht nicht aus. Siehe [github issue](https://github.com/raspberrypi/linux/issues/2832).

Dort steht ein kleines Skript zum Reset des Bluetooth-Modems:  

```
sudo killall hciattach
if grep -a Zero /proc/device-tree/model; then
  raspi-gpio set 45 op dl
  sleep 1
  raspi-gpio set 45 op dh
else
  /opt/vc/bin/vcmailbox 0x38041 8 8 128 0
  sleep 1
  /opt/vc/bin/vcmailbox 0x38041 8 8 128 1
fi
sleep 4
sudo btuart
```

Ist evtl. ganz nützlich, hilft aber bei diesem Problem nicht.

Als temporäre Lösung wird im o.a. Issue das Kommando `sudo rpi-update` beschrieben. Hierdurch wird eine Beta-Version (4.19.102-v7+ #1295) des Kernels eingespielt.