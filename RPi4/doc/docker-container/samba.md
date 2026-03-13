# Samba
Damit ich von meiner Panasonic-Kamera Bilder per WLAN auf meinem RPi / in mein Nextcloud übertragen kann, benötige ich einen Samba-Share. Wenn Bilder übertragen werden sollen, starte ich kurz den Container, übertrage die Bilder und stoppe den Container anschließend wieder. So muss ich mich nicht wikrlich um Security kümmern.


Info:  
* https://hub.docker.com/r/servercontainers/samba  
* https://blog.pistack.co.za/samba-server-on-raspberry-pi-with-docker/

`/home/hajo/docker-compose.yaml`:
```
  samba:
    image: dperson/samba
    container_name: samba
    environment:
      - TZ=Europe/Berlin
      - WORKGROUP=WORKGROUP
      - USERID=33
      - GROUPID=33
      - RECYCLE
    networks:
      - default
    ports:
      - "137:137/udp" # required only to advertise shares (NMBD)
      - "138:138/udp" # required only to advertise shares (NMBD)      
      - '139:139/tcp'
      - '445:445/tcp'
    read_only: false
    tmpfs:
      - /tmp
    restart: unless-stopped
    stdin_open: true
    tty: true
    volumes:
      - /home/hajo/docker-volumes/Nextcloud/data/hajo/files/Photos/Panasonic:/mnt/Panasonic
    command:
      -u "HAJO;HAJO"    
      -s "panasonic;/mnt/Panasonic;yes;no;no;all;'none';'none';'Panasonic'"
      -S 
      -p
```
* Damit die Panasonic sich verbinden kann, muss mit `-S` die Prüfung auf _mindestens SMB2_ deaktiviert werden.
* USERID & GROUPID 33, da dies die ID von `www-data` ist, der (warum auch immer) von Nextcloud genutzt wird.