# 🔗 CrowdSec Integration mit bestehender nftables-Firewall

Diese Anleitung erklärt, wie CrowdSec mit der bestehenden nftables-Firewall auf dem Pi5 integriert wird.

## 📋 Übersicht

CrowdSec erstellt eine eigene nftables-Tabelle (`crowdsec`) und Chain (`crowdsec-chain`), die **vor** den bestehenden Firewall-Regeln ausgeführt wird. Dadurch werden böse IPs blockiert, bevor sie die Hauptfirewall erreichen.

## 🏗️ Architektur

```
Internet
   │
   ▼
┌─────────────────────────────────────┐
│  nftables Priority-Reihenfolge      │
├─────────────────────────────────────┤
│                                     │
│  1. CrowdSec Table (Priority: -10)  │◄── Blockiert böse IPs
│     └─ crowdsec-chain               │
│                                     │
│  2. Filter Table (Priority: 0)      │◄── Deine Firewall-Regeln
│     ├─ input                        │
│     ├─ forward                      │
│     └─ output                       │
│                                     │
└─────────────────────────────────────┘
```

## ⚙️ Konfiguration

### 1. CrowdSec nftables-Tabelle

Der Firewall Bouncer erstellt automatisch:

```nftables
table ip crowdsec {
    set crowdsec-blacklists {
        type ipv4_addr
        flags timeout
    }
    
    chain crowdsec-chain {
        type filter hook input priority -10; policy accept;
        ip saddr @crowdsec-blacklists drop
    }
}
```

**Wichtig**: Priority `-10` bedeutet, dass diese Chain **vor** der Standard-Filter-Tabelle (Priority `0`) ausgeführt wird.

### 2. Bestehende Firewall bleibt unverändert

Deine `nftables-pi5.conf` bleibt wie sie ist:

```nftables
table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        # ... deine Regeln ...
    }
}
```

### 3. Zusammenspiel

1. **Paket kommt an** → CrowdSec prüft zuerst (Priority -10)
2. **IP in Blacklist?** → DROP (Paket wird verworfen)
3. **IP nicht in Blacklist?** → Weiter zur Hauptfirewall (Priority 0)
4. **Hauptfirewall** → Normale Regeln greifen

## 🚀 Installation & Setup

### Schritt 1: CrowdSec starten

```bash
cd /home/hajo/docker/crowdsec

# .env erstellen
cp .env.example .env

# Services starten
docker compose up -d

# Logs verfolgen
docker compose logs -f
```

### Schritt 2: Bouncer API Key generieren

```bash
# API Key erstellen
docker compose exec crowdsec cscli bouncers add firewall-bouncer

# Output kopieren, z.B.:
# Api key for 'firewall-bouncer':
#    abc123def456ghi789jkl012mno345pqr678stu901vwx234yz

# In .env eintragen
nano .env
# BOUNCER_KEY_FIREWALL=abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
```

### Schritt 3: Services neu starten

```bash
docker compose down
docker compose up -d
```

### Schritt 4: Firewall-Integration prüfen

```bash
# CrowdSec nftables-Tabelle anzeigen
sudo nft list table ip crowdsec

# Sollte ausgeben:
# table ip crowdsec {
#     set crowdsec-blacklists {
#         type ipv4_addr
#         flags timeout
#     }
#     
#     chain crowdsec-chain {
#         type filter hook input priority -10; policy accept;
#         ip saddr @crowdsec-blacklists drop
#     }
# }
```

### Schritt 5: Funktionstest

```bash
# 1. Test-IP manuell blockieren
docker compose exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 5m --reason "Test"

# 2. Prüfen ob IP in nftables ist
sudo nft list set ip crowdsec crowdsec-blacklists

# Sollte enthalten:
# set crowdsec-blacklists {
#     type ipv4_addr
#     flags timeout
#     elements = { 1.2.3.4 timeout 5m }
# }

# 3. Test-IP wieder entfernen
docker compose exec crowdsec cscli decisions delete --ip 1.2.3.4
```

## 🔍 Monitoring & Debugging

### Aktuelle Blockierungen anzeigen

```bash
# Geblockte IPs in CrowdSec
docker compose exec crowdsec cscli decisions list

# Geblockte IPs in nftables
sudo nft list set ip crowdsec crowdsec-blacklists

# Beide sollten übereinstimmen!
```

### Firewall-Regeln Übersicht

```bash
# Alle nftables-Tabellen anzeigen
sudo nft list ruleset

# Nur CrowdSec-Tabelle
sudo nft list table ip crowdsec

# Nur Hauptfirewall
sudo nft list table inet filter
```

### Logs überwachen

```bash
# CrowdSec Logs
docker compose logs -f crowdsec

# Bouncer Logs
docker compose logs -f crowdsec-firewall-bouncer

# Beide zusammen
docker compose logs -f
```

### Metriken

```bash
# CrowdSec Metriken
docker compose exec crowdsec cscli metrics

# Zeigt:
# - Anzahl geblockter IPs
# - Anzahl verarbeiteter Logs
# - Anzahl erkannter Angriffe
```

## 🛡️ Whitelist konfigurieren

Um zu verhindern, dass dein eigenes Netzwerk blockiert wird:

### 1. Whitelist-Parser installieren

```bash
docker compose exec crowdsec cscli parsers install crowdsecurity/whitelists
```

### 2. Whitelist konfigurieren

```bash
# Datei erstellen
docker compose exec crowdsec nano /etc/crowdsec/parsers/s02-enrich/whitelists.yaml
```

Inhalt:

```yaml
name: crowdsecurity/whitelists
description: "Whitelist für vertrauenswürdige IPs"
whitelist:
  reason: "Trusted local network and known IPs"
  ip:
    # Lokales Netzwerk
    - "192.168.178.0/24"
    
    # Loopback
    - "127.0.0.1"
    - "::1"
    
    # Docker-Netzwerke
    - "172.20.0.0/16"
    - "172.30.0.0/16"
    
    # Pi4 Backend-Server
    - "192.168.178.3"
    - "192.168.178.33"
    
    # Externe IP (wird automatisch aktualisiert)
    # - "203.0.113.1"  # Beispiel - wird durch update-whitelist.sh ersetzt
  
  expression:
    # Whitelist für bestimmte Scenarios
    # - evt.Parsed.program == 'my-trusted-app'
```

### 3. CrowdSec neu starten

```bash
docker compose restart crowdsec
```

### 4. Whitelist testen

```bash
# Versuche eine whitelistete IP zu blockieren
docker compose exec crowdsec cscli decisions add --ip 192.168.178.1 --duration 1h

# Sollte abgelehnt werden mit:
# WARN[...] 192.168.178.1 is whitelisted by 'crowdsecurity/whitelists'
```

## 🔄 Automatische Whitelist-Aktualisierung (Dynamische IP)

Wenn du eine dynamische externe IP hast (DynDNS), kann die Whitelist automatisch aktualisiert werden:

### 1. Whitelist-Script

Das Script `/home/hajo/docker/crowdsec/scripts/update-whitelist.sh` liest die aktuelle externe IP aus `ionos-dyndns/data/status.json` und aktualisiert die Whitelist.

```bash
#!/bin/bash
# Automatische Whitelist-Aktualisierung bei IP-Änderung

# Externe IP aus DynDNS-Status lesen
EXTERNAL_IP=$(jq -r '.current_ip // empty' /home/hajo/docker/ionos-dyndns/data/status.json)

# Whitelist aktualisieren
# ... (siehe scripts/update-whitelist.sh für Details)
```

### 2. Integration mit DynDNS

Das DynDNS-Script (`ionos-dyndns/scripts/update_dyndns.sh`) triggert automatisch das Whitelist-Update:

```bash
# Nach erfolgreichem DynDNS-Update
if [ -x "/home/hajo/docker/crowdsec/scripts/update-whitelist.sh" ]; then
  sudo /home/hajo/docker/crowdsec/scripts/update-whitelist.sh
fi
```

### 3. Sudoers-Regel einrichten

Damit das DynDNS-Script das Whitelist-Script ausführen kann:

```bash
sudo visudo
```

Füge hinzu:

```bash
# DynDNS Container darf CrowdSec Whitelist updaten
root ALL=(ALL) NOPASSWD: /home/hajo/docker/crowdsec/scripts/update-whitelist.sh
```

### 4. Funktionsweise

```
1. IP ändert sich (z.B. 1.2.3.4 → 5.6.7.8)
   ↓
2. DynDNS-Script erkennt Änderung
   ↓
3. DynDNS-Update bei Ionos (erfolgreich)
   ↓
4. status.json wird aktualisiert
   ↓
5. Whitelist-Script wird getriggert
   ↓
6. mywhitelists.yaml wird aktualisiert
   ↓
7. CrowdSec wird neu gestartet
   ↓
8. Neue IP ist whitelisted!
```

### 5. Manuelle Aktualisierung

Falls nötig, kann die Whitelist manuell aktualisiert werden:

```bash
# Whitelist manuell aktualisieren
sudo /home/hajo/docker/crowdsec/scripts/update-whitelist.sh

# Status prüfen
cat /home/hajo/docker/crowdsec/config/parsers/s02-enrich/mywhitelists.yaml

# CrowdSec-Logs prüfen
docker compose -f /home/hajo/docker/crowdsec/docker-compose.yml logs -f
```

### 6. Vorteile

| Feature | Status |
|---------|--------|
| **Automatisch** | ✅ Bei IP-Änderung |
| **Zuverlässig** | ✅ Nutzt status.json |
| **Fehlertoleranz** | ✅ Non-critical |
| **Event-basiert** | ✅ Kein Cron nötig |
| **Logging** | ✅ In DynDNS-Logs |

## 🔧 Erweiterte Konfiguration

### nftables-Tabelle anpassen

Falls du die CrowdSec-Tabelle anpassen möchtest:

```bash
# Bouncer-Konfiguration bearbeiten
docker compose exec crowdsec-firewall-bouncer nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```

Wichtige Parameter:

```yaml
# Firewall-Backend
mode: nftables

# nftables-Einstellungen
nftables:
  # Tabellenname
  table: crowdsec
  
  # Chain-Name
  chain: crowdsec-chain
  
  # Priority (niedriger = früher)
  priority: -10

# Blacklist-Modus
blacklists_ipv4: crowdsec-blacklists
blacklists_ipv6: crowdsec6-blacklists

# Update-Intervall (Sekunden)
update_frequency: 10

# Log-Level
log_mode: file
log_dir: /var/log/
log_level: info
```

### IPv6 Support

CrowdSec unterstützt auch IPv6:

```bash
# IPv6-Tabelle prüfen
sudo nft list table ip6 crowdsec

# Sollte ähnlich wie IPv4 sein:
# table ip6 crowdsec {
#     set crowdsec6-blacklists {
#         type ipv6_addr
#         flags timeout
#     }
#     
#     chain crowdsec6-chain {
#         type filter hook input priority -10; policy accept;
#         ip6 saddr @crowdsec6-blacklists drop
#     }
# }
```

## 🚨 Troubleshooting

### Problem: nftables-Tabelle wird nicht erstellt

**Symptom**: `sudo nft list table ip crowdsec` zeigt Fehler

**Lösung**:

```bash
# 1. Bouncer-Logs prüfen
docker compose logs crowdsec-firewall-bouncer

# 2. Privileged Mode prüfen
docker compose ps
# crowdsec-firewall-bouncer sollte "privileged: true" haben

# 3. Bouncer neu starten
docker compose restart crowdsec-firewall-bouncer

# 4. Manuell testen
docker compose exec crowdsec-firewall-bouncer cs-firewall-bouncer -c /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml -t
```

### Problem: IPs werden nicht blockiert

**Symptom**: Decisions vorhanden, aber nicht in nftables

**Lösung**:

```bash
# 1. Decisions prüfen
docker compose exec crowdsec cscli decisions list

# 2. nftables prüfen
sudo nft list set ip crowdsec crowdsec-blacklists

# 3. Bouncer-Status prüfen
docker compose exec crowdsec cscli bouncers list
# Sollte "firewall-bouncer" mit "last_pull" < 1 Minute zeigen

# 4. Bouncer-Logs prüfen
docker compose logs crowdsec-firewall-bouncer | grep -i error

# 5. Manuell synchronisieren
docker compose restart crowdsec-firewall-bouncer
```

### Problem: Bestehende Firewall-Regeln funktionieren nicht mehr

**Symptom**: Services nicht mehr erreichbar nach CrowdSec-Start

**Lösung**:

```bash
# 1. CrowdSec-Tabelle prüfen
sudo nft list table ip crowdsec

# 2. Policy sollte "accept" sein, nicht "drop"
# chain crowdsec-chain {
#     type filter hook input priority -10; policy accept;  ← WICHTIG!
# }

# 3. Falls falsch, Bouncer neu konfigurieren
docker compose down
# docker-compose.yml prüfen: MODE=drop (nicht reject oder tarpit)
docker compose up -d

# 4. Hauptfirewall prüfen
sudo nft list table inet filter
# Sollte unverändert sein
```

### Problem: Zu viele Blockierungen

**Symptom**: Legitime Zugriffe werden blockiert

**Lösung**:

```bash
# 1. Aktuelle Decisions prüfen
docker compose exec crowdsec cscli decisions list

# 2. Alerts prüfen (warum wurde blockiert?)
docker compose exec crowdsec cscli alerts list

# 3. Whitelist konfigurieren (siehe oben)

# 4. Scenario deaktivieren (falls zu aggressiv)
docker compose exec crowdsec cscli scenarios list
docker compose exec crowdsec cscli scenarios remove <scenario-name>

# 5. Alle Decisions löschen (Neustart)
docker compose exec crowdsec cscli decisions delete --all
```

## 📊 Performance-Optimierung

### Ressourcenverbrauch reduzieren

```bash
# 1. Update-Frequenz erhöhen (weniger Updates)
# In docker-compose.yml:
# UPDATE_FREQUENCY=30  # statt 10 Sekunden

# 2. Weniger Logs analysieren
# Nur kritische Logs einbinden

# 3. Alte Decisions automatisch löschen
# In CrowdSec-Konfiguration:
# decision_retention: 24h  # statt 7d
```

### Monitoring

```bash
# Ressourcenverbrauch prüfen
docker stats crowdsec crowdsec-firewall-bouncer

# Sollte zeigen:
# - CPU: < 5%
# - RAM: < 100MB (crowdsec), < 50MB (bouncer)
```

## 🎯 Best Practices

1. **Whitelist zuerst**: Konfiguriere Whitelist vor Produktivbetrieb
2. **Monitoring**: Überwache die ersten Tage intensiv
3. **Backup**: Sichere Konfiguration regelmäßig
4. **Updates**: Halte CrowdSec und Collections aktuell
5. **Dokumentation**: Dokumentiere Anpassungen

## 📚 Weiterführende Informationen

- **CrowdSec Dokumentation**: https://docs.crowdsec.net
- **nftables Dokumentation**: https://wiki.nftables.org
- **Firewall Bouncer**: https://docs.crowdsec.net/docs/bouncers/firewall

---

**Made with Bob** 🤖

Für weitere Fragen siehe [README.md](README.md) oder die [offizielle Dokumentation](https://docs.crowdsec.net).
