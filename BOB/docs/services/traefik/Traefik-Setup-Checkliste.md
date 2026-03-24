# Traefik Reverse Proxy Setup - Informationscheckliste

## 1. Netzwerk & Infrastruktur

### Pi #4 (App-Server)
- [x] **IP-Adresse:** 192.168.178.3
- [x] **Hostname:** rpi4b
- [x] **Docker-Netzwerk Name:** homeassistant_network, nextcloud_network, proxy
- [ ] **Docker-Netzwerk Subnet:** _________________ (zu ermitteln)

### Pi #5 (Traefik-Server)
- [x] **IP-Adresse:** 192.168.178.55
- [x] **Hostname:** rpi5
- [x] **RaspberryOS Version:** Debian GNU/Linux 12 (bookworm)
- [x] **Docker Version:** 29.2.1

### Netzwerkverbindung
- [] **Können beide Pis sich gegenseitig erreichen?** (Ja/Nein): _________________
- [ ] **Firewall-Regeln zwischen den Pis:** _________________
- [ ] **Router/Gateway IP:** 192.168.178.1

---

## 2. Domain & DNS

- [x] **Hauptdomain:** hajo62.duckdns.org (aktuell in Verwendung)
- [x] **Subdomains:**
  - **Home Assistant:** ha.hajo63.de (geplant)
  - **Nextcloud:** nc.hajo62.duckdns.org (aktuell: nc.hajo63.de geplant)
  - **Pigallery2:** pg.hajo63.de (geplant)
  - **Traefik Dashboard:** traefik.hajo63.de (Vorschlag)
- [ ] **DNS-Provider:** DuckDNS (aktuell), _________________ (für hajo63.de)
- [ ] **Wildcard-Zertifikat gewünscht?** (Ja/Nein): _________________

---

## 3. SSL/TLS Zertifikate

- [ ] **Let's Encrypt Email:** _________________
- [ ] **Zertifikat-Resolver Name:** _________________ (z.B. "letsencrypt")
- [ ] **Challenge-Typ:** 
  - [ ] HTTP-01 Challenge
  - [ ] DNS-01 Challenge (Provider: _________________)
- [ ] **Staging-Modus für Tests?** (Ja/Nein): _________________

---

## 4. Home Assistant (Pi #4)

- [x] **Container Name:** homeassistant
- [x] **Interner Port:** 8123
- [x] **Docker-Netzwerk:** host (network_mode: host)
- [x] **Aktuelles Zugriffs-URL:** http://192.168.178.3:8123
- [x] **Besondere Konfiguration in configuration.yaml nötig?** Ja - für Reverse Proxy (trusted_proxies, use_x_forwarded_for)
- [x] **Zusätzliche Infos:**
  - Verwendet MariaDB (homeassistant-db, Port 3306)
  - Privileged Mode aktiv
  - Memory Limit: 2048M
  - Volumes: /home/hajo/docker-volumes/homeassistant
  - LetsEncrypt Zertifikate: /home/hajo/docker-volumes/LetsEncrypt/certs/hajo62.duckdns.org/

---

## 5. Nextcloud (Pi #4)

- [x] **Container Name:** nextcloud
- [x] **Interner Port:** 8088 (Container Port 80, Host Port 8088)
- [x] **Docker-Netzwerk:** nextcloud_network
- [x] **Aktuelles Zugriffs-URL:** http://192.168.178.3:8088
- [x] **Hostname:** nc.hajo62.duckdns.org
- [x] **Datenbank-Container Name:** nextcloud-db (MariaDB, Port 3307)
- [x] **Redis-Container:** nextcloud-redis (vorhanden)
- [x] **Zusätzliche Infos:**
  - Image: nextcloud:stable
  - Memory Limit: 4G, CPU Limit: 2.0
  - Volumes: /home/hajo/docker-volumes/nextcloud
  - DNS: 127.0.0.1, 1.1.1.1
  - Datenbank: MariaDB mit READ-COMMITTED isolation

---

## 6. Pigallery2 (Pi #4)

- [x] **Container Name:** pigallery2
- [x] **Interner Port:** 8001 (Container Port 80, Host Port 8001)
- [x] **Docker-Netzwerk:** default (kein spezifisches Netzwerk definiert)
- [x] **Aktuelles Zugriffs-URL:** http://192.168.178.3:8001
- [x] **Zusätzliche Infos:**
  - Image: bpatrik/pigallery2:v2.0.3
  - Datenbank: pigallery2-db (MariaDB, Port 3310)
  - Memory Limit: 768M
  - Volumes: /home/hajo/docker-volumes/pigallery2
  - Foto-Verzeichnisse: /home/hajo/Photos (verschiedene Jahrgänge, read-only)
  - Authentifizierung: Enforced User "myadmin" konfiguriert

---

## 7. GeoIP Konfiguration

- [ ] **MaxMind Account erstellt?** (Ja/Nein): _________________
- [ ] **MaxMind License Key:** _________________
- [ ] **GeoLite2 Database gewünscht:** 
  - [ ] GeoLite2-Country
  - [ ] GeoLite2-City
- [ ] **Erlaubte Länder:** DE (weitere: _________________)
- [ ] **Aktion bei Blockierung:**
  - [ ] 403 Forbidden
  - [ ] 404 Not Found
  - [ ] Custom Error Page

---

## 8. CrowdSec Konfiguration

- [ ] **CrowdSec API Key (falls Cloud-Sync):** _________________
- [ ] **Gewünschte Collections:**
  - [ ] crowdsecurity/traefik
  - [ ] crowdsecurity/http-cve
  - [ ] crowdsecurity/whitelist-good-actors
  - [ ] Weitere: _________________
- [ ] **Bouncer API Key generieren:** (wird automatisch erstellt)
- [ ] **Log-Level:** _________________ (info/debug/warning)
- [ ] **Whitelist IPs (z.B. lokales Netzwerk):** _________________

---

## 9. Traefik Konfiguration

### Basis-Einstellungen
- [ ] **Traefik Version:** v3.6 (empfohlen: v3.x)
- [ ] **Dashboard aktivieren?** (Ja/Nein): Ja
- [ ] **Dashboard Authentifizierung:**
  - **Username:** _________________
  - **Password (htpasswd):** _________________
- [ ] **Log-Level:** INFO (DEBUG/INFO/WARN/ERROR)
- [ ] **Access Logs aktivieren?** (Ja/Nein): _________________

### Entrypoints
- [ ] **HTTP Port:** _________________ (Standard: 80)
- [ ] **HTTPS Port:** _________________ (Standard: 443)
- [ ] **HTTP zu HTTPS Redirect?** (Ja/Nein): _________________

### Middleware
- [ ] **Rate Limiting gewünscht?** (Ja/Nein): _________________
  - **Requests pro Sekunde:** _________________
- [ ] **Security Headers aktivieren?** (Ja/Nein): _________________
- [ ] **IP Whitelist für Admin-Bereiche:** _________________

---

## 10. Docker Compose Struktur

- [ ] **Bevorzugte Verzeichnisstruktur auf Pi #5:**
  - **Traefik Config:** _________________ (z.B. /opt/traefik)
  - **Zertifikate:** _________________ (z.B. /opt/traefik/letsencrypt)
  - **CrowdSec Config:** _________________ (z.B. /opt/crowdsec)
  - **GeoIP Datenbank:** _________________ (z.B. /opt/traefik/geoip)

---

## 11. Monitoring & Logging

- [ ] **Prometheus Metriken aktivieren?** (Ja/Nein): _________________
- [ ] **Log-Rotation konfigurieren?** (Ja/Nein): _________________
- [ ] **Externe Monitoring-Lösung:** _________________ (z.B. Grafana)

---

## 12. Backup & Recovery

- [ ] **Backup-Strategie für Traefik-Config:** _________________
- [ ] **Backup-Strategie für Zertifikate:** _________________
- [ ] **Backup-Strategie für CrowdSec-Daten:** _________________

---

## 13. Sicherheit

- [ ] **Fail2Ban zusätzlich gewünscht?** (Ja/Nein): _________________
- [ ] **2FA für kritische Services?** (Ja/Nein): _________________
- [ ] **VPN-Zugang als Alternative?** (Ja/Nein): _________________
- [ ] **Lokales Netzwerk-Zugriff ohne Einschränkungen?** (Ja/Nein): _________________

---

## 14. Zusätzliche Anforderungen

- [ ] **Automatische Updates für Container?** (Ja/Nein): _________________
- [ ] **Health Checks konfigurieren?** (Ja/Nein): _________________
- [ ] **Custom Error Pages:** _________________
- [ ] **Weitere Middleware-Anforderungen:** _________________

---

## Wichtige Hinweise

1. **Docker-Netzwerk:** Alle Container auf Pi #4 müssen Labels für Traefik erhalten
2. **Netzwerk-Erreichbarkeit:** Docker-Netzwerk muss zwischen Pi #4 und Pi #5 erreichbar sein (ggf. Overlay-Netzwerk oder Docker Swarm)
3. **GeoIP-Updates:** GeoIP-Datenbank muss regelmäßig aktualisiert werden (Cronjob einrichten)
4. **CrowdSec-Integration:** CrowdSec benötigt Zugriff auf Traefik-Logs
5. **Port-Forwarding:** Router muss Ports 80 und 443 auf Pi #5 weiterleiten

---

## 15. Analyse & Empfehlungen: Docker-Netzwerke

### Aktuelle Situation (Pi #4)
```
networks:
  homeassistant_network:     # Nur für Signal-CLI verwendet
  nextcloud_network:         # Für Nextcloud + nextcloud-db
  proxy:                     # Definiert aber nicht verwendet
    name: proxy
```

**Probleme der aktuellen Konfiguration:**

1. **Home Assistant im Host-Modus:**
   - ❌ Keine Netzwerk-Isolation
   - ❌ Direkter Zugriff auf alle Host-Ports
   - ❌ Schwierig für Traefik zu erreichen (Pi #5 → Pi #4)
   - ⚠️ Sicherheitsrisiko bei Kompromittierung

2. **Pigallery2 im Default-Netzwerk:**
   - ❌ Keine explizite Netzwerk-Zuordnung
   - ❌ Nicht im "proxy" Netzwerk

3. **Nextcloud isoliert:**
   - ✅ Eigenes Netzwerk (gut für DB-Isolation)
   - ❌ Nicht im "proxy" Netzwerk

4. **"proxy" Netzwerk ungenutzt:**
   - ❌ Definiert aber von keinem Container verwendet

### Empfohlene Netzwerk-Architektur

#### Option A: Traefik auf Pi #5 (Empfohlen für Sicherheit)

**Vorteile:**
- ✅ Zentrale SSL-Terminierung
- ✅ Bessere Sicherheit (Traefik exponiert, Apps geschützt)
- ✅ Einfachere Zertifikatsverwaltung
- ✅ GeoIP & CrowdSec zentral

**Netzwerk-Setup:**
```yaml
# Pi #4: docker-compose-Pi4.yaml
networks:
  proxy:
    name: proxy
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
  
  nextcloud_internal:
    name: nextcloud_internal
    driver: bridge
    internal: true  # Kein Internet-Zugriff
  
  homeassistant_internal:
    name: homeassistant_internal
    driver: bridge

services:
  homeassistant:
    networks:
      - proxy
      - homeassistant_internal
    # WICHTIG: network_mode: host ENTFERNEN!
    ports:
      - "8123:8123"  # Nur für lokalen Zugriff
  
  nextcloud:
    networks:
      - proxy
      - nextcloud_internal
  
  nextcloud-db:
    networks:
      - nextcloud_internal  # Nur intern, kein Proxy-Zugriff
  
  pigallery2:
    networks:
      - proxy
```

**Traefik-Zugriff von Pi #5:**
- Traefik auf Pi #5 greift über HTTP auf Pi #4 zu
- URLs: http://192.168.178.3:8123, http://192.168.178.3:8088, http://192.168.178.3:8001
- SSL-Terminierung erfolgt auf Pi #5

#### Option B: Traefik auf Pi #4 (Einfacher, weniger sicher)

**Vorteile:**
- ✅ Einfachere Konfiguration
- ✅ Keine Netzwerk-Kommunikation zwischen Pis nötig

**Nachteile:**
- ❌ Alle Services auf einem Pi
- ❌ Single Point of Failure
- ❌ Weniger Sicherheit

### Sicherheitsempfehlungen

1. **Home Assistant aus Host-Mode nehmen:**
   ```yaml
   homeassistant:
     # network_mode: host  # ENTFERNEN!
     networks:
       - proxy
     ports:
       - "8123:8123"
   ```

2. **Datenbanken isolieren:**
   - Datenbanken sollten NICHT im proxy-Netzwerk sein
   - Nur über interne Netzwerke erreichbar

3. **Explizite Subnetze definieren:**
   ```yaml
   networks:
     proxy:
       driver: bridge
       ipam:
         config:
           - subnet: 172.20.0.0/16
             gateway: 172.20.0.1
   ```

4. **Firewall-Regeln:**
   - Pi #4: Nur Ports 8123, 8088, 8001 von Pi #5 erreichbar
   - Pi #5: Ports 80, 443 von außen erreichbar

### Empfohlene Änderungen für Traefik-Setup

**Priorität 1 (Kritisch):**
- [ ] Home Assistant: `network_mode: host` entfernen
- [ ] Alle Services ins `proxy` Netzwerk aufnehmen
- [ ] Datenbanken in separate interne Netzwerke

**Priorität 2 (Wichtig):**
- [ ] Explizite Subnetze definieren
- [ ] Firewall-Regeln zwischen Pi #4 und Pi #5

**Priorität 3 (Optional):**
- [ ] Docker Swarm für echtes Overlay-Netzwerk
- [ ] Separate VLANs für Management/Services

### Nächste Schritte

1. Entscheiden: Traefik auf Pi #4 oder Pi #5?
2. Netzwerk-Architektur anpassen
3. Home Assistant Konfiguration für Reverse Proxy vorbereiten
4. Firewall-Regeln definieren

---

## Nächste Schritte nach dem Ausfüllen

1. Docker-Netzwerk zwischen beiden Pis einrichten
2. Traefik auf Pi #5 installieren und konfigurieren
3. CrowdSec auf Pi #5 installieren und mit Traefik verbinden
4. GeoIP-Plugin konfigurieren
5. Container auf Pi #4 mit Traefik-Labels versehen
6. DNS-Einträge erstellen
7. SSL-Zertifikate generieren lassen
8. Testen und Monitoring einrichten

---

**Erstellt am:** 2026-02-09  
**Für:** Traefik Reverse Proxy Setup mit Home Assistant, Nextcloud & Pigallery2