# Pi-Hole
## Installation
`ubuntu 20.04` stellt nach der Installation einen einfachen DNS- und DHCP-Server für kleine Netzwerke bereit. Dieser nutzt den Port 53.  

Pi-Hole startet nicht, da Port 53 durch diesen `caching DNS stub resolver` blockiert ist. Der nachfolgende Befehl zeigt den Namensauflösungsdienst `systemd-resolve` auf Port 53 an (Siehe [hier](https://github.com/pi-hole/docker-pi-hole#installing-on-ubuntu)):
```
sudo lsof -i :53
```
Dieser Dienst wird nicht benötigt, insbesondere, da Pi-Hole selbst als DNS-Server dient, so dass dieser Dienst deaktiviert werden:

```
sudo sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf

sudo sh -c 'rm /etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf'

systemctl restart systemd-resolved
```

Der Befehl `sudo lsof -i :53` zeigt nun nichts mehr an.

Eine Beschreibung wie man die Datei `docker-compose.yaml` erstellt, gibt es [hier](https://www.laub-home.de/wiki/Pi-hole_mit_Docker_Compose_auf_dem_Raspberry_Pi).


```
services:
  pihole:
    image: pihole/pihole:latest
    container_name: PiHole
    env_file: .env
    restart: unless-stopped
    volumes:
      - /home/hajo/docker/pihole/pihole/:/etc/pihole/
      - /home/hajo/docker/pihole/dnsmasq.d/:/etc/dnsmasq.d/
    ports:
      - "53:53/tcp"
      - "53:53/udp"
    environment:
      - TZ=Europe/Berlin
      - WEBPASSWORD=${PIHOLE_WEBPASSWORD}
      - ServerIP=${PIHOLE_IP}
      #ServerIP: "${IP}"
      #DNS1: "127.0.0.1"
      #DNS2: "192.168.10.221"
    dns:
      - 127.0.0.1       # Required for local names resolution
      - 1.1.1.1         # Required during startup when Pi-Hole is not fully started
    cap_add:
      - NET_ADMIN
    network_mode: host
```

 `.env`
```
PIHOLE_WEBPASSWORD=myPassword
PIHOLE_IP=<IP>
```

Nun ist das Pi-Hole-Web-Interface über die IP-Adresse des Pi verfügbar.

## Konfiguration
> Auf der Fritzbox habe ich **IPv6** deaktiviert.   
Ob das notwendig ist, weiß ich nicht.  
[Hier](https://gpailler.github.io/2019-10-13-pi4-part4/) gibt es einen Artikel zu Pi-Hole und IPv6.

Damit Pi-Hole genutzt wird, muss man dessen IP-Adresse als DNS-Server eintragen. Damit dies gleich für alle Geräte im eigenen WLAN funktioniert, trägt man diesen auf de Fritzbox ein.

Heimnetz / Netzwerk / Netzwerkeinstellungen  
IPv4-Adressen  
Lokaler DNS-Server: Hier die IP-Adresse des RPi eintragen.

### Local DNS Records
fritz.box: 192.168.178.1

### Blacklist
facebook.com - Add domain as wildcard

---

## ToDo
* Gruppen zeitlich steuern, um bestimmte Blacklist-Einträge zu aktivieren bzw. zu deaktivieren: 
https://discourse.pi-hole.net/t/activate-group-with-cron/32660/9

