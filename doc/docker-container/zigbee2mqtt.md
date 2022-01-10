# Zigbee2mqtt

Auf github ist ein [Zigbee zu MQTT](https://github.com/Koenkk/zigbee2mqtt) gateway Projekt verfügbar. Diese Software ermöglicht die Verwendung von Zigbee-Geräten ohne die Bridges oder die Gatewayes der Hersteller und ohne dass Daten in die Cloud der Hersteller übertragen werden.  
Neben der bereits sehr guten Beschreibung des [Autors](https://github.com/Koenkk) gibt es [hier](https://gadget-freakz.com/diy-zigbee-gateway/) und [hier](https://www.panbachi.de/eigenes-zigbee-gateway-bauen-93/) weitere nützliche Artikel und diesen [Forums-Thread](https://community.home-assistant.io/t/zigbee2mqtt-getting-rid-of-your-proprietary-zigbee-bridges-xiaomi-hue-tradfri).

## Hardware
Nach gut 2,5 Jahren hat der [CC2531-Stick](#Notwendige_Hardware) leider den Betrieb eingestellt, so dass ich mich nach einem neuen umschauen musste. Aus der [Liste der unterstützen Hardware](https://www.zigbee2mqtt.io/guide/adapters/) habe ich mich für den **SONOFF Zigbee 3.0 USB Dongle Plus** entschieden und bei dem im Artikel verlinkten Händler itead erworben. Die Lieferng aus China hat ca. 2 Wochen gedauert.

## Inbetriebnahme 
Die Inbetriebnahme war denkbar einfach.  
Stick (ohne Software-Update oder flashen) in den Pi stecken.  
Mit dem `dmesg`- oder dem `ls -l /dev/serial/by-id`-Befehl die USB-Portnummer bestimmen:
```
$ sudo dmesg | grep USB
...
[23139.790091] usb 1-1.1: new full-speed USB device number 3 using xhci_hcd
[23139.897315] usb 1-1.1: New USB device found, idVendor=10c4, idProduct=ea60, bcdDevice= 1.00
[23139.897331] usb 1-1.1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[23139.897342] usb 1-1.1: Product: Sonoff Zigbee 3.0 USB Dongle Plus
[23139.938013] usbserial: USB Serial support registered for generic
[23139.945419] usbserial: USB Serial support registered for cp210x
[23139.954418] usb 1-1.1: cp210x converter now attached to ttyUSB0
[72522.131036] usb 1-1.1: USB disconnect, device number 3
[72522.132839] cp210x ttyUSB0: cp210x converter now disconnected from ttyUSB0
[270865.864443] usb 1-1.1: new full-speed USB device number 4 using xhci_hcd
[270865.971562] usb 1-1.1: New USB device found, idVendor=10c4, idProduct=ea60, bcdDevice= 1.00
[270865.971577] usb 1-1.1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[270865.971588] usb 1-1.1: Product: Sonoff Zigbee 3.0 USB Dongle Plus
[270865.984758] usb 1-1.1: cp210x converter now attached to ttyUSB0
```
`ls -l /dev/serial/by-id`: 
```
ls -l /dev/serial/by-id
total 0
lrwxrwxrwx 1 root root 13 Jan  9 12:34 usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_8ec00336acc9eb1186858b4f1d69213e-if00-port0 -> ../../ttyUSB0
```

In meinem Fall war dies - wie in den Beschreibungen - `ttyUSB0`.

## zigbee2mqtt konfigurieren
Aus der alten Installation - s.u. - hatte ich noch den _alten_ `docker-compose.yaml`-Eintrag und die _alte_ Konfigurationsdatei. In diesen musste ich lediglich das neue _Device_ eintragen.  
`/home/hajo/docker-compose.yaml`:
``` 
  `zigbee2mqtt`:
    container_name: zigbee2mqtt
    image: koenkk/zigbee2mqtt
    depends_on:
      - mqtt
    volumes:
      - /home/hajo/docker-volumes/zigbee2mqtt/data:/app/data
      - /run/udev:/run/udev:ro
    ports:
      - 8082:8080
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0
    restart: unless-stopped
    network_mode: host
    environment:
      - TZ=Europe/Berlin
      #- DEBUG=zigbee-herdsman*
    healthcheck:
      test:  HEALTHCHECK CMD curl --fail http://localhost:8082/ || exit 1
      interval: 30s
      timeout: 5s
      retries: 5 
```

`/home/hajo/docker-volumes/zigbee2mqtt/data/configuration.yaml`:
```
homeassistant: true
permit_join: true
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://192.168.178.3
serial:
  port: /dev/ttyUSB0
frontend:
  port: 8082
devices:
  '0x00158d0002b5196f':
    friendly_name: XiaomiAqara-1
    retain: true
  '0x00158d00025ee3a6':
    friendly_name: XiaomiAqara-2
    retain: true
  '0x00158d0002e23355':
    friendly_name: XiaomiSmart-1
    retain: true
  '0x000b57fffe271050':
    friendly_name: '0x000b57fffe271050'
    retain: true
  '0x001788010406fad5':
    friendly_name: '0x001788010406fad5'
    retain: true
  '0xbc33acfffea2f23a':
    friendly_name: '0xbc33acfffea2f23a'
    retain: true
```

## Devices pairen
Um die Xiaomi-Devices mit dem neuen Zigbee-Coordinator zu pairen, muss der Knopf am Sensor ca. 5 Sekunden lang gedrückt gehalten werden, bis die Led blinkt.


---
# Altes Setup mit CC2531-Sniffer und nativer Installation auf dem RPi 3B+ !!!
---

## Notwendige Hardware
- [CC2531 Zigbee Sniffer](...): ca. 9 € - Darauf achten, dass der Stick die Debug-Pins zum anstecken des Kabels hat.
- [CC-Debugger](https://rover.ebay.com/rover/1/711-53200-19255-0/1?icep_id=114&ipn=icep&toolid=20004&campid=5338436153&mpre=https%3A%2F%2Fwww.ebay.com%2Fsch%2Fi.html%3F_from%3DR40%26_trksid%3Dm570.l1313%26_nkw%3DCC%2BDebugger%26_sacat%3D0%26LH_TitleDesc%3D0%26_osacat%3D0%26_odkw%3DCC2531%2Bgeh%25C3%25A4use%26LH_TitleDesc%3D0): ca. 9 €
- [Downloader-Kabel](https://rover.ebay.com/rover/1/711-53200-19255-0/1?icep_id=114&ipn=icep&toolid=20004&campid=5338436153&mpre=https%3A%2F%2Fwww.ebay.com%2Fsch%2Fi.html%3F_from%3DR40%26_trksid%3Dm570.l1313%26_nkw%3DBluetooth%2B4.0%2Bzigbee%2Bdownloader%2Bcable%26_sacat%3D0%26LH_TitleDesc%3D0%26_osacat%3D0%26_odkw%3DBluetooth%2B4.0%2Bzigbee%2Bcable%26LH_TitleDesc%3D0): ca. 2 €
- Und als ersten Sensor probiere ich den [Xiaomi Aqara](https://rover.ebay.com/rover/1/711-53200-19255-0/1?icep_id=114&ipn=icep&toolid=20004&campid=5338436153&mpre=https%3A%2F%2Fwww.ebay.com%2Fsch%2Fi.html%3F_from%3DR40%26_trksid%3Dm570.l1313%26_nkw%3DXiaomi%2BAqara%2Btemperature%2Bhumidity%26_sacat%3D0%26LH_TitleDesc%3D0%26_osacat%3D0%26_odkw%3DXiaomi%2BAqara%2Btemperature%26LH_TitleDesc%3D0) für Temperatur, Luftdruck und Feuchtigkeit: ca. 10,50 €

Leider kommen die Teile aus China, so dass es bis zu zwei Monaten dauert, bis sie ankommen. Wer es eiliger hat, findet bei [ebay-Kleinanzeigen](https://www.ebay-kleinanzeigen.de/s-cc2531-zigbee/k0) fertig präperierte Sticks und [hier](https://rover.ebay.com/rover/1/707-53477-19255-0/1?icep_id=114&ipn=icep&toolid=20004&campid=5338436153&mpre=https%3A%2F%2Fwww.ebay.de%2Fsch%2Fi.html%3F_from%3DR40%26_trksid%3Dm570.l1313%26_nkw%3DWSDCGQ11LM%26_sacat%3D0) für ein paar Euro mehr den Xiaomi Aqara Sensor geliefert aus Deutschland.

Ich werde mit diesem Teil erst mal bis Ende Februar warten, da ich das Flashen selbst machen möchte und die anderen Teile nicht in Deutschland gefunden habe...


---

## Flashen der Firmware auf den CC2531 USB Stick
### Vorbereitungen auf dem Mac
[Hier](https://github.com/Koenkk/zigbee2mqtt.io/blob/master/getting_started/flashing_the_cc2531.md) die Bescheibung, um das `cc-tool` zu erstellen:  
```
xcode-select --install
brew install autoconf automake libusb boost pkgconfig libtool
git clone https://github.com/dashesy/cc-tool.git
cd cc-tool
./bootstrap
./configure
make
```

### Flashen der Firmware
Download der Firmware CC2531ZNP-Prod.hex unter https://www.zigbee2mqtt.io/.

Flashen der Firmware:
```
sudo ./cc-tool -e -w /private/tmp/CC2531_DEFAULT_20190608/CC2531ZNP-Prod.hex
```
Nun den CC debugger mit dem Downloader cable an den CC2531 USB Sniffer anschließen und den Sniffer und den Debugger per USB an den Rechner anschließen. Das Flashen der neuen Firmware erfolgt mit diesem Kommando:
```
sudo ./cc-tool -e -w CC2531ZNP-Prod.hex
```

Nun sollte der Stick einsatzbereit ein.

---





---
# ALT!!!
---
## Native Installation aud dem Raspberry 3B+ unter Raspbian 
### Voraussetzungen
Zur Installation bin ich dieser [Anleitung](https://github.com/Koenkk/zigbee2mqtt.io/blob/master/getting_started/running_zigbee2mqtt.md) gefolgt.

Prüfen, ob node (>V10.x) und npm (>v6.x) mit den benötigten Versionen installiert sind. Falls nicht, diese installieren.
```
# Checken der node.js- und npm-Versionen und installation von node.js
node --version
npm --version

# Setup Node.js repository
sudo curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -

# Install Node.js
sudo apt-get install -y nodejs git make g++ gcc
```

### Download und Installation der zigbee2mqtt Software:
```
# Clone zigbee2mqtt repository
git clone https://github.com/Koenkk/zigbee2mqtt.git
cd zigbee2mqtt



sudo git clone https://github.com/Koenkk/zigbee2mqtt.git /opt/zigbee2mqtt
sudo chown -R pi:pi /opt/zigbee2mqtt

# Install dependencies
cd /opt/zigbee2mqtt
npm install
```

#### Konfiguration
Mit `nano /opt/zigbee2mqtt/data/configuration.yaml` die Konfigurationsdatei editieren. Hier den MQTT Server, User, Kennwort und den Port prüfen bzw. eintragen.  
`ls -l /dev/serial/by-id` zeigt an, als welches Device der Sniffer erkannt wird. Bei mir war dies `/dev/ttyACM0`. Es kam allerdings vor, dass dies nach dem booten sporadisch auch `/dev/ttyACM01` gewesen ist, so dass ich lieber gleich die Ausgabe von `ls -l /dev/serial/by-id` nutze.

Ich verwende derzeit den im Home Assistant _enthaltenen_ MQTT Broker, so dass die Datei wie folgt ausschaut:  
```
# Home Assistant integration (MQTT discovery)
homeassistant: false

# allow new devices to join
permit_join: true

# MQTT settings
mqtt:
  # MQTT base topic for zigbee2mqtt MQTT messages
  base_topic: zigbee2mqtt
  # MQTT server URL
  server: mqtt://localhost
  # MQTT server authentication, uncomment if required:
  user: homeassistant
  password: myPassword

# Serial settings
serial:
  # Location of CC2531 USB sniffer
  port: /dev/serial/by-id/usb-Texas_Instruments_TI_CC2531_USB_CDC___0X00124B00193648CA-if00
```

Bevor Zigbee2mqtt gestartet wird, sollte der mqtt-Broker (siehe [mqtt.md](./mqtt.md)) laufen.

#### Zigbee2mqtt starten
```
cd /opt/zigbee2mqtt
npm start
```
Stoppen mit <CTRL + C>.

### Devices pairen
#### Xiaomi Aqara pairen
Dazu den Knopf am Sensor 5 Sekunden lang gedrückt halten.

In der Shell erscheint die Nummer des Devices.

In `/opt/zigbee2mqtt/data/configuration.yaml` das Device ergänzen:
```
devices:
  '0x00158d0002b5196f':
    friendly_name: 'Temperatur Wohnzimmer'
    retain: false
```

`.homeassistant/configuration.yaml:`
```
mqtt:
  discovery: true
  discovery_prefix: homeassistant
```

Im Web-GUI des HA findet man bei Einstellungen / Integrationen / MQTT die ersten Werte...

##### Autostart von zigbee2mqtt
`sudo nano /etc/systemd/system/zigbee2mqtt.service`
```
[Unit]
Description=zigbee2mqtt
After=network.target

[Service]
ExecStart=/usr/local/bin/npm start
WorkingDirectory=/opt/zigbee2mqtt
StandardOutput=inherit
StandardError=inherit
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
```

##### Start zigbee2mqtt
`sudo systemctl start zigbee2mqtt`
`sudo systemctl enable zigbee2mqtt.service`

##### Show status
`systemctl status zigbee2mqtt.service`

##### View the log of zigbee2mqtt
`sudo journalctl -u zigbee2mqtt.service -f`





https://community.home-assistant.io/t/zigbee2mqtt-lovelace-custom-card-to-show-zigbee2mqtt-network-map/132088
