# Wie CrowdSec mit mehreren Bouncern funktioniert

## 🤔 Die wichtige Frage

**"Wenn eine IP auf HTTP-Ebene Unfug treibt, wird sie auch in der Firewall geblockt?"**

**Antwort: JA! Alle Bouncer teilen sich die gleichen Entscheidungen.**

## 🏗️ Architektur im Detail

### Zentrale Entscheidungen

CrowdSec trifft **zentrale Entscheidungen**, die von **allen Bouncern** abgerufen werden:

```
┌─────────────────────────────────────────────────────┐
│           CrowdSec Container (Zentrale)             │
│                                                     │
│  📊 Analysiert Logs von:                           │
│     - Traefik Access-Logs                          │
│     - SSH-Logs (/var/log/auth.log)                │
│     - System-Logs (/var/log/syslog)               │
│                                                     │
│  🧠 Erkennt Angriffe:                              │
│     - HTTP-DOS (zu viele Requests)                 │
│     - SSH Brute-Force                              │
│     - HTTP-CVE (Exploit-Versuche)                  │
│     - Port-Scans                                   │
│                                                     │
│  ⚖️ Trifft EINE zentrale Entscheidung:             │
│     "IP 1.2.3.4 blocken für 4 Stunden"            │
│                                                     │
│  💾 Decisions Database (zentral!)                  │
│     ┌─────────────────────────────────────┐       │
│     │ IP: 1.2.3.4                         │       │
│     │ Grund: crowdsecurity/http-dos       │       │
│     │ Dauer: 4h                           │       │
│     │ Quelle: Traefik-Logs                │       │
│     └─────────────────────────────────────┘       │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ LAPI (Local API - Port 8080)
                   │ Alle Bouncer fragen hier nach Decisions
                   │
       ┌───────────┴───────────┬─────────────────┐
       │                       │                 │
       ▼                       ▼                 ▼
┌──────────────┐    ┌──────────────────┐  ┌──────────────┐
│ Firewall     │    │ Traefik Plugin   │  │ nginx Bouncer│
│ Bouncer      │    │                  │  │ (optional)   │
│ (Host)       │    │ (in Traefik)     │  │              │
│              │    │                  │  │              │
│ Fragt alle   │    │ Fragt alle       │  │ Fragt alle   │
│ 10 Sekunden: │    │ 10 Sekunden:     │  │ 10 Sekunden: │
│ "Neue IPs?"  │    │ "Neue IPs?"      │  │ "Neue IPs?"  │
│              │    │                  │  │              │
│ ✅ Blockiert │    │ ✅ Blockiert     │  │ ✅ Blockiert │
│ 1.2.3.4 in   │    │ 1.2.3.4 in       │  │ 1.2.3.4 in   │
│ nftables     │    │ Traefik (HTTP)   │  │ nginx        │
└──────────────┘    └──────────────────┘  └──────────────┘
```

## 📝 Beispiel-Szenario

### Szenario 1: HTTP-DOS-Angriff

```
1. Angreifer (IP 1.2.3.4) sendet 1000 Requests/Sekunde an https://ha.hajo63.de

2. Traefik schreibt Access-Logs:
   {"ClientAddr":"1.2.3.4","RequestPath":"/","StatusCode":200}
   {"ClientAddr":"1.2.3.4","RequestPath":"/","StatusCode":200}
   ... (1000x)

3. CrowdSec liest Traefik-Logs (via acquis.yaml)

4. CrowdSec erkennt: "IP 1.2.3.4 macht HTTP-DOS"
   Scenario: crowdsecurity/http-dos
   Threshold: > 100 Requests/10s

5. CrowdSec erstellt Entscheidung:
   ┌─────────────────────────────────────┐
   │ IP: 1.2.3.4                         │
   │ Type: ban                           │
   │ Grund: crowdsecurity/http-dos       │
   │ Dauer: 4 Stunden                    │
   │ Quelle: Traefik Access-Logs         │
   └─────────────────────────────────────┘

6. ALLE Bouncer holen diese Entscheidung (alle 10 Sekunden):

   a) Firewall-Bouncer (Host):
      - Fügt 1.2.3.4 zu nftables hinzu
      - sudo nft add element ip crowdsec crowdsec-blacklists { 1.2.3.4 }
      - ✅ IP ist auf Kernel-Ebene geblockt
      - Pakete von 1.2.3.4 werden sofort verworfen

   b) Traefik-Bouncer (Plugin):
      - Fügt 1.2.3.4 zur internen Blocklist hinzu
      - ✅ IP ist auf HTTP-Ebene geblockt
      - Requests von 1.2.3.4 bekommen 403 Forbidden

7. Ergebnis:
   - ✅ IP 1.2.3.4 ist ÜBERALL geblockt
   - ✅ Firewall: Pakete werden verworfen (Kernel-Ebene)
   - ✅ Traefik: HTTP-Requests werden abgelehnt (Application-Ebene)
   - ✅ Doppelter Schutz!
```

### Szenario 2: SSH Brute-Force

```
1. Angreifer (IP 5.6.7.8) versucht SSH Brute-Force

2. SSH schreibt Logs:
   Feb 25 19:00:01 rpi5 sshd[1234]: Failed password for root from 5.6.7.8
   Feb 25 19:00:02 rpi5 sshd[1235]: Failed password for admin from 5.6.7.8
   ... (10x)

3. CrowdSec liest SSH-Logs (/var/log/auth.log)

4. CrowdSec erkennt: "IP 5.6.7.8 macht SSH Brute-Force"
   Scenario: crowdsecurity/ssh-bf
   Threshold: > 5 failed logins

5. CrowdSec erstellt Entscheidung:
   ┌─────────────────────────────────────┐
   │ IP: 5.6.7.8                         │
   │ Type: ban                           │
   │ Grund: crowdsecurity/ssh-bf         │
   │ Dauer: 24 Stunden                   │
   │ Quelle: SSH-Logs                    │
   └─────────────────────────────────────┘

6. ALLE Bouncer holen diese Entscheidung:

   a) Firewall-Bouncer:
      - ✅ Blockiert 5.6.7.8 in nftables
      - IP kann nicht mal mehr SSH-Port erreichen

   b) Traefik-Bouncer:
      - ✅ Blockiert 5.6.7.8 auch für HTTP
      - IP kann auch keine Webseiten mehr aufrufen

7. Ergebnis:
   - ✅ IP 5.6.7.8 ist komplett isoliert
   - ✅ Kein SSH-Zugriff
   - ✅ Kein HTTP-Zugriff
   - ✅ Kein Netzwerk-Zugriff überhaupt
```

## 🔍 Warum mehrere Bouncer?

### Defense in Depth (Verteidigung in der Tiefe)

```
Internet
   │
   ▼
┌─────────────────────────────────────┐
│ 1. Firewall-Bouncer (nftables)      │  ← Erste Verteidigungslinie
│    - Kernel-Ebene                   │     Schnellste Reaktion
│    - Blockiert ALLE Pakete          │     Spart Ressourcen
│    - Sehr schnell                   │
└──────────────┬──────────────────────┘
               │ Falls IP durchkommt
               │ (z.B. neue IP)
               ▼
┌─────────────────────────────────────┐
│ 2. Traefik-Bouncer (HTTP)           │  ← Zweite Verteidigungslinie
│    - Application-Ebene              │     Detaillierte Logs
│    - Blockiert HTTP-Requests        │     Bessere Fehlerseiten
│    - Detaillierte Logs              │
└─────────────────────────────────────┘
```

### Vorteile

1. **Redundanz**: Falls ein Bouncer ausfällt, schützt der andere
2. **Verschiedene Ebenen**: Kernel + Application
3. **Bessere Logs**: Traefik sieht HTTP-Details, Firewall sieht Netzwerk-Details
4. **Flexibilität**: Verschiedene Blocking-Strategien möglich

## 📊 Entscheidungs-Synchronisation

### Wie oft werden Entscheidungen abgerufen?

```yaml
# Firewall-Bouncer (docker-compose.yml)
UPDATE_FREQUENCY: 10  # Alle 10 Sekunden

# Traefik-Bouncer (config/dynamic/middlewares.yml)
crowdsecMode: "live"  # Echtzeit-Abfrage
```

**Bedeutet:**
- Firewall-Bouncer fragt alle 10 Sekunden nach neuen IPs
- Traefik-Bouncer fragt bei jedem Request nach (live mode)
- Maximale Verzögerung: 10 Sekunden bis IP in Firewall ist

### Entscheidungs-Lebenszyklus

```
1. CrowdSec erkennt Angriff
   ↓
2. Entscheidung wird erstellt (z.B. 4h Dauer)
   ↓
3. Alle Bouncer holen Entscheidung
   ↓
4. IP ist überall geblockt
   ↓
5. Nach 4 Stunden: Entscheidung läuft ab
   ↓
6. Alle Bouncer entfernen IP automatisch
   ↓
7. IP ist wieder erlaubt
```

## 🎯 Zusammenfassung

### Die wichtigsten Punkte

1. **Zentrale Entscheidungen**: CrowdSec trifft EINE Entscheidung pro IP
2. **Alle Bouncer teilen sich diese**: Jeder Bouncer holt die gleichen Decisions
3. **Quelle egal**: Egal ob HTTP, SSH oder Port-Scan - alle Bouncer blockieren
4. **Doppelter Schutz**: Firewall (Kernel) + Traefik (HTTP)
5. **Automatische Synchronisation**: Alle 10 Sekunden (Firewall) bzw. live (Traefik)

### Praktisches Beispiel

```bash
# IP macht HTTP-Unfug
curl -X POST https://ha.hajo63.de (1000x)

# CrowdSec erkennt HTTP-DOS
docker compose exec crowdsec cscli decisions list
# IP: 1.2.3.4, Grund: http-dos, Dauer: 4h

# Firewall-Bouncer blockiert
sudo nft list set ip crowdsec crowdsec-blacklists
# elements = { 1.2.3.4 timeout 4h }

# Traefik-Bouncer blockiert
curl https://ha.hajo63.de -H "X-Forwarded-For: 1.2.3.4"
# 403 Forbidden

# Beide Bouncer aktiv
docker compose exec crowdsec cscli bouncers list
# firewall-bouncer   ✓  2s ago
# traefik-bouncer    ✓  2s ago
```

## 🔗 Weitere Informationen

- [CrowdSec Dokumentation](https://docs.crowdsec.net/)
- [Bouncer Konzept](https://docs.crowdsec.net/docs/concepts#bouncers)
- [LAPI (Local API)](https://docs.crowdsec.net/docs/local_api/intro)

---

**Made with Bob** 🤖

**Fazit**: Alle Bouncer arbeiten zusammen und teilen sich die gleichen Entscheidungen. Eine IP, die auf HTTP-Ebene Unfug treibt, wird auch in der Firewall geblockt!