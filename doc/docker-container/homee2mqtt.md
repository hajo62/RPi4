# homee2mqtt
Auf dem RPi3B+ hatte ich ein Image selbst gebaut. Der Versuche es einfach zu übrtragen, und auf dem RPi4 zu nutzen hat nicht funktioniert.

```
docker save <573c7b50a2f4> > ./homee2mqtt.tar
scp -P 53122 ubuntu@192.168.178.112:/home/ubuntu/homee2mqtt.tar.gz ./homee2mqtt.tar.gz
scp -P 53122 ./homee2mqtt.tar.gz hajo@192.168.178.3:/home/hajo/homee2mqtt.tar.gz
docker tag 573c7b50a2f4 hajo/home2mqtt:10-0.0.2
```

`docker pull` geht dann leider nicht.
```
Error response from daemon: pull access denied for hajo/homee2mqtt, repository does not exist or may require 'docker login': denied: requested access to the resource is denied
```
Also habe ich das Image neu gebaut. 
> **Anmerkung**: Schritt 4 beim docker build schlägt fehl, wenn ich den Pi-Hole als DNS eingestellt habe. Hier sollte `8.8.8.8` oder die Fritzbox selbst verwendet werden!

## Source laden
[Hier](https://github.com/odig/homeeToMqtt) gibt es github-Repo für eine **MQTT**-Integration für **homee**. Zur Installation habe ich das Repo in ein Verzeichnis `~/homeeToMqtt_src` geclont und mit dem Befehl `npm i` installiert.

```
mkdir ~/src
cd ~/src
git clone https://github.com/odig/homeeToMqtt

cd homeeToMqtt
npm i
```

## Docker-Image erstellen
Als nächstes baue ich ein Docker-Image.
Um das Image bauen zu können, wird eine Datei `~/src/homeeToMqtt/Dockerfile` mit folgendem Inhalt angelegt:
```
FROM node:10-slim

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY package*.json ./

# RUN npm install
# If you are building your code for production
RUN npm ci --only=production

# Bundle app source
COPY . .

CMD [ "node", "app.js" ]
```

Nun kann mit folgendem Befehl das Docker-Image gebaut werden:
```
docker build -t hajo/homee2mqtt:10-0.0.4 .
```

Nachdem das Image erstellt wurde, ist es in der docker-Registry vorhanden. Anzeigen mit:  
```
docker images
```

## Konfiguration
Die Konfiguration wird in der Datei `~/docker-volumes/homee2mqtt/config.json` erstellt:
```
{
    "homeeUserName": "<Homee User Name>",
    "homeePassword": "<Homee User Password>",
    "homeeServer": "<Homee IP-Adresse",
    "mqttServer": "<HomeAssistant IP-Adresse",
    "mqttUserName": "mosquitto",
    "mqttpassword": "",
    "publish": true,
    "publishHuman": true,
    "publishInt": false,
    "publishBool": true,
    "subscribe": true,
    "subscribeHuman": true,
    "identifier": "devices/status/",
    "identifierHuman": "human/",
    "identifierInt": "devices/int/",
    "identifierBool": "devices/bool/",
    "filterEchoedMQTTMessages": false,
    "homeeStatusRepeat": false,
    "statusTimer": 180
}
```

## Docker-Image starten
Dazu erweitert man die Datei `docker-compose.yaml` um folgenden Block und startet anschließend den Container mit `docker-cpmpose up [-d] homee2mqtt`.
```
    homee2mqtt:
      container_name: homee2mqtt
      image: hajo/homee2mqtt:10-0.0.4
      depends_on:
        - mqtt
      volumes:
        - /home/hajo/docker-volumes/homee2mqtt:/etc/homeeToMqtt
      restart: unless-stopped
      network_mode: host
```

Ggf. noch die Logs kontrollieren:
```
docker-compose  logs -f homee2mqtt
```



