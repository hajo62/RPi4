# nginx
## nginx Version anzeigen
```
docker exec -it nginx nginx -v
```

##
Nachfolgende `docker-compose.yaml`-Datei configuriert und startet den Container:  
```
version: '3.9'
services:
  nginx: 
    image: nginx:latest
    # image: mynginx:latest
    # image: jidckii/nginx-geoip2               # Geht nicht
    # image: ghcr.io/macbre/nginx-http3:latest  # Geht nicht
    container_name: nginx
    volumes:
      - ./docker-volumes/nginx/log:/var/log/nginx
      - ./docker-volumes/nginx/etc/nginx.conf:/etc/nginx/nginx.conf
      - ./docker-volumes/nginx/etc/nginx/cache:/etc/nginx/cache
      # Für Passwortchutz im Web-Prox für DigiKam
      - ./docker-volumes/nginx/etc/passwords:/etc/nginx/passwords
      # LetsEncrypt-Zertifikate
      - /home/hajo/docker-volumes/LetsEncrypt/certs/:/etc/letsencrypt/
      - /home/hajo/docker-volumes/LetsEncrypt/certs/dhparam.pem:/etc/nginx/dhparam.pem
      # GeoIP: Modul und Datenbank
      # - /home/hajo/docker-volumes/nginx/modules/ngx_http_geoip2_module/ngx_http_geoip2_module.so:/etc/nginx/modules/ngx_http_geoip2_module.so
      - /home/hajo/docker-volumes/geoip-upd/geoip2:/usr/share/Geoip:ro
    ports:
      # - 80:80
      - 443:443
    restart: unless-stopped
```

## nginx absichern:
https://www.sherbers.de/sichere-tls-konfiguration-mit-nginx/

Um zu überprüfen, ob auch alles funktioniert, empfiehlt sich der [SSL Server Test](https://www.ssllabs.com/ssltest/index.html) von [SSL Labs](https://www.ssllabs.com/).

https://geekflare.com/nginx-webserver-security-hardening-guide/