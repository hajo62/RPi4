# Let's Encrypt
[Hier](https://www.humankode.com/ssl/how-to-set-up-free-ssl-certificates-from-lets-encrypt-using-docker-and-nginx) gibt es eine Anleitung, nach der ich meine Zertifikate erstelle.

Statt der angegebenen Pfade habe ich ... verwendet:  
/docker-volumes -> /home/hajo/docker-volumes
/docker -> /home/hajo/docker

Erstellen der Verzeichniss-Struktur:
```
mkdir -p /home/hajo/docker/letsencrypt-docker-nginx/src/letsencrypt/letsencrypt-site
```

Erstellen der docker-compose.yml-Datei:
```
nano /home/hajo/docker/letsencrypt-docker-nginx/src/letsencrypt/docker-compose.yml
```
docker-compose.yml:
```
version: '3.1'

services:

  letsencrypt-nginx-container:
    container_name: 'letsencrypt-nginx-container'
    image: nginx:latest
    ports:
      - "9080:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./letsencrypt-site:/usr/share/nginx/html
    networks:
      - docker-network

networks:
  docker-network:
    driver: bridge
```

Erstellen der Konfigurationsdatei für nginx:
```
nano /home/hajo/docker/letsencrypt-docker-nginx/src/letsencrypt/nginx.conf
```

nginx.conf:
```
server {
    listen 80;
    listen [::]:80;
    server_name hajo62.duckdns.org;

    location ~ /.well-known/acme-challenge {
        allow all;
        root /usr/share/nginx/html;
    }

    root /usr/share/nginx/html;
    index index.html;
}
```

Erstellen einer index.html-Datei:
```
sudo nano /home/hajo/docker/letsencrypt-docker-nginx/src/letsencrypt/letsencrypt-site/index.html
```
index.html:
```
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>Let's Encrypt First Time Cert Issue Site</title>
</head>
<body>
    <h1>Hallo!</h1>
    <p>
        This is the temporary site that will only be used for the very first time SSL certificates are issued by Let's Encrypt's
        certbot.
    </p>
</body>
</html>
```

## Staging zum Test der Syntax
> Der nachfolgende Befehl muss um den Parameter `--dns=192.168.178.1` ergänzt werden, da bedingt durch Pi-Hole sonst keine Namensauflösung im Certbox-Container funktioniert.  
Das ist keine Lösung, des Problems sondern nur ein Work Around!

```
docker run -it --rm --dns=192.168.178.1 \
-v /home/hajo/docker-volumes/etc/letsencrypt:/etc/letsencrypt \
-v /home/hajo/docker-volumes/var/lib/letsencrypt:/var/lib/letsencrypt \
-v /home/hajo/docker/letsencrypt-docker-nginx/src/letsencrypt/letsencrypt-site:/data/letsencrypt \
-v /home/hajo/docker-volumes/var/log/letsencrypt:/var/log/letsencrypt \
certbot/certbot:arm64v8-latest \
certonly --webroot \
--register-unsafely-without-email --agree-tos \
--webroot-path=/data/letsencrypt \
--staging \
-d hajo62.duckdns.org 
```

Zusätzliche Informationen über die Zertifikate meiner Domain anzeigen:
```
sudo docker run --rm -it --dns=192.168.178.1 --name certbot \
-v /home/hajo/docker-volumes/etc/letsencrypt:/etc/letsencrypt \
-v /home/hajo/docker-volumes/var/lib/letsencrypt:/var/lib/letsencrypt  \
-v /home/hajo/docker/letsencrypt-docker-nginx/src/letsencrypt/letsencrypt-site:/data/letsencrypt \
certbot/certbot:arm64v8-latest \
--staging \
certificates
```

Nachdem das _Staging_ funktioniert hat, wird aufgeräumt und anschließend das gültige Zertifikat erstellt.

sudo rm -rf /home/hajo/docker-volumes/

## Erstellen des Zertifikates
```
docker run -it --rm --dns=192.168.178.1 \
-v /home/hajo/docker-volumes/etc/letsencrypt:/etc/letsencrypt \
-v /home/hajo/docker-volumes/var/lib/letsencrypt:/var/lib/letsencrypt \
-v /home/hajo/docker/letsencrypt-docker-nginx/src/letsencrypt/letsencrypt-site:/data/letsencrypt \
-v /home/hajo/docker-volumes/var/log/letsencrypt:/var/log/letsencrypt \
certbot/certbot:arm64v8-latest \
certonly --webroot \
--email hajo62@gmail.com --agree-tos --no-eff-email \
--webroot-path=/data/letsencrypt \
-d hajo62.duckdns.org 
```

Stoppen des temporären nginx-Containers:
```
cd /home/hajo/docker/letsencrypt-docker-nginx/src/letsencrypt
sudo docker-compose down
```
Evtl. noch das nginx-Images entfernen:
```
docker images
docker rmi <IMAGE ID>
```

---

## nginx-Production

sudo mkdir -p /home/hajo/docker/letsencrypt-docker-nginx/src/production/production-site
sudo mkdir -p /home/hajo/docker/letsencrypt-docker-nginx/src/production/dh-param

sudo nano /home/hajo/docker/letsencrypt-docker-nginx/src/production/docker-compose.yml

```
version: '3.1'

services:

  production-nginx-container:
    container_name: 'production-nginx-container'
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./production.conf:/etc/nginx/conf.d/default.conf
      - ./production-site:/usr/share/nginx/html
      - ./dh-param/dhparam-2048.pem:/etc/ssl/certs/dhparam-2048.pem
      - /home/hajo/docker-volumes/etc/letsencrypt/live/hajo62.duckdns.org/fullchain.pem:/etc/letsencrypt/live/hajo62.duckdns.org/fullchain.pem
      - /home/hajo/docker-volumes/etc/letsencrypt/live/hajo62.duckdns.org/privkey.pem:/etc/letsencrypt/live/hajo62.duckdns.org/privkey.pem
    networks:
      - docker-network

networks:
  docker-network:
    driver: bridge
```










```
server {
    listen      80;
    listen [::]:80;
    server_name hajo62.duckdns.org;

    location / {
        rewrite ^ https://$host$request_uri? permanent;
    }

    #for certbot challenges (renewal process)
    location ~ /.well-known/acme-challenge {
        allow all;
        root /data/letsencrypt;
    }
}

#https://hajo62.duckdns.org
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name hajo62.duckdns.org;

    server_tokens off;

    ssl_certificate /etc/letsencrypt/live/hajo62.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/hajo62.duckdns.org/privkey.pem;

    ssl_buffer_size 8k;

    ssl_dhparam /etc/ssl/certs/dhparam-2048.pem;

    ssl_protocols TLSv1.2 TLSv1.1 TLSv1;
    ssl_prefer_server_ciphers on;

    ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;

    ssl_ecdh_curve secp384r1;
    ssl_session_tickets off;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8;

    return 301 https://$request_uri;
}

#https://
server {
    server_name ;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_tokens off;

    ssl on;

    ssl_buffer_size 8k;
    ssl_dhparam /etc/ssl/certs/dhparam-2048.pem;

    ssl_protocols TLSv1.2 TLSv1.1 TLSv1;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;

    ssl_ecdh_curve secp384r1;
    ssl_session_tickets off;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4;

    ssl_certificate /etc/letsencrypt/live/hajo62.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/hajo62.duckdns.org/privkey.pem;

    root /usr/share/nginx/html;
    index index.html;
}
```


sudo openssl dhparam -out /home/hajo/docker/letsencrypt-docker-nginx/src/production/dh-param/dhparam-2048.pem 2048

nginx-Web-Site: Dateien hierher kopieren 
/docker/letsencrypt-docker-nginx/src/production/production-site/

cd /home/hajo/docker/letsencrypt-docker-nginx/src/production
sudo docker-compose up -d









https://decatec.de/linux/lets-encrypt-zertifikate-mit-acme-sh-und-nginx/


sudo adduser letsencrypt 
sudo usermod -a -G www-data letsencrypt

sudo visudo
letsencrypt ALL=NOPASSWD: /bin/systemctl reload nginx.service
su - letsencrypt

curl https://get.acme.sh | sh

exit


sudo mkdir -p /var/www/letsencrypt/.well-known/acme-challenge
sudo chown -R www-data:www-data /var/www/letsencrypt
sudo chmod -R 775 /var/www/letsencrypt
sudo mkdir -p /etc/letsencrypt/hajo62.duckdns.org
sudo chown -R www-data:www-data /etc/letsencrypt
sudo chmod -R 775 /etc/letsencrypt



server {
	listen 80 default_server;
    listen [::]:80 default_server;
	server_name hajo62.duckdns.org 192.168.178.3;
 
	root /var/www;
	
	location ^~ /.well-known/acme-challenge {
		default_type text/plain;
		root /var/www/letsencrypt;
	}		
}



acme.sh --issue -d hajo62.duckdns.org --keylength 4096 -w /var/www/letsencrypt --key-file /etc/letsencrypt/hajo62.duckdns.org/key.pem --ca-file /etc/letsencrypt/hajo62.duckdns.org/ca.pem --cert-file /etc/letsencrypt/hajo62.duckdns.org/cert.pem --fullchain-file /etc/letsencrypt/hajo62.duckdns.org/fullchain.pem --reloadcmd "sudo /bin/systemctl reload nginx.service"



---












# Reverse Proxy
Ein **Reverse-Proxy** dient teilweise _Empfangschef_ im eigenen Netz, der eingehende Anfragen an die richtige _Abteilung_ weiterleitet, und teils Türsteher, der die interne Infrastruktur vor neugierigen Blicken schützt. Dazu fängt er alle Anfragen von den Clients an die Server - z.B. den Raspberry Pi - ab und liefert auch alle Antworten und Dienste von den Servern wieder an die Clients zurück. Aus Sicht des _Kunden_ sieht es so aus, als würde alles von einer einzigen Stelle ausgehen.

[nginx](https://www.nginx.com/) ist eine Open-Source-Webserver, der u.a. als Reverse Proxy genutzt werden kann.

Eine Beschreibung zur Installation eines nginx-Docker-Container findet sich z.B. [hier](https://blog.docker.com/2015/04/tips-for-deploying-nginx-official-image-with-docker); ich hatte aber Probleme mit der Konfiguration und mit LetsEncrypt.  
Eine deutlich einfachere Lösung ist die Nutzung eines Containers, der bereits **nginx** und **LetsEncrypt** enthält.  

## Installation des docker-containers mit nginx und letsencrypt
 
 
Ich habe [diesen](https://github.com/linuxserver/docker-letsencrypt) Container verwendet und nach [dieser](https://community.home-assistant.io/t/nginx-reverse-proxy-set-up-guide-docker) Beschreibung vorgegangen.

WICHTIG: homeassistant darf nicht `network_mode: host` in `docker-compose.yaml`-Datei haben; dann scheint der letsencrypt-Container nicht an den HA-Container ran zu kommen...

Nachfolgende `docker-compose.yaml`-Datei configuriert und startet den Container.  

```
  version: '3'
  services:

    letsencrypt:
      image: linuxserver/letsencrypt
      container_name: letsencrypt
      restart: unless-stopped
      cap_add:
      - NET_ADMIN
      volumes:
      - /etc/localtime:/etc/localtime:ro
      - /home/pi/docker/letsencrypt/config:/config
      environment:
      - PGID=1000
      - PUID=1000
      - EMAIL=<my eMail>
      - URL=<myDNS>.duckdns.org
      - SUBDOMAINS=wildcard
      - VALIDATION=duckdns
      - DUCKDNSTOKEN=<my DUCKDNS TOKEN>
      - TZ=Europe/Berlin
      ports:
      - "80:80"
      - "443:443"
```

Der erste Start dauert eine ganze Weile, da das Zertifkat erstellt und heruntergeladen wird. Hier die Ausgabe beim ersten Start:  

```
letsencrypt    | 2048 bit DH parameters present
letsencrypt    | E-mail address entered: <my eMail>
letsencrypt    | duckdns validation is selected
letsencrypt    | Generating new certificate
letsencrypt    | Saving debug log to /var/log/letsencrypt/letsencrypt.log
letsencrypt    | Plugins selected: Authenticator standalone, Installer None
letsencrypt    | Obtaining a new certificate
letsencrypt    | Performing the following challenges:
letsencrypt    | http-01 challenge for <myDNS>.duckdns.org
letsencrypt    | Waiting for verification...
letsencrypt    | Cleaning up challenges
letsencrypt    | IMPORTANT NOTES:
letsencrypt    |  - Congratulations! Your certificate and chain have been saved at:
letsencrypt    |    /etc/letsencrypt/live/<myDNS>.duckdns.org/fullchain.pem
letsencrypt    |    Your key file has been saved at:
letsencrypt    |    /etc/letsencrypt/live/<myDNS>.duckdns.org/privkey.pem
letsencrypt    |    Your cert will expire on 2019-12-23. To obtain a new or tweaked
letsencrypt    |    version of this certificate in the future, simply run certbot
letsencrypt    |    again. To non-interactively renew *all* of your certificates, run
letsencrypt    |    "certbot renew"
letsencrypt    |  - If you like Certbot, please consider supporting our work by:
letsencrypt    |
letsencrypt    |    Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
letsencrypt    |    Donating to EFF:                    https://eff.org/donate-le
```







## ?????
Warum habe ich das notiert?!  

https://medium.com/@pentacent/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71  
https://github.com/Tob1asDocker/rpi-certbot  

```
docker pull tobi312/rpi-certbot
docker run --name mynginx -P -d nginx
```
 https://letsencrypt.org/de/
