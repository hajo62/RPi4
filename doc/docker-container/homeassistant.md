# Home Assistant mit docker
Eine Beschreibung zur Installation von HomeAssistant-Docker-Containern findet sich [hier](https://www.home-assistant.io/docs/installation/docker/). Dort wird davon ausgegangen, dass **docker** und **docker-compose** bereits installiert sind. [Hier](../docker.md) meine Beschreibung zur Installation von docker und docker-compose.

## Installation mit docker-compose
Anlegen der Datei `docker-compose.yaml`mit folgendem _Abschnitt_:

```
version: '3.7'
services:
  homeassistant:
    container_name: home-assistant
    image: homeassistant/raspberrypi3-homeassistant:stable
    depends_on:
      - mariadb
    volumes:
      - /home/hajo/docker-volumes/homeassistant:/config
      - /etc/localtime:/etc/localtime:ro
      # Used for monitor docker component
      # See: https://github.com/ualex73/monitor_docker
      - /var/run/docker.sock:/var/run/docker.sock
      # LetsEncrypt-Zertifikat-Dateien
      - /home/hajo/LetsEncrypt/certs/xxx.duckdns.org/:/etc/letsencrypt/
    # Macht expose überhaupt Sinn, wenn die Ports freigegeben werden?
    expose:
      - "8123"
    ports:
      - "8123:8123"
    restart: unless-stopped
    network_mode: host
```

Mit `docker-compose up [-d] homeassistant` wird nun der Container gestartet, bzw. wenn er noch nicht da ist, wird zuerst das Image herunter geladen und dann der Container gestartet.  
Restart des HomeAssistant-Container erfolgt mit dem Kommando `docker-compose restart homeassistant`.

Um mehrere Versionen des Images gleichzeitg vorhalten zu können, kennzeichne ich das Image noch mit einem _Version-Tag_:
```
docker tag homeassistant/raspberrypi3-homeassistant:stable homeassistant/raspberrypi3-homeassistant:v2021.1.1
```

# Update auf einen neuere Version

Da der Download und das Entpacken der Images recht lang dauert, fange ich mit dem Download an. Anschließend stoppe ich HomeAssistant und erstelle mit `rsync` eine Kopie des Konfiguration-Verzeichnisses, um dieses mit tar zu sichern. Gebraucht habe ich das bisher aber noch nie.


```
# Pull newest image. Takes a while to pull and extract
nice -n 19 docker-compose pull homeassistant

# Stoppen von HomeAssistant
docker-compose stop homeassistant

# Backup (Optional)
sudo rsync --archive -v $HOME/docker-volumes/homeassistant /tmp/ha.rsync
sudo tar cfvz $HOME/ha.tar.gz /tmp/ha.rsync

# Starten der neuen Version
docker-compose up -d homeassistant

# Wenn alles okay ist...
# Version-Tag setzen
# siehe oben

# Altes Image löschen
docker rmi <old IMAGE ID>
```
