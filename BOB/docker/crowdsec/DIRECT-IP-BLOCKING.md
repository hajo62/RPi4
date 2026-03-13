# 🚫 Direct-IP Blocking

## Übersicht

Direct-IP Hits sind Requests an den Server über die IP-Adresse statt über den Hostnamen:

```
Normal:    https://ha.hajo63.de/     ← Legitimer Zugriff
Direct-IP: https://93.184.216.34/   ← Scanner/Angreifer
```

Scanner und Angreifer nutzen Direct-IP Hits um:
- Offene Ports zu finden
- Dienste zu identifizieren
- SSL-Zertifikate auszulesen
- Schwachstellen zu suchen

## 🏗️ Implementierung (Zwei-Stufen-Ansatz)

### Stufe 1: Traefik Catch-All Router

**Datei**: `docker/traefik/config/dynamic/routes.yml`

```yaml
https-catchall:
  rule: "HostRegexp(`{host:.+}`) && PathPrefix(`/`)"
  entryPoints:
    - websecure
  priority: 1          # Niedrigste Priorität
  service: noop@internal
  tls: {}
```

**Wie es funktioniert:**
- Alle bekannten Hosts (ha, nc, pg) haben höhere Priorität → normaler Ablauf
- Alle anderen Requests (Direct-IP, unbekannte Domains) → `noop@internal` → **404**
- 404 wird im Access-Log geloggt → CrowdSec kann reagieren

### Stufe 2: CrowdSec Custom Scenario

**Datei**: `docker/crowdsec/config/scenarios/direct-ip-hit.yaml`

```yaml
type: trigger
name: custom/direct-ip-hit
filter: "evt.Meta.log_type == 'http_access-log'
      && evt.Meta.http_status == '404'
      && (evt.Parsed.traefik_router_name_root == ''
       || evt.Parsed.traefik_router_name_root == 'null')"
groupby: evt.Meta.source_ip
blackhole: 5m
labels:
  service: http
  type: scan
  remediation: true
```

**Wie es funktioniert:**
- Filter erkennt: HTTP 404 + kein Router-Name = Direct-IP Hit
- `type: trigger` → Beim **ersten** Treffer sofortiger Ban (kein Eimer-Modell!)
- Ban-Dauer: 24 Stunden (Standard)
- `blackhole: 5m` → Verhindert doppelte Bans für gleiche IP innerhalb 5 Minuten
- Firewall-Bouncer setzt nftables-Regel → Pakete werden verworfen

## 📊 Ablauf eines Direct-IP Hits

```
1. Scanner (1.2.3.4) → https://93.184.216.34/
   │
   ▼
2. Traefik: https-catchall greift (priority: 1)
   → noop@internal → 404
   → Access-Log: {ip: "1.2.3.4", status: 404, router: ""}
   │
   ▼
3. CrowdSec liest Log (alle ~10s)
   → custom/direct-ip-hit Scenario greift
   → Decision: ban 1.2.3.4 für 24h
   │
   ▼
4. Firewall-Bouncer (alle 10s)
   → nftables: DROP alle Pakete von 1.2.3.4
   │
   ▼
5. Nächster Versuch von 1.2.3.4
   → Pakete werden auf Kernel-Ebene verworfen
   → Kein Traefik-Log mehr
   → Kein weiterer Eintrag im Dashboard
```

## 🔍 Feldnamen im CrowdSec Traefik-Parser

Ermittelt mit `cscli explain`:

| Feld | Wert | Bedeutung |
|------|------|-----------|
| `evt.Meta.log_type` | `http_access-log` | Traefik Access-Log |
| `evt.Meta.http_status` | `"404"` | HTTP Status-Code (String!) |
| `evt.Meta.source_ip` | `1.2.3.4` | Client-IP |
| `evt.Parsed.traefik_router_name_root` | `""` | Leer = kein Router = Direct-IP Hit |
| `evt.Parsed.traefik_router_name_root` | `"ha"` | Router-Name bei bekanntem Host |

## 📈 Erwartetes Verhalten im Attack Dashboard

| Situation | Dashboard-Einträge |
|-----------|-------------------|
| Erster Direct-IP Hit | 1 Eintrag (404) |
| Weitere Versuche nach Ban | 0 (nftables DROP) |
| Nach 24h (Ban abgelaufen) | 1 neuer Eintrag |

## 🧪 Testen

```bash
# Direct-IP Hit auslösen (vom LAN):
curl -k -o /dev/null -w "%{http_code}\n" https://192.168.178.55/
# → 404

# Im Access-Log prüfen:
grep '"DownstreamStatus":404' /home/hajo/docker/traefik/logs/access.json | \
  tail -3 | jq '{ip: .ClientHost, status: .DownstreamStatus, router: .RouterName}'

# CrowdSec Scenario verifizieren:
docker compose exec crowdsec cscli explain \
  --log '{"ClientHost":"1.2.3.4","DownstreamStatus":404,"RouterName":"","RequestPath":"/","time":"2026-02-28T16:00:00Z"}' \
  --type traefik 2>&1 | grep -E "direct-ip|Scenarios"

# Alerts prüfen:
docker compose exec crowdsec cscli alerts list
```

## ⚠️ Wichtig: Whitelist

Lokale IPs werden **nicht** gebannt (Whitelist in `config/parsers/s02-enrich/mywhitelists.yaml`):
- `192.168.178.0/24` (LAN)
- `172.16.0.0/12` (Docker-Netzwerke)

Daher: Tests vom Pi5 selbst oder aus dem LAN lösen keinen Ban aus.

## 🔗 Verwandte Dateien

- `docker/traefik/config/dynamic/routes.yml` – Catch-All Router
- `docker/crowdsec/config/scenarios/direct-ip-hit.yaml` – Custom Scenario
- `docker/traefik/config/traefik.yml` – Access-Log Filter (404 ist enthalten)

---

**Made with Bob** 🤖