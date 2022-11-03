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

Oder besser die Kennworte in die Datei `˜/.env` eintragen und hier _nur_ referenzieren. Außerdem habe ich nun noch auf das Docker Official Image umgestellt:

```
version: '3.8'
services:
  homeassistant-db:
    image: mariadb
    container_name: homeassistant-db
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
-- Leider keine Notizen gemacht --  
Aber [hier](https://www.nickneos.com/2020/09/14/migrating-home-assistant/) findet sich dazu einiges.


## Version checken
Dazu im Container das Kommando `mariadb -V` ausführen:
```
docker exec homeassistant-db mariadb -V
```


## *Datenbank-Browser*
[Hier](https://dbeaver.io/) gibt es **DBeaver**, ein universelles Datenbank-Management-Tool für viele populäre Datenbanken. Damit kann man einen Blick in die Datenbank werfen und ich habe auch schon mal _falsche_ Werte gelöscht.





## Security
Diese Meldung kam beim ersten Start:
> PLEASE REMEMBER TO SET A PASSWORD FOR THE MariaDB root USER !
To do so, start the server, then issue the following command:
> ```
> /usr/bin/mysql_secure_installation
> ```
> which will also give you the option of removing the test  databases and anonymous user created by default.  This is strongly recommended for production servers.
