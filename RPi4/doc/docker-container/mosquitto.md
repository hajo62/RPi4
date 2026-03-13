# MQTT-Server
## Open Port 1883 and start firewall
Damit man den Broker von außen erreichen kann, muss vor dem Start des brokers Port 1883 geöffnet werden.

## Verbindung über UserID/Passwortabsichern
In der Datei `config/mosquitto.conf` wird die Passwortdatei angegeben. 
```
password_file /mosquitto/config/passwd
allow_anonymous false
```
Kennworte werden dann über dieses Kommando gesetzt:
```
docker-compose exec mqtt mosquitto_passwd -c /mosquitto/config/passwd hajo
```

## Links
https://hometechhacker.com/mqtt-home-assistant-using-docker-eclipse-mosquitto/#Setting_up_MQTT_in_Docker_using_Eclipse_Mosquitto
https://spectechular.de/post/lokalen-mqtt-server-mit-docker-betreiben/


https://hackaday.io/project/12482-garage-door-opener/log/43367-using-a-username-and-password-for-mqtt

Hier scheint ein Kennwort gesetzt zu werden ;)
docker-compose exec mqtt /bin/sh -c "touch /tmp/passwd && mosquitto_passwd -b /tmp/passwd hajo mymqttRat1onal! && cat /tmp/passwd && rm /tmp/passwd" > docker-volumes/mosquitto/config/passwd