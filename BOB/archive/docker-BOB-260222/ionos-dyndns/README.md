# DynDNS-Updater (Nur bei IPv4 Änderung)

Dieses Script ruft die **öffentliche IPv4-Adresse** direkt von der **FRITZ!Box** (UPnP/SOAP) ab und ruft **nur bei einer Änderung** die **IONOS DynDNS-Update-URL** auf. Es vermeidet unnötige API-Calls und funktioniert ohne externe IP-Dienste.

## Inhalt

- `scripts/update_dyndns.sh`  
  *Minimaler DynDNS-Updater: IPv4 per FRITZ!Box, Update nur bei Änderung.*
- `.env`  
  Konfiguration (Update-URL, Intervall).
- Optional: `docker-compose.yml`  
  Startet das Script in einem schlanken Alpine-Container und persistiert den IP-Status.

---

## Voraussetzungen

1. **FRITZ!Box**  
   - UPnP/IGD muss aktiv sein:  
     *FRITZ!Box → Internet → Freigaben → „Änderungen der Sicherheitseinstellungen über UPnP gestatten“*  
   - Der SOAP-Endpunkt ist erreichbar unter:  
     `http://fritz.box:49000/igdupnp/control/WANIPConn1`

2. **IONOS DynDNS-Update-URL**  

   - Über die IONOS DNS API erzeugen (Developer Portal oder per `curl`) und als `UPDATE_URL` verwenden.  
   - Format: `https://ipv4.api.hosting.ionos.com/dns/v1/dyndns?q=<TOKEN>` (Beispiel; deinen echten Link einsetzen).


  ```bash
curl -X 'POST' 'https://api.hosting.ionos.com/dns/v1/dyndns' \
-H 'accept: application/json' \
-H 'X-API-Key: 09a11c904a274bb09b12f51d916ebe4b.RRH7CraVw1wJ02j3Oh5dBmY4YWKK5bBo18vhVGLizg1YWqHZSpLlSbQ9rk7nq0lGOcmYnZQ0EU59h5NipB2WoQ' \
-H 'Content-Type: application/json' \
-d '{
"domains": [
  "hajo63.de",
  "ha.hajo63.de",
  "nc.hajo63.de",
  "pg.hajo63.de",
  "www.hajo63.de"
  ],
  "description": "My DynamicDns"
}'
  ```


3. **Shell-Tools**  
   - `wget` und `grep` müssen vorhanden sein.  
   - Im Docker-Container installiert das Script `wget` bei Bedarf automatisch (Alpine).

---

## Konfiguration

### `.env`

```dotenv
# IONOS DynDNS Update-URL (aus der API-Antwort)
UPDATE_URL=https://ipv4.api.hosting.ionos.com/dns/v1/dyndns?q=DEIN_TOKEN

# Intervall in Sekunden (Standard: 600 = 10 Minuten)
INTERVAL_SECONDS=600
