# Tips und Tricks
Hier eine Sammlung von kleineren Tips Tricks.

## Disk Space
Von [hier](https://itsfoss.com/free-up-space-ubuntu-linux/) habe ich diesen Tip zum Freimachen von Plattenplatz. Hat bei mir beim ersten mal 3.2 GB frei gemacht.
```
du -sh /var/log/journal
journalctl --disk-usage             # Zeigt den verwendeten Platz an. Bei mir waren das 4.0G

sudo journalctl --rotate
sudo journalctl --vacuum-time=30d   # Behält 'nur' noch die letzten 30 Tage. Bei mir wurden dadurch 3.2 GB freigemacht.

journalctl --disk-usage
```

Das war auch der größte Batzen. Weitere Info zu journal files gibt's [hier](https://linuxhandbook.com/clear-systemd-journal-logs/).

> Aber mal beobachten. Ein paar Tage später konnte ich wieder ca. 700 MB frei machen...  
Evtl. hilft `--rotate`.