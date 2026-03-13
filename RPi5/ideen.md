
## Lokale Zugriffe auch über https
Traefik und owncloud und Fritzbox oder Pi-Hole.  
Split-Brain DNS (Optional): Für maximale Sicherheit können Sie in Ihrem lokalen Netzwerk (z.B. über Pi-hole) einen DNS-Eintrag setzen, der cloud.deine-domain.de direkt auf die interne IP des Pi leitet. So nutzen Sie auch intern HTTPS über Traefik, haben aber den Port 8080 als "physikalischen" Notausgang.

DNS-Rebind-Schutz auf FritzBox einstellen:
Loggen Sie sich auf Ihrer FritzBox ein.
Navigieren Sie zu: Heimnetz -> Netzwerk -> Reiter Netzwerkeinstellungen.
Scrollen Sie ganz nach unten (ggf. die „Erweiterte Ansicht“ oben rechts aktivieren).
Suchen Sie das Feld DNS-Rebind-Schutz.
Tragen Sie dort Ihre Domain ein: cloud.deine-domain.de.
Klicken Sie auf Übernehmen.
Siehe: https://schroederdennis.de/pi-hole/pi-hole-installation-einrichtung-raspberry-pi-fritzbox-konfiguration-adblocker/#:~:text=Wir%20loggen%20uns%20wieder%20auf%20der%20Fritzbox,unten%20und%20sehen%20das%20Feld%20Lokaler%20DNS%2DServer.





## Docker-Socket-Schutz
Der Zugriff von Tarefik auf /var/run/docker.sock ist ein hohes Sicherheitsrisiko (Container-Escape).
Best Practice: Verwenden Sie einen Socket-Proxy (z.B. tecnativa/docker-socket-proxy), der Traefik nur lesenden Zugriff auf notwendige API-Endpunkte erlaubt, anstatt den Socket direkt zu mounten. 