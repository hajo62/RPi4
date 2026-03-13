# 🌐 CrowdSec Community-Intelligence einrichten

Diese Anleitung zeigt, wie du CrowdSec mit der globalen Community verbindest, um von Millionen geteilter Bedrohungsdaten zu profitieren.

## 🎯 Was bringt Community-Intelligence?

### Ohne Community:
- ❌ Nur lokale Angriffserkennung
- ❌ Reaktiv (erst blockieren nach Angriff)
- ❌ Keine globalen Bedrohungsdaten
- ❌ Jeder Angreifer kann es versuchen

### Mit Community (EMPFOHLEN):
- ✅ Globale Blocklisten (Millionen bekannter böser IPs)
- ✅ Proaktiv (blockieren bevor sie angreifen)
- ✅ Echtzeit-Updates von der Community
- ✅ Web-Dashboard mit Statistiken
- ✅ Deine Daten helfen anderen

## 📋 Schnellstart (5 Minuten)

### Schritt 1: CrowdSec Account erstellen

1. Öffne: https://app.crowdsec.net
2. Klicke auf "Sign Up" (kostenlos)
3. Bestätige E-Mail und logge dich ein

### Schritt 2: Enrollment-Befehl kopieren

1. Gehe zu **"Security Engines"** oder **"Engines"**
2. Klicke auf **"Add Security Engine"**
3. Du siehst einen Befehl wie:
   ```bash
   sudo cscli console enroll cmm15996d000q02jmwdoi9jed
   ```
4. **Kopiere diesen Befehl** (dein Key ist anders!)

### Schritt 3: Enrollment auf dem Pi5 ausführen

```bash
cd /home/hajo/docker/crowdsec

# Führe den kopierten Befehl aus (OHNE sudo, MIT docker compose exec)
docker compose exec crowdsec cscli console enroll cmm15996d000q02jmwdoi9jed
```

**Erwartete Ausgabe:**
```
INFO manual set to true
INFO context set to true
INFO Enabled manual : Forward manual decisions to the console
INFO Enabled tainted : Forward alerts from tainted scenarios to the console
INFO Enabled context : Forward context with alerts to the console
INFO Watcher successfully enrolled. Visit https://app.crowdsec.net to accept it.
INFO Please restart crowdsec after accepting the enrollment.
```

### Schritt 4: Im Dashboard akzeptieren

1. Gehe zurück zu https://app.crowdsec.net
2. Du solltest eine Benachrichtigung sehen
3. Klicke auf **"Accept"** oder **"Approve"**
4. Deine Engine wird als **"Active"** angezeigt

### Schritt 5: CrowdSec neu starten

```bash
docker compose restart crowdsec
```

### Schritt 6: Console Management aktivieren

```bash
# Aktiviere Empfang von Community-Decisions
docker compose exec crowdsec cscli console enable console_management

# Neu starten
docker compose restart crowdsec
```

### Schritt 7: Status prüfen

```bash
docker compose exec crowdsec cscli console status
```

**Sollte zeigen:**
```
╭────────────────────┬───────────┬──────────────────────────────────────────────────────╮
│ Option Name        │ Activated │ Description                                          │
├────────────────────┼───────────┼──────────────────────────────────────────────────────┤
│ custom             │ ✅        │ Forward alerts from custom scenarios to the console  │
│ manual             │ ✅        │ Forward manual decisions to the console              │
│ tainted            │ ✅        │ Forward alerts from tainted scenarios to the console │
│ context            │ ✅        │ Forward context with alerts to the console           │
│ console_management │ ✅        │ Receive decisions from console                       │
╰────────────────────┴───────────┴──────────────────────────────────────────────────────╯
```

**Wichtig**: `console_management` muss ✅ sein!

### Schritt 8: Fertig! 🎉

Prüfe die installierten Collections:

```bash
docker compose exec crowdsec cscli collections list
```

Du solltest sehen:
- ✅ `crowdsecurity/linux`
- ✅ `crowdsecurity/sshd`
- ✅ `crowdsecurity/nginx`
- ✅ `crowdsecurity/traefik`
- ✅ `crowdsecurity/http-cve`
- ✅ `crowdsecurity/whitelist-good-actors`

## ✅ Überprüfung

### Decisions prüfen

```bash
# Aktuelle Decisions (sollte anfangs leer sein)
docker compose exec crowdsec cscli decisions list
```

**"No active decisions" ist NORMAL und GUT!**

Das bedeutet:
- ✅ CrowdSec läuft korrekt
- ✅ Firewall Bouncer ist verbunden
- ✅ Aktuell keine Angriffe → Dein Pi5 ist sicher!

### nftables prüfen

```bash
# CrowdSec-Tabelle anzeigen
sudo nft list table ip crowdsec

# Blacklist-Set anzeigen (sollte leer sein)
sudo nft list set ip crowdsec crowdsec-blacklists-cscli
```

**Erwartete Ausgabe:**
```
table ip crowdsec {
    set crowdsec-blacklists-cscli {
        type ipv4_addr
        flags timeout
    }
}
```

Das Set ist bereit und wird automatisch gefüllt, wenn Angriffe erkannt werden!

### Test-Blockierung (optional)

```bash
# Test-IP blockieren
docker compose exec crowdsec cscli decisions add --ip 8.8.8.8 --duration 2m --reason "Test"

# Prüfen
docker compose exec crowdsec cscli decisions list
sudo nft list set ip crowdsec crowdsec-blacklists-cscli

# Nach 2 Minuten automatisch entfernt
```

## 📊 Was du jetzt siehst

### Im CrowdSec Dashboard:

- **Alerts**: Erkannte Angriffe auf deinen Pi5
- **Decisions**: Geblockte IPs (lokal + Community)
- **Metrics**: Statistiken über Angriffe
- **Scenarios**: Welche Angriffsszenarien erkannt wurden
- **Top Countries**: Woher die Angriffe kommen
- **Timeline**: Zeitlicher Verlauf

### Auf dem Pi5:

```bash
# Alle Decisions (lokal + Community)
docker compose exec crowdsec cscli decisions list

# Nur Community-Decisions
docker compose exec crowdsec cscli decisions list --origin cscli

# Alerts
docker compose exec crowdsec cscli alerts list

# Metriken
docker compose exec crowdsec cscli metrics
```

## 🔍 Community-Blocklisten aktivieren

Standardmäßig erhältst du bereits Community-Daten. Für zusätzliche Blocklisten:

### Beliebte Community-Blocklisten:

```bash
# Firehol Level 1 (bekannte böse IPs)
docker compose exec crowdsec cscli scenarios install crowdsecurity/firehol_level1

# Tor Exit Nodes (optional, falls du Tor blockieren willst)
docker compose exec crowdsec cscli scenarios install crowdsecurity/tor-exit-nodes

# VPN-Anbieter (optional)
docker compose exec crowdsec cscli scenarios install crowdsecurity/vpn-iplist

# CrowdSec Community Blocklist
docker compose exec crowdsec cscli scenarios install crowdsecurity/community-blocklist
```

Nach Installation neu starten:

```bash
docker compose restart crowdsec
```

## 🎛️ Einstellungen anpassen

### Sharing-Optionen konfigurieren

```bash
# Was wird geteilt?
docker compose exec crowdsec cscli console status

# Sharing deaktivieren (nicht empfohlen)
docker compose exec crowdsec cscli console disable share_manual_decisions
docker compose exec crowdsec cscli console disable share_context

# Sharing aktivieren
docker compose exec crowdsec cscli console enable share_manual_decisions
docker compose exec crowdsec cscli console enable share_context
```

**Empfehlung**: Alles aktiviert lassen für maximalen Schutz!

## 🔐 Datenschutz

### Was wird geteilt?

- ✅ IP-Adressen von Angreifern
- ✅ Angriffstyp (SSH Brute-Force, etc.)
- ✅ Zeitstempel
- ✅ Deine Engine-ID

### Was wird NICHT geteilt?

- ❌ Keine Log-Inhalte
- ❌ Keine Passwörter
- ❌ Keine persönlichen Daten
- ❌ Keine Konfigurationsdateien
- ❌ Keine internen IP-Adressen

**Fazit**: Datenschutzfreundlich und sicher! 🔒

## 📈 Monitoring

### Dashboard-Metriken

Im Web-Dashboard siehst du:

- **Total Alerts**: Anzahl erkannter Angriffe
- **Active Decisions**: Aktuell geblockte IPs
- **Top Scenarios**: Häufigste Angriffstypen
- **Geographic Distribution**: Woher die Angriffe kommen
- **Timeline**: Angriffe über Zeit

### CLI-Metriken

```bash
# Übersicht
docker compose exec crowdsec cscli metrics

# Decisions
docker compose exec crowdsec cscli decisions list

# Alerts
docker compose exec crowdsec cscli alerts list --limit 20

# Hub-Status
docker compose exec crowdsec cscli hub list
```

## 🆘 Troubleshooting

### Problem: Enrollment schlägt fehl

**Symptom**: "failed to enroll" in Logs

**Lösung**:

```bash
# 1. Prüfe Enrollment Key
cat .env | grep ENROLL_KEY

# 2. Prüfe Internet-Verbindung
docker compose exec crowdsec ping -c 3 api.crowdsec.net

# 3. Neuen Key generieren
# Gehe zu https://app.crowdsec.net
# Lösche alte Engine und erstelle neue
# Kopiere neuen Key in .env

# 4. Neu starten
docker compose down
docker compose up -d
```

### Problem: Engine zeigt "Offline"

**Symptom**: Dashboard zeigt Engine als offline

**Lösung**:

```bash
# 1. Prüfe Container-Status
docker compose ps

# 2. Prüfe Console-Status
docker compose exec crowdsec cscli console status

# 3. Prüfe Logs
docker compose logs crowdsec | tail -50

# 4. Neu enrollen
docker compose exec crowdsec cscli console enroll <neuer-key>
```

### Problem: Keine Community-Decisions

**Symptom**: Nur lokale Decisions, keine von Community

**Lösung**:

```bash
# 1. Prüfe Console-Status
docker compose exec crowdsec cscli console status
# Sollte "Console: ✔️" zeigen

# 2. Prüfe Hub-Updates
docker compose exec crowdsec cscli hub update
docker compose exec crowdsec cscli hub upgrade

# 3. Installiere Community-Blocklist
docker compose exec crowdsec cscli scenarios install crowdsecurity/community-blocklist

# 4. Neu starten
docker compose restart crowdsec
```

## 🎯 Best Practices

1. **Enrollment Key geheim halten**: Nicht in Git committen!
2. **Dashboard regelmäßig prüfen**: Mindestens wöchentlich
3. **Hub aktualisieren**: Monatlich neue Scenarios installieren
4. **Sharing aktiviert lassen**: Hilft der Community
5. **Tags nutzen**: Erleichtert Verwaltung mehrerer Engines

## 📚 Weiterführende Informationen

- **CrowdSec Console**: https://app.crowdsec.net
- **Dokumentation**: https://docs.crowdsec.net/docs/console/intro
- **Hub (Scenarios)**: https://hub.crowdsec.net
- **Community Forum**: https://discourse.crowdsec.net

## ✅ Checkliste

Nach erfolgreicher Einrichtung:

- [ ] Account auf app.crowdsec.net erstellt
- [ ] Engine hinzugefügt
- [ ] Enrollment Key in .env eingetragen
- [ ] Container neu gestartet
- [ ] Enrollment erfolgreich (Logs geprüft)
- [ ] Engine zeigt "Online" im Dashboard
- [ ] Console-Status zeigt alle Optionen aktiviert
- [ ] Community-Blocklisten installiert (optional)
- [ ] Dashboard zeigt erste Daten

---

**Made with Bob** 🤖

Du profitierst jetzt von der globalen CrowdSec-Community! 🌐🛡️