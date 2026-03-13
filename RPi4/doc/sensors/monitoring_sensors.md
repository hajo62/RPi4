# System Monitoring
## Linux Update available
Der Lösungsansatz stammt von [hier](https://community.home-assistant.io/t/ha-on-ubuntu-monitor-available-os-updates/158417/3).

Über crontab den Befehl `/usr/lib/update-notifier/apt-check` ausführen und das Ergebnis in eine Datei schreiben, die man dann aus dem Homee-Container auslesen kann.  
Crontab-Eintrag:
```
0  */3  * * * /usr/lib/update-notifier/apt-check > /home/hajo/docker-volumes/homeassistant/OS_updates.out 2>&1
```


