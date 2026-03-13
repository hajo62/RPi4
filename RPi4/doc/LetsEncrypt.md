# Transport Layer Security (TLS)

Um mein Heimnetz gegen Angriffe und Manipulationsversuche zu schützen, sollen nur verschlüsselte Verbindungen zugelassen werden. Das dafür benötigte X.509-Zertifikate für die Transport Layer Security (TLS) kann man bei [Let’s Encrypt](https://letsencrypt.org/) **kostenlos** beziehen. Allerdings haben die Zertifikate _nur_ eine Gültigkeit von jeweils 90 Tagen und müssen daher regelmäßig (am besten automatisiert) erneuert werden. 

Zur Automatisierung der Zertifizierung nutzt Let’s Encrypt das Challenge-Response-Verfahren Automatic Certificate Management Environment (ACME). Dabei werden verschiedene Anfragen entweder an Unterseiten am Webserver (http-challenge) oder direkt DNS-Anfragen an die zu zertifizierende Domain gestellt. 

Als Domain nutze ich eine **kostenlose** Sub-Domain bei [DuckDNS](https://www.duckdns.org/), die (_angeblich_) als Challenge _nur_ die **http-challenge** ermöglicht. Leider muss hierfür während der Überprüfung der Port 80 auf der Fritzbox geöffnet werden und an den Web-Server weitergeleitet werden.

## Port 80 öffnen und Weiterleitung konfigurieren
Um den Port nur kurzzeitig automatisch öffnen und schließen zu können, habe ich in Anlehnung an ein [Skript von Nico Hartung](https://github.com/sky321/fritz_TR-064/blob/master/fritzbox-tr064.sh) mein eigenes kleines Shell-Skript erstellt.
```
#!/bin/bash
# Als Vorlage diente das Skript von Nico Hartung: https://github.com/sky321/fritz_TR-064/blob/master/fritzbox-tr064.sh

###
# Variablen
###
. ~/.myPrivacy/fritzbox.env
FRITZBOX_PW=`(echo $FRITZBOX_PW | base64 --decode)`
FRITZBOX_IP=`/sbin/ip route | awk '/^default/ { print $3 }'`
host_IP=`/usr/bin/hostname -I | /usr/bin/awk '{print $1}'`

###
# Konstanten
###
location="/upnp/control/wanpppconn1"
uri="urn:dslforum-org:service:WANPPPConnection:1"
action='AddPortMapping'

###
# Parameter
###
ENABLE="0"
if [ "$1" == "enable" ]
	then
		ENABLE="1"
elif [ "$1" == "disable" ]
	then
		ENABLE="0"
fi

###
# Skript
###
SoapParamString="<NewRemoteHost>0.0.0.0</NewRemoteHost>
<NewExternalPort>80</NewExternalPort>
<NewProtocol>TCP</NewProtocol>
<NewInternalPort>80</NewInternalPort>
<NewInternalClient>$host_IP</NewInternalClient>
<NewEnabled>$ENABLE</NewEnabled>
<NewPortMappingDescription>LetsEncrypt</NewPortMappingDescription>
<NewLeaseDuration>0</NewLeaseDuration>"

result=`curl -k -m 5 --anyauth -u "$FRITZBOX_USER:$FRITZBOX_PW" https://$FRITZBOX_IP:49443$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'>$SoapParamString</u:$action></s:Body></s:Envelope>" -s`
# Ab hier evtl. mal um Fehlerbehandlung kümmern
echo $result
```

## Erstellen & Erneuern von Let's Encrypt Zertifikaten
Nach langer Suche habe ich auf [github](https://github.com/acmesh-official/acme.sh) endlich das Shell-Script `acme.sh` gefunden, mit dem man _relativ_ einfach SSL-Zertifikate erstellen (und hoffentlich auch erneuern) kann. Dort findet sich auch eine Beschreibung, wie mann das Script zu benutzen hat:

### acme.sh
Man kann das Skript mit `curl https://get.acme.sh | sh` direkt auf dem (Web-)Server installieren oder über einen Docker-Container verwenden.

Bei der _direkten_ Installation wird das Verzeichnis `~/.achme.sh` angelegt und das Skript in dieses Verzeichnis kopiert. Weiterhin wird ein Alias angelegt und nachfolgender Crontab-Eintrag erstellt. 
```
21 0 * * * "/home/hajo/.acme.sh"/acme.sh --cron --home "/home/hajo/.acme.sh" > /dev/null
```

Ich habe mich aber entschlossen, mein _erstes_ Zertifkat mit dem [hier](https://github.com/acmesh-official/acme.sh/wiki/Run-acme.sh-in-docker) beschriebenen Docker-Container zu erstellen.

#### (Erstes) Zertifikat erstellen
Zuerst Port 80 auf der Fritzbox öffnen (s.o).
Anschließend den Container laden, um die Hilfe angezeigt zu bekommen, oder mit dem 2. Kommando gleich das Zertifikat erstellen:

```
# Image laden und Hilfe anzeigen
docker run --rm neilpang/acme.sh

# Zertifikat erstellen
docker run --rm  -it    -v "/home/hajo/LetsEncrypt/zert":/acme.sh    --net=host   neilpang/acme.sh  --issue -d hajo62.duckdns.org  -d ha.hajo62.duckdns.org -d nc.hajo62.duckdns.org -d pg.hajo62.duckdns.org --standalone
```
Die Zertifikate werden dann im Verzeichnis `/home/hajo/LetsEncrypt/certs` angelegt.
 
Die Zertificate müssen nun noch nach
kopiert werden (ca und fullchain wurden nicht automatisch mit kopiert):
```
cp /home/hajo/LetsEncrypt/certs/hajo62.duckdns.org/* /home/hajo/docker-volumes/LetsEncrypt/certs/hajo62.duckdns.org/
```

Evtl. muss auch noch nginx restarted werden.


# Zu klären...
Diffie-Hellman-Schlüsselaustausch  
sudo openssl dhparam -out ./certs/dhparam.pem 2048

