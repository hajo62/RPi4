# MariaDB
<img src="https://mariadb.org/wp-content/themes/twentynineteen-child/icons/logo_seal.svg" width="150" border="1">  

Im [Forum](https://community.home-assistant.io/search?q=database%20lock%20) wird immer mal wieder empfohlen, statt der eingebauten Datenbank auf **MariaDB** zu wechseln. Da ich auch diverse Datenbank-Lock-Einräge im HomeAssistant-Log beobachtet habe, habe ich auf MariaDB auf docker umgestellt.  

## Installation

Aus diesem [Blog](https://www.wouterbulten.nl/blog/tech/home-automation-setup-docker-compose/#mariadb) konnte ich den ersten Wurf für mein `docker-compose.yaml` ableiten. 
Hier der entsprechende Teil meiner `docker-compose.yaml`:  

```
version: '3.7'
services:
  mariadb:
    image: tobi312/rpi-mariadb
    container_name: mariadb
    restart: unless-stopped
    volumes:
      - /home/ubuntu/docker-volumes/mariadb:/var/lib/mysql
    environment:
      TZ=Europe/Berlin
      MYSQL_ROOT_PASSWORD: my-secret-pw
      MYSQL_USER: user
      MYSQL_PASSWORD: my-secret-pw
      MYSQL_DATABASE: user
    ports:
      - 3306:3306
````

Oder besser die Kennworte in die Datei `˜/.env` eintragen und hier referenzieren:

```
version: '3.7'
services:
  mariadb:
    image: tobi312/rpi-mariadb
    container_name: mariadb
    restart: unless-stopped
    volumes:
      - /home/hajo/docker-volumes/mariadb:/var/lib/mysql
    environment:
      TZ: Europe/Berlin
      MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
      MYSQL_DATABASE: ${MYSQL_DATABASE}
    ports:
      - 3306:3306
    healthcheck:
      test:  mysqladmin ping -h 127.0.0.1 -u root --password=$MYSQL_ROOT_PASSWORD || exit 1
      interval: 30s
      timeout: 5s
      retries: 5    
```

Mit dem Kommando `docker-compose pull mariadb` wird das Image heruntergeladen und mit `docker-compose up [-d] mariadb` gestartet.

## Konfiguration
-- keine Notizen gemacht --

## *Datenbank-Browser*
[Hier](https://dbeaver.io/) gibt es **DBeaver**, ein universelles Datenbank-Management-Tool für viele ppopuläre Datenbanken.