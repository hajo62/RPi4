# Traefik Quickstart Guide

Schnellanleitung für die Inbetriebnahme von Traefik auf Pi5.

## ⚡ Schnellstart (3 Minuten)

### 1. Ionos-Zertifikate kopieren

```bash
cd docker/traefik
mkdir -p certs/hajo63.de certs/hajo62.duckdns.org

# Zertifikate von Ionos in die Verzeichnisse kopieren:
# certs/hajo63.de/fullchain.pem
# certs/hajo63.de/privkey.pem
# certs/hajo62.duckdns.org/fullchain.pem
# certs/hajo62.duckdns.org/privkey.pem
```

**Wichtig:** Zertifikate müssen im PEM-Format vorliegen!

### 2. .env konfigurieren

```bash
cd docker/traefik
cp .env.example .env
nano .env
```

**Minimal-Konfiguration:**

```bash
# Domains (sollten bereits passen)
DOMAIN_MAIN=hajo63.de
DOMAIN_FALLBACK=hajo62.duckdns.org

# Pi4 IP (prüfen!)
PI4_IP=192.168.178.3
```

**Nicht benötigt:**
- ❌ LETSENCRYPT_EMAIL (Ionos-Zertifikate statt Let's Encrypt)
- ❌ CROWDSEC_TRAEFIK_BOUNCER_API_KEY (Firewall-Bouncer auf Host reicht)
- ❌ TRAEFIK_DASHBOARD_AUTH (Dashboard nur lokal auf localhost:8080)

### 3. Setup-Skript ausführen

```bash
./scripts/setup.sh
```

Das Skript:
- ✅ Erstellt Verzeichnisse
- ✅ Prüft Konfiguration
- ✅ Startet Traefik

### 4. Testen

```bash
# Logs prüfen
docker compose logs -f traefik

# Dashboard öffnen (im lokalen Netz)
# http://192.168.178.55:8092
# Direkt vom Mac im Browser erreichbar!

# Service testen
# https://ha.hajo63.de
# https://nc.hajo63.de
# https://pg.hajo63.de
```

## 🔧 Manuelle Installation

Falls das Setup-Skript nicht funktioniert:

### 1. Verzeichnisse erstellen

```bash
cd docker/traefik
mkdir -p certs/hajo63.de certs/hajo62.duckdns.org logs
```

### 2. .env konfigurieren

```bash
cp .env.example .env
nano .env
# Alle Werte anpassen (siehe oben)
```

### 3. Starten

```bash
docker compose up -d
```

### 4. Logs prüfen

```bash
docker compose logs -f traefik
```

## 🐛 Häufige Probleme

### Problem: "CrowdSec-Netzwerk nicht gefunden"

**Lösung:**
```bash
cd docker/crowdsec
docker compose up -d
cd ../traefik
```

### Problem: "Zertifikat nicht gefunden"

**Lösung:**
```bash
# Prüfen ob Zertifikate vorhanden sind
ls -la certs/hajo63.de/
# Sollte zeigen: fullchain.pem, privkey.pem

# Rechte prüfen
chmod 644 certs/hajo63.de/*.pem
chmod 644 certs/hajo62.duckdns.org/*.pem
```

### Problem: "Port 80 already in use"

**Lösung:**
```bash
# Prüfen welcher Prozess Port 80 nutzt
sudo lsof -i :80

# nginx auf Pi5 stoppen (falls vorhanden)
sudo systemctl stop nginx
```

### Problem: SSL-Fehler "certificate signed by unknown authority"

**Ursache:** Ionos-Zertifikate nicht korrekt oder abgelaufen

**Lösung:**
```bash
# Zertifikat-Gültigkeit prüfen
openssl x509 -in certs/hajo63.de/fullchain.pem -noout -dates

# Zertifikat-Details prüfen
openssl x509 -in certs/hajo63.de/fullchain.pem -noout -text

# Neue Zertifikate von Ionos herunterladen und ersetzen
```

## 📊 Status prüfen

### Container-Status

```bash
docker compose ps
```

Sollte zeigen:
```
NAME                    STATUS
traefik                 Up
homeassistant-proxy     Up
nextcloud-proxy         Up
pigallery2-proxy        Up
```

### Traefik-Dashboard

**Im lokalen Netz:** `http://192.168.178.55:8092`

Direkt vom Mac oder jedem anderen Gerät im Heimnetz erreichbar.

Zeigt:
- ✅ Routers (ha, nc, pg)
- ✅ Services (homeassistant, nextcloud, pigallery2)
- ✅ Middlewares (rate-limit-standard, geoblock-de, secure-headers, etc.)

**Sicherheit:** Port 8092 ist nur auf der LAN-IP des Pi5 gebunden (`192.168.178.55:8092`), nicht von außen erreichbar. Die nftables-Firewall blockiert Port 8092 für externe Zugriffe.

**Port-Übersicht Pi5:**
| Port | Dienst |
|------|--------|
| 8080 | CrowdSec LAPI |
| 8090 | signal-cli-rest-api |
| 8091 | wud-webhook |
| 8092 | **Traefik Dashboard** |

### CrowdSec-Status

```bash
cd docker/crowdsec
docker compose exec crowdsec cscli bouncers list
```

Sollte zeigen:
```
Name                    IP Address    Valid  Last API Pull
firewall-bouncer        127.0.0.1     ✓      2s ago
```

**Hinweis:** Traefik-Bouncer ist NICHT in der Liste (ist optional/deaktiviert)

### GeoIP-Test

```bash
# Von außerhalb Deutschlands testen (VPN)
curl -I https://ha.hajo63.de
# Sollte 403 Forbidden zurückgeben

# Von Deutschland testen
curl -I https://ha.hajo63.de
# Sollte 200 OK zurückgeben
```

## 🎯 Nächste Schritte

Nach erfolgreicher Installation:

1. **DNS-Einträge setzen**
   - `ha.hajo63.de` → Pi5-IP
   - `nc.hajo63.de` → Pi5-IP
   - `pg.hajo63.de` → Pi5-IP
   - **NICHT:** `traefik.hajo63.de` (Dashboard nur lokal!)

2. **Router-Portforwarding**
   - Port 80 → Pi5:80
   - Port 443 → Pi5:443

3. **Firewall-Regeln (Pi5)**
   ```bash
   # Nur Ports 80 und 443 von außen
   sudo nft list ruleset
   ```

4. **Services auf Pi4 anpassen**
   - Home Assistant: `trusted_proxies` setzen
   - Nextcloud: `trusted_domains` setzen

5. **Monitoring einrichten**
   - WUD: Update-Überwachung
   - CrowdSec: Geblockte IPs prüfen
   - Logs: Regelmäßig prüfen

## 📚 Weitere Dokumentation

- [README.md](README.md) - Vollständige Dokumentation
- [docker-compose.yml](docker-compose.yml) - Service-Konfiguration
- [config/traefik.yml](config/traefik.yml) - Traefik-Hauptkonfiguration
- [config/dynamic/middlewares.yml](config/dynamic/middlewares.yml) - Middlewares

## 🆘 Support

Bei Problemen:

1. **Logs prüfen**
   ```bash
   docker compose logs traefik
   ```

2. **README.md Troubleshooting-Sektion lesen**

3. **CrowdSec-Logs prüfen**
   ```bash
   cd docker/crowdsec
   docker compose logs crowdsec
   ```

4. **Traefik-Dashboard prüfen**
   - `https://traefik.hajo63.de`

---

**Made with Bob** 🤖