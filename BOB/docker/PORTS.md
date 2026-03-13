# 🔌 Port-Übersicht Pi5 (192.168.178.55)

Alle belegten Ports auf dem Pi5. Der Pi5 löst den Pi4 schrittweise ab.

---

## 📋 Aktuelle Ports (Pi5)

| Port | Protokoll | Dienst | Container | Erreichbar von | Beschreibung |
|------|-----------|--------|-----------|----------------|--------------|
| **80** | TCP | Traefik HTTP | `traefik` | LAN (intern) | HTTP → HTTPS Redirect. **Nicht von außen freigegeben!** |
| **443** | TCP | Traefik HTTPS | `traefik` | Internet | Reverse Proxy für alle Services |
| **3000** | TCP | WUD Web UI | `wud` | LAN | What's Up Docker Dashboard |
| **8080** | TCP | CrowdSec LAPI | `crowdsec` | LAN / Docker intern | CrowdSec Local API (für Bouncer-Kommunikation) |
| **8090** | TCP | Signal CLI REST API | `signal-cli-rest-api` | LAN | Signal Messenger REST API |
| **8091** | TCP | WUD Webhook | `wud-webhook` | LAN / Docker intern | Webhook-Empfänger für WUD-Benachrichtigungen |
| **8092** | TCP | Traefik Dashboard | `traefik` | LAN | Traefik Admin Dashboard (nur LAN-IP gebunden) |
| **8095** | TCP | Attack Dashboard | `attack-dashboard` | LAN | Angriffs-Übersicht (Traefik + CrowdSec + SSH) |
| **8180** | TCP | This Week in Past | `this-week-in-past` | LAN | Foto-Diashow (öffentlich) |
| **8280** | TCP | This Week in Past (Privat) | `this-week-in-past-priv` | LAN | Foto-Diashow (privat) |

---

## 🌐 Von außen erreichbar (Internet)

| Port | Dienst | Beschreibung |
|------|--------|--------------|
| **443** | Traefik HTTPS | Alle öffentlichen Services via Reverse Proxy |

**Öffentliche Services (via Traefik):**
- `https://ha.hajo63.de` → Home Assistant (Pi4:8123, später Pi5)
- `https://nc.hajo63.de` → Nextcloud (Pi4:8088, später Pi5)
- `https://pg.hajo63.de` → Pigallery2 (Pi4:8001, später Pi5)

---

## 🏠 Nur im lokalen Netz (LAN: 192.168.178.x)

| Port | Dienst | URL | Beschreibung |
|------|--------|-----|--------------|
| **3000** | WUD Web UI | `http://192.168.178.55:3000` | Container-Update-Überwachung |
| **8080** | CrowdSec LAPI | `http://192.168.178.55:8080` | CrowdSec API (für Bouncer) |
| **8090** | Signal CLI | `http://192.168.178.55:8090` | Signal REST API |
| **8091** | WUD Webhook | `http://192.168.178.55:8091` | Webhook-Empfänger |
| **8092** | Traefik Dashboard | `http://192.168.178.55:8092` | Traefik Admin UI |
| **8095** | Attack Dashboard  | `http://192.168.178.55:8095` | Angriffs-Übersicht (Traefik + CrowdSec + SSH) |
| **8180** | This Week in Past | `http://192.168.178.55:8180` | Foto-Diashow |
| **8280** | This Week in Past (Privat) | `http://192.168.178.55:8280` | Foto-Diashow (privat) |
| **9200** | OwnCloud Infinite Scale | `http://192.168.178.55:9200` | oCIS Web-UI (intern) |

---

## 🗺️ Geplante neue Dienste – Port-Reservierungen

Folgende Ports sind für die Migration vom Pi4 bzw. neue Dienste vorgesehen:

| Port | Dienst | Protokoll | Hinweis |
|------|--------|-----------|---------|
| **1883** | Mosquitto MQTT | TCP | Standard-Port, nur LAN |
| **2342** | PhotoPrism | TCP | Standard-Port |
| **3307** | Nextcloud MariaDB | TCP | Datenbank (intern) |
| **8001** | Pigallery2 | TCP | Wie auf Pi4 beibehalten |
| **8082** | Zigbee2MQTT Web UI | TCP | Wie auf Pi4 beibehalten |
| **8086** | Frei | TCP | Ursprünglich für oCIS geplant, jetzt frei |
| **8087** | Piwigo | TCP | Frei |
| **8088** | Nextcloud | TCP | ✅ **Aktiv auf Pi5** |
| **8093** | Z-Wave JS UI | TCP | 8091 belegt (WUD Webhook) |
| **8094** | Z-Wave JS WebSocket | TCP | 3000 belegt (WUD) |
| **8123** | Home Assistant | TCP | Standard-Port |
| **9001** | Mosquitto WebSocket | TCP | Standard-Port, nur LAN |

> **Hinweis zu Mosquitto:** Port 1883 (MQTT) und 9001 (WebSocket) sind Standard-Ports.
> Unverschlüsselt – nur im LAN verwenden, durch Firewall von außen blockieren.
> Für externen Zugriff: MQTT über TLS (Port 8883) oder via Traefik-Tunnel.

> **Hinweis zu Z-Wave:** Der Standard-Port 3000 (WebSocket) ist durch WUD belegt.
> Daher: WebSocket auf 8094, Web UI auf 8093.

---

## 📦 Dienste ohne externe Ports

| Dienst | Container | Beschreibung |
|--------|-----------|--------------|
| ionos-dyndns | `ionos-dyndns` | DynDNS-Updater (kein Port) |
| nextcloud-redis | `nextcloud-redis` | Redis Cache für Nextcloud (nur intern) |

---

## 🔒 Sicherheitshinweise

### **Port 80 (HTTP)**
- Traefik hört auf Port 80, leitet aber **sofort** zu HTTPS (443) weiter
- **Nicht von außen freigegeben** (kein Port-Forwarding im Router)

### **Port 1883 / 9001 (Mosquitto)**
- Unverschlüsselt – nur im LAN!
- Durch nftables-Firewall von außen blockieren

### **Port 8080 (CrowdSec LAPI)**
- Gebunden auf `0.0.0.0:8080`
- Wird vom Host-Bouncer (`crowdsec-firewall-bouncer`) genutzt
- Durch nftables-Firewall von außen blockiert

### **Port 8092 (Traefik Dashboard)**
- Gebunden auf `192.168.178.55:8092` (nur LAN-IP)
- Kein Passwort (nur im LAN erreichbar)

### **Alle anderen LAN-Ports**
- Gebunden auf `0.0.0.0` (alle Interfaces)
- Durch nftables-Firewall von außen blockiert
- Kein Port-Forwarding im Router

---

## 🔧 Freie Ports (für weitere neue Dienste)

- **8003 – 8079** (komplett frei)
- **8083 – 8085** (frei)
- **8086** (frei - ursprünglich für oCIS geplant)
- **8089** (frei)
- **8096 – 8122** (frei)
- **8124 – 8179** (frei)
- **8181 – 8279** (frei)
- **8281+** (frei)

---

*Zuletzt aktualisiert: 2026-03-07*
*Made with Bob* 🤖