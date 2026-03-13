# CrowdSec nftables FORWARD Chain für Docker-Traffic

## Übersicht

Diese Konfiguration erweitert den CrowdSec Firewall-Bouncer um eine **FORWARD-Chain**, die gebannte IPs auch vom Zugriff auf Docker-Container (z.B. Traefik) blockt.

## Problem

Der Standard CrowdSec Firewall-Bouncer erstellt nur eine **INPUT-Chain**, die eingehende Verbindungen zum Server selbst blockt. Docker-Container sind jedoch über das **FORWARD-Hook** erreichbar, da der Traffic durch die Docker-Bridge geroutet wird.

**Ohne FORWARD-Chain:**
- ✅ SSH-Zugriff zum Server wird geblockt
- ❌ HTTPS-Zugriff zu Traefik (Docker) wird NICHT geblockt

**Mit FORWARD-Chain:**
- ✅ SSH-Zugriff zum Server wird geblockt
- ✅ HTTPS-Zugriff zu Traefik (Docker) wird geblockt

## Architektur

```
Internet → Router → Pi5 Firewall (nftables)
                         ↓
                    ┌────┴────┐
                    │  INPUT  │ ← Blockt SSH, direkte Verbindungen
                    └─────────┘
                         ↓
                    ┌────┴────┐
                    │ FORWARD │ ← Blockt Docker-Traffic (Traefik)
                    └─────────┘
                         ↓
                   Docker Bridge
                         ↓
                   Traefik Container
```

## Installation

Die FORWARD-Chain wurde automatisch eingerichtet durch:

### 1. Script: `/etc/crowdsec/nftables-forward-chain.sh`

```bash
#!/bin/bash
# CrowdSec nftables FORWARD chain for Docker traffic
# This script adds a FORWARD chain to block banned IPs from accessing Docker containers

# Wait for nftables and CrowdSec to be ready
echo "Waiting for CrowdSec firewall bouncer to create nftables table..."
for i in {1..30}; do
    if nft list table ip crowdsec &>/dev/null; then
        echo "CrowdSec nftables table found"
        break
    fi
    echo "Attempt $i/30: Waiting for crowdsec table..."
    sleep 2
done

# Check if table exists
if ! nft list table ip crowdsec &>/dev/null; then
    echo "ERROR: CrowdSec nftables table not found after 60 seconds"
    exit 1
fi

# Wait for bouncer to create sets (takes a few seconds after table creation)
echo "Waiting for bouncer to create IP sets..."
sleep 5

# Delete chain if it exists (to recreate with current sets)
if nft list chain ip crowdsec crowdsec-chain-forward &>/dev/null; then
    echo "Deleting existing CrowdSec FORWARD chain..."
    nft delete chain ip crowdsec crowdsec-chain-forward
fi

echo "Creating CrowdSec FORWARD chain..."

# Create FORWARD chain
nft add chain ip crowdsec crowdsec-chain-forward '{ type filter hook forward priority filter; policy accept; }'

# Add blocking rules (without named counters to avoid conflicts)
# Only adds rules for sets that exist - errors are ignored
if nft list set ip crowdsec crowdsec-blacklists-cscli &>/dev/null; then
    nft add rule ip crowdsec crowdsec-chain-forward ip saddr @crowdsec-blacklists-cscli counter drop
    echo "  Added rule for crowdsec-blacklists-cscli"
else
    echo "  Note: crowdsec-blacklists-cscli set not yet created"
fi

if nft list set ip crowdsec crowdsec-blacklists-CAPI &>/dev/null; then
    nft add rule ip crowdsec crowdsec-chain-forward ip saddr @crowdsec-blacklists-CAPI counter drop
    echo "  Added rule for crowdsec-blacklists-CAPI"
else
    echo "  Note: crowdsec-blacklists-CAPI set not yet created"
fi

if nft list set ip crowdsec crowdsec-blacklists-crowdsec &>/dev/null; then
    nft add rule ip crowdsec crowdsec-chain-forward ip saddr @crowdsec-blacklists-crowdsec counter drop
    echo "  Added rule for crowdsec-blacklists-crowdsec"
else
    echo "  Note: crowdsec-blacklists-crowdsec set not yet created"
fi

echo "CrowdSec FORWARD chain created successfully"
```

**Wichtig:**
- Das Script löscht die Chain bei jedem Aufruf und erstellt sie neu (idempotent)
- 5 Sekunden Verzögerung nach Tabellen-Erstellung, damit Bouncer die Sets erstellen kann
- Prüft explizit ob Sets existieren, bevor Regeln hinzugefügt werden
- Verwendet anonyme Counter um Konflikte zu vermeiden

### 2. Systemd Service: `/etc/systemd/system/crowdsec-forward-chain.service`

```ini
[Unit]
Description=CrowdSec nftables FORWARD chain for Docker
After=crowdsec-firewall-bouncer.service
# Warte bis Bouncer wirklich bereit ist
After=network-online.target
# Keine harte Dependency - Service soll auch starten wenn Bouncer neu startet
Wants=crowdsec-firewall-bouncer.service

[Service]
Type=oneshot
# Warte bis Bouncer-Tabelle existiert (bis zu 60 Sekunden)
ExecStart=/etc/crowdsec/nftables-forward-chain.sh
RemainAfterExit=yes
# Restart bei Fehler
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

**Wichtig:**
- `Wants=` statt `Requires=`: Service startet auch wenn Bouncer beim Boot failed und neu startet
- Das Script wartet bis zu 60 Sekunden auf die nftables-Tabelle
- `Restart=on-failure`: Automatischer Neustart bei Fehler

### 3. Service aktiviert

```bash
sudo systemctl enable crowdsec-forward-chain.service
```

Der Service startet automatisch beim Boot nach dem Firewall-Bouncer.

## Wichtiger Hinweis: Dynamische Set-Erstellung

**Die nftables-Sets werden dynamisch erstellt:**

Beim ersten Start existiert nur das `crowdsec-blacklists-CAPI` Set (Community-Blocklist). Die anderen Sets werden erst vom Firewall-Bouncer erstellt, wenn sie benötigt werden:

- `crowdsec-blacklists-cscli` - Wird erstellt bei manuellem Ban (`cscli decisions add`)
- `crowdsec-blacklists-crowdsec` - Wird erstellt bei automatischem Ban (Scenario-Trigger)

**Das Script fügt nur Regeln für existierende Sets hinzu.** Wenn ein Set nicht existiert, wird die Regel übersprungen (Fehler wird ignoriert). Sobald das Set erstellt wird, muss das Script erneut ausgeführt werden oder die Regel manuell hinzugefügt werden.

**Nach einem Reboot:**
```bash
# Prüfen welche Sets existieren
sudo nft list sets ip crowdsec | grep crowdsec-blacklists

# Chain prüfen
sudo nft list chain ip crowdsec crowdsec-chain-forward
```

**Erwartete Ausgabe nach Reboot (ohne aktive Bans):**
```
chain crowdsec-chain-forward {
    type filter hook forward priority filter; policy accept;
    ip saddr @crowdsec-blacklists-CAPI counter packets 0 bytes 0 drop
}
```

Nur die CAPI-Regel ist vorhanden, da die anderen Sets noch nicht existieren.

## Funktionsweise

### nftables-Sets

CrowdSec verwaltet drei IP-Sets in nftables:

1. **crowdsec-blacklists-cscli**: Manuelle Bans (via `cscli decisions add`)
2. **crowdsec-blacklists-CAPI**: Community-Blocklist (24.000+ IPs)
3. **crowdsec-blacklists-crowdsec**: Automatische Bans (Szenarien)

### FORWARD-Chain Regeln

```bash
# Alle Pakete zählen
counter name "processed"

# Manuelle Bans blocken
ip saddr @crowdsec-blacklists-cscli counter name "crowdsec-blacklists-cscli" drop

# Community-Blocklist blocken
ip saddr @crowdsec-blacklists-CAPI counter name "crowdsec-blacklists-CAPI" drop

# Automatische Bans blocken
ip saddr @crowdsec-blacklists-crowdsec counter name "crowdsec-blacklists-crowdsec" drop
```

## Verifikation

### Chain prüfen

```bash
sudo nft list chain ip crowdsec crowdsec-chain-forward
```

**Erwartete Ausgabe:**
```
table ip crowdsec {
	chain crowdsec-chain-forward {
		type filter hook forward priority filter; policy accept;
		counter name "processed"
		ip saddr @crowdsec-blacklists-cscli counter name "crowdsec-blacklists-cscli" drop
		ip saddr @crowdsec-blacklists-CAPI counter name "crowdsec-blacklists-CAPI" drop
		ip saddr @crowdsec-blacklists-crowdsec counter name "crowdsec-blacklists-crowdsec" drop
	}
}
```

### Counter prüfen

```bash
sudo nft list counters ip crowdsec
```

**Beispiel-Ausgabe:**
```
counter processed {
    packets 3562743 bytes 4679946101
}

counter crowdsec-blacklists-cscli {
    packets 108 bytes 16267
}

counter crowdsec-blacklists-CAPI {
    packets 0 bytes 0
}

counter crowdsec-blacklists-crowdsec {
    packets 1540 bytes 101128
}
```

### Geblockte IPs prüfen

```bash
# Aktive Decisions
docker compose exec crowdsec cscli decisions list

# IPs im nftables-Set
sudo nft list set ip crowdsec crowdsec-blacklists-crowdsec
```

## Test

### 1. Manuellen Ban erstellen

```bash
docker compose exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 5m --reason "Test"
```

### 2. IP im Set prüfen

```bash
sudo nft list set ip crowdsec crowdsec-blacklists-cscli
```

**Sollte zeigen:**
```
elements = { 1.2.3.4 timeout 4m59s expires 4m58s }
```

### 3. Von gebannter IP testen

```bash
# Von 1.2.3.4 aus:
curl -I --max-time 5 https://ha.hajo63.de
# Sollte: Connection timed out
```

### 4. Ban aufheben

```bash
docker compose exec crowdsec cscli decisions delete --ip 1.2.3.4
```

## Automatischer Ban-Test (Erfolgreich durchgeführt)

**Test am 2026-02-25:**

1. **3 verschiedene Admin-Pfade** in unter 1 Sekunde aufgerufen:
   - `/admin.php`
   - `/wp-admin/`
   - `/phpmyadmin/`

2. **CrowdSec hat automatisch gebannt:**
   - Scenario: `crowdsecurity/http-admin-interface-probing`
   - IP: `87.122.125.131`
   - Duration: 4 Stunden
   - Country: `DE` (Deutschland)
   - AS: `8881 1&1 Versatel GmbH`

3. **Firewall hat geblockt:**
   - `curl` timeout nach 5 Sekunden
   - IP war im `crowdsec-blacklists-crowdsec` Set
   - FORWARD-Chain Counter: 108 geblockte Pakete

**✅ Test erfolgreich - CrowdSec und Firewall funktionieren vollständig!**

## Troubleshooting

### Chain existiert nicht nach Reboot

```bash
# Service-Status prüfen
sudo systemctl status crowdsec-forward-chain.service

# Manuell ausführen
sudo /etc/crowdsec/nftables-forward-chain.sh

# Service neu starten
sudo systemctl restart crowdsec-forward-chain.service
```

### Gebannte IP kommt trotzdem durch

```bash
# 1. Prüfen ob IP im Set ist
sudo nft list set ip crowdsec crowdsec-blacklists-crowdsec

# 2. Prüfen ob FORWARD-Chain aktiv ist
sudo nft list chain ip crowdsec crowdsec-chain-forward

# 3. Counter prüfen (sollten hochgehen)
sudo nft list counters ip crowdsec | grep crowdsec-blacklists

# 4. Firewall-Bouncer-Logs prüfen
sudo journalctl -u crowdsec-firewall-bouncer -f
```

### Service startet nicht

```bash
# Logs ansehen
sudo journalctl -u crowdsec-forward-chain.service -n 50

# Script manuell testen
sudo bash -x /etc/crowdsec/nftables-forward-chain.sh
```

## Wartung

### Service neu starten

```bash
sudo systemctl restart crowdsec-forward-chain.service
```

### Chain manuell löschen

```bash
sudo nft delete chain ip crowdsec crowdsec-chain-forward
```

### Chain neu erstellen

```bash
sudo /etc/crowdsec/nftables-forward-chain.sh
```

## Wichtige Hinweise

1. **Automatischer Start**: Der Service startet automatisch beim Boot nach dem Firewall-Bouncer
2. **Idempotent**: Das Script prüft, ob die Chain bereits existiert und erstellt sie nur wenn nötig
3. **Keine Änderung am Bouncer**: Der Firewall-Bouncer selbst wird nicht modifiziert
4. **Kompatibel**: Funktioniert mit allen CrowdSec-Versionen und Firewall-Bouncer-Versionen
5. **Performance**: Minimaler Overhead, da nur nftables-Sets verwendet werden

## Siehe auch

- [INSTALLATION-HOST-BOUNCER.md](INSTALLATION-HOST-BOUNCER.md) - Firewall-Bouncer Installation
- [INTEGRATION.md](INTEGRATION.md) - CrowdSec-Traefik Integration
- [CROWDSEC-HOW-IT-WORKS.md](../traefik/CROWDSEC-HOW-IT-WORKS.md) - Funktionsweise

## Kategorie

**Firewall-Konfiguration** (nftables) mit CrowdSec-Integration

Diese Konfiguration gehört zur **Firewall-Ebene**, da sie nftables-Regeln verwaltet. Sie nutzt jedoch CrowdSec-Decisions als Datenquelle für die zu blockenden IPs.

---

*Made with Bob - 2026-02-25*