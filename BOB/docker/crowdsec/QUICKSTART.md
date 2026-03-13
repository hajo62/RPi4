# 🚀 CrowdSec Schnellstart-Anleitung

Diese Anleitung führt dich in 5 Minuten durch die Einrichtung von CrowdSec auf deinem Pi5.

## ✅ Voraussetzungen

- Docker und Docker Compose installiert
- Root-Zugriff (sudo)
- Bestehende nftables-Firewall läuft

## 📝 Schritt-für-Schritt Installation

### 1️⃣ Verzeichnisse erstellen

```bash
cd /home/hajo/docker/crowdsec
mkdir -p config data db
```

### 2️⃣ Umgebungsvariablen konfigurieren

```bash
cp .env.example .env
```

**Hinweis**: Der Bouncer API Key wird im nächsten Schritt generiert.

### 3️⃣ Services starten

```bash
docker compose up -d
```

Warte ca. 30 Sekunden, bis CrowdSec vollständig gestartet ist.

### 4️⃣ Bouncer API Key generieren

```bash
docker compose exec crowdsec cscli bouncers add firewall-bouncer
```

**Output** (Beispiel):
```
Api key for 'firewall-bouncer':
   abc123def456ghi789jkl012mno345pqr678stu901vwx234yz

Please keep this key since you will not be able to retrieve it!
```

**Wichtig**: Kopiere den API Key!

### 5️⃣ API Key in .env eintragen

```bash
nano .env
```

Füge den API Key ein:
```bash
BOUNCER_KEY_FIREWALL=abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
```

Speichern: `Ctrl+O`, `Enter`, `Ctrl+X`

### 6️⃣ Services neu starten

```bash
docker compose down
docker compose up -d
```

### 7️⃣ Installation prüfen

```bash
# Services-Status
docker compose ps

# Sollte zeigen:
# NAME                          STATUS
# crowdsec                      Up
# crowdsec-firewall-bouncer     Up

# Bouncer-Verbindung prüfen
docker compose exec crowdsec cscli bouncers list

# Sollte zeigen:
# NAME              IP ADDRESS    VALID  LAST API PULL
# firewall-bouncer  172.x.x.x     ✔️     2s
```

### 8️⃣ Firewall-Integration prüfen

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

✅ **Wenn du diese Ausgabe siehst, ist CrowdSec erfolgreich installiert!**

## 🧪 Funktionstest

### Test 1: IP manuell blockieren

```bash
# Test-IP blockieren
docker compose exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 5m --reason "Test"

# Prüfen ob IP in nftables ist
sudo nft list set ip crowdsec crowdsec-blacklists

# Sollte enthalten:
# elements = { 1.2.3.4 timeout 5m }

# Test-IP wieder entfernen
docker compose exec crowdsec cscli decisions delete --ip 1.2.3.4
```

### Test 2: SSH Brute-Force simulieren

```bash
# Von einem anderen Rechner im Netzwerk:
# Mehrmals mit falschem Passwort verbinden
ssh wrong-user@192.168.178.55

# Nach 3-5 Versuchen sollte die IP blockiert werden
# Auf dem Pi5 prüfen:
docker compose exec crowdsec cscli decisions list

# Sollte die Test-IP zeigen
```

## 🛡️ Whitelist konfigurieren (WICHTIG!)

Um zu verhindern, dass dein eigenes Netzwerk blockiert wird:

```bash
# Whitelist-Parser installieren
docker compose exec crowdsec cscli parsers install crowdsecurity/whitelists

# Whitelist-Datei erstellen
docker compose exec crowdsec bash -c 'cat > /etc/crowdsec/parsers/s02-enrich/whitelists.yaml << EOF
name: crowdsecurity/whitelists
description: "Whitelist für vertrauenswürdige IPs"
whitelist:
  reason: "Trusted local network"
  ip:
    - "192.168.178.0/24"
    - "127.0.0.1"
    - "::1"
EOF'

# CrowdSec neu starten
docker compose restart crowdsec
```

## 📊 Wichtige Befehle

```bash
# Status prüfen
docker compose ps

# Logs anzeigen
docker compose logs -f

# Geblockte IPs anzeigen
docker compose exec crowdsec cscli decisions list

# Alerts anzeigen
docker compose exec crowdsec cscli alerts list

# Metriken anzeigen
docker compose exec crowdsec cscli metrics

# IP manuell blockieren
docker compose exec crowdsec cscli decisions add --ip <IP> --duration 24h

# IP entsperren
docker compose exec crowdsec cscli decisions delete --ip <IP>

# Alle Blockierungen löschen
docker compose exec crowdsec cscli decisions delete --all
```

## 🔄 In zentrale docker-compose.yml einbinden

Um CrowdSec mit anderen Services zu starten:

```bash
# Hauptverzeichnis
cd /home/hajo/docker

# docker-compose.yml bearbeiten
nano docker-compose.yml
```

Füge hinzu:

```yaml
include:
  - docker/crowdsec/docker-compose.yml
  # ... andere Services
```

Dann:

```bash
# Alle Services starten
docker compose up -d

# CrowdSec-Status prüfen
docker compose ps crowdsec crowdsec-firewall-bouncer
```

## 🎯 Nächste Schritte

1. **Traefik-Integration**: Siehe [README.md](README.md#-integration-mit-traefik)
2. **Community-Intelligence**: Registriere dich auf https://app.crowdsec.net
3. **Monitoring**: Richte Prometheus-Metriken ein
4. **Weitere Collections**: Installiere zusätzliche Regelsets

## 📚 Weitere Dokumentation

- **Vollständige Anleitung**: [README.md](README.md)
- **Firewall-Integration**: [INTEGRATION.md](INTEGRATION.md)
- **Offizielle Docs**: https://docs.crowdsec.net

## 🆘 Probleme?

### CrowdSec startet nicht

```bash
# Logs prüfen
docker compose logs crowdsec

# Häufige Ursachen:
# - Ports bereits belegt (8080)
# - Volumes nicht beschreibbar
# - Docker-Daemon nicht gestartet
```

### Bouncer verbindet nicht

```bash
# API Key prüfen
docker compose exec crowdsec cscli bouncers list

# Neuen Key generieren
docker compose exec crowdsec cscli bouncers add firewall-bouncer-new

# In .env eintragen und neu starten
docker compose down && docker compose up -d
```

### nftables-Tabelle fehlt

```bash
# Bouncer-Logs prüfen
docker compose logs crowdsec-firewall-bouncer

# Bouncer neu starten
docker compose restart crowdsec-firewall-bouncer

# Privileged Mode prüfen
docker compose config | grep privileged
# Sollte "privileged: true" zeigen
```

## ✅ Checkliste

- [ ] Services laufen (`docker compose ps`)
- [ ] Bouncer verbunden (`cscli bouncers list`)
- [ ] nftables-Tabelle existiert (`sudo nft list table ip crowdsec`)
- [ ] Funktionstest erfolgreich (Test-IP blockiert)
- [ ] Whitelist konfiguriert
- [ ] Logs überwacht (erste 24h)

---

**Made with Bob** 🤖

**Geschätzte Zeit**: 5-10 Minuten  
**Schwierigkeit**: Einfach  
**Support**: Siehe [README.md](README.md) oder https://discourse.crowdsec.net