# Traefik Konfigurationsmethode: Entscheidungshilfe

## 🎯 Ihre Situation

Basierend auf Ihrer bestehenden Container-Infrastruktur:
- ✅ Sie nutzen bereits **Docker Labels** (WUD, Watchtower)
- ✅ Sie haben **Container-Standards** etabliert
- ✅ Sie verwalten **3 Services auf Pi4** (Home Assistant, Nextcloud, Pigallery2)
- ✅ Traefik auf Pi5 soll als **zentraler Reverse-Proxy** dienen

---

## 📊 Schnellvergleich

| Kriterium | Labels | File Provider | Hybrid |
|-----------|--------|---------------|--------|
| **Lernkurve** | ⭐⭐⭐⭐⭐ Einfach | ⭐⭐⭐ Mittel | ⭐⭐⭐⭐ Einfach-Mittel |
| **Wartbarkeit** | ⭐⭐⭐ Gut | ⭐⭐⭐⭐⭐ Sehr gut | ⭐⭐⭐⭐ Sehr gut |
| **Flexibilität** | ⭐⭐⭐ Gut | ⭐⭐⭐⭐⭐ Sehr gut | ⭐⭐⭐⭐⭐ Sehr gut |
| **Konsistenz mit BOB** | ⭐⭐⭐⭐⭐ Perfekt | ⭐⭐⭐ Mittel | ⭐⭐⭐⭐ Gut |
| **Für 3 Services** | ⭐⭐⭐⭐⭐ Ideal | ⭐⭐⭐ Überdimensioniert | ⭐⭐⭐⭐ Gut |
| **Wiederverwendbarkeit** | ⭐⭐ Begrenzt | ⭐⭐⭐⭐⭐ Exzellent | ⭐⭐⭐⭐⭐ Exzellent |

---

## 🏆 Empfehlung für Ihr Setup: **HYBRID**

### Warum Hybrid?

1. **Passt zu Ihren Container-Standards**
   - Sie nutzen bereits Labels für WUD/Watchtower
   - Konsistente Arbeitsweise über alle Container

2. **Optimal für 3 Services**
   - Nicht zu komplex (wie reiner File Provider)
   - Nicht zu eingeschränkt (wie reine Labels)

3. **Beste Balance**
   - Zentrale Middlewares (wiederverwendbar)
   - Service-Routing in Labels (übersichtlich)

4. **Zukunftssicher**
   - Einfach erweiterbar bei mehr Services
   - Flexibel für komplexe Anforderungen

---

## 🎨 Hybrid-Ansatz im Detail

### Was gehört wohin?

#### File Provider (`config/dynamic/middlewares.yml`)
**Zentrale, wiederverwendbare Komponenten:**

```yaml
http:
  middlewares:
    # Security Headers (für ALLE Services)
    secure-headers:
      headers:
        sslRedirect: true
        forceSTSHeader: true
        stsSeconds: 31536000
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "same-origin"
        customFrameOptionsValue: "SAMEORIGIN"
    
    # GeoIP Deutschland (für ALLE Services)
    geoip-de:
      plugin:
        geoblock:
          allowedCountries:
            - DE
          defaultAllow: false
    
    # Rate Limiting Profile: Standard
    rate-limit-standard:
      rateLimit:
        average: 100
        burst: 50
        period: 1s
    
    # Rate Limiting Profile: Streng (für Login-Seiten)
    rate-limit-strict:
      rateLimit:
        average: 10
        burst: 5
        period: 1s
    
    # Home Assistant spezifische Headers
    ha-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
          X-Forwarded-For: ""
    
    # Nextcloud spezifische Headers
    nc-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
        customResponseHeaders:
          X-Frame-Options: "SAMEORIGIN"
          X-Content-Type-Options: "nosniff"
```

**Vorteile:**
- ✅ Einmal definieren, überall nutzen
- ✅ Zentrale Wartung (z.B. Security Headers aktualisieren)
- ✅ Konsistente Sicherheitsrichtlinien

#### Docker Labels (`docker-compose.yml`)
**Service-spezifisches Routing:**

```yaml
services:
  # ============================================
  # Home Assistant Proxy (Pi4: 192.168.178.3:8123)
  # ============================================
  homeassistant-proxy:
    image: alpine:latest
    container_name: homeassistant-proxy
    command: tail -f /dev/null  # Dummy-Container
    
    networks:
      - proxy
    
    labels:
      # Traefik aktivieren
      - "traefik.enable=true"
      
      # Router-Konfiguration
      - "traefik.http.routers.homeassistant.rule=Host(`ha.hajo63.de`)"
      - "traefik.http.routers.homeassistant.entrypoints=websecure"
      - "traefik.http.routers.homeassistant.tls.certresolver=letsencrypt"
      
      # Backend auf Pi4
      - "traefik.http.services.homeassistant.loadbalancer.server.url=http://192.168.178.3:8123"
      
      # Middlewares (aus File Provider!)
      - "traefik.http.routers.homeassistant.middlewares=secure-headers@file,ha-headers@file,geoip-de@file,rate-limit-standard@file"
      
      # WUD Labels (Ihre Standards!)
      - "wud.watch=true"
      - "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"
      - "wud.display.name=Home Assistant Proxy"
      - "wud.display.icon=si:homeassistant"
  
  # ============================================
  # Nextcloud Proxy (Pi4: 192.168.178.3:8088)
  # ============================================
  nextcloud-proxy:
    image: alpine:latest
    container_name: nextcloud-proxy
    command: tail -f /dev/null
    
    networks:
      - proxy
    
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(`nc.hajo63.de`)"
      - "traefik.http.routers.nextcloud.entrypoints=websecure"
      - "traefik.http.routers.nextcloud.tls.certresolver=letsencrypt"
      - "traefik.http.services.nextcloud.loadbalancer.server.url=http://192.168.178.3:8088"
      
      # Nextcloud-spezifische Middlewares
      - "traefik.http.routers.nextcloud.middlewares=secure-headers@file,nc-headers@file,rate-limit-standard@file"
      
      # WUD Labels
      - "wud.watch=true"
      - "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"
      - "wud.display.name=Nextcloud Proxy"
      - "wud.display.icon=si:nextcloud"
  
  # ============================================
  # Pigallery2 Proxy (Pi4: 192.168.178.3:8001)
  # ============================================
  pigallery2-proxy:
    image: alpine:latest
    container_name: pigallery2-proxy
    command: tail -f /dev/null
    
    networks:
      - proxy
    
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pigallery2.rule=Host(`pg.hajo63.de`)"
      - "traefik.http.routers.pigallery2.entrypoints=websecure"
      - "traefik.http.routers.pigallery2.tls.certresolver=letsencrypt"
      - "traefik.http.services.pigallery2.loadbalancer.server.url=http://192.168.178.3:8001"
      
      # Standard Middlewares
      - "traefik.http.routers.pigallery2.middlewares=secure-headers@file,geoip-de@file,rate-limit-standard@file"
      
      # WUD Labels
      - "wud.watch=true"
      - "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"
      - "wud.display.name=Pigallery2 Proxy"
      - "wud.display.icon=si:image"

networks:
  proxy:
    external: true
```

**Vorteile:**
- ✅ Übersichtlich: Jeder Service in einem Block
- ✅ Konsistent mit Ihren Container-Standards
- ✅ Einfach zu erweitern (neuer Service = neuer Block)
- ✅ Nutzt zentrale Middlewares via `@file`

---

## 📁 Ordnerstruktur (Hybrid)

```
/home/hajo/docker-volumes/traefik/
├── docker-compose.yml              # Traefik + Proxy-Container (mit Labels)
├── .env                            # Secrets
│
├── config/
│   ├── traefik.yml                 # Hauptkonfiguration
│   └── dynamic/
│       └── middlewares.yml         # NUR Middlewares (wiederverwendbar)
│
├── letsencrypt/
│   └── acme.json
│
├── logs/
│   ├── access.log
│   └── error.log
│
└── scripts/
    ├── backup.sh
    └── update-geoip.sh
```

**Nur 2 Konfigurationsdateien:**
1. `traefik.yml` - Basis-Setup (Entrypoints, Provider, SSL)
2. `middlewares.yml` - Wiederverwendbare Middlewares

**Alles andere in docker-compose.yml!**

---

## 🔧 Konkrete Konfiguration

### 1. traefik.yml (Basis-Konfiguration)

```yaml
# ============================================
# Traefik v3 - Hauptkonfiguration
# ============================================

# API & Dashboard
api:
  dashboard: true
  insecure: false  # Nur über HTTPS

# Entrypoints
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

# Provider
providers:
  # Docker Provider (für Labels)
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: proxy
  
  # File Provider (für Middlewares)
  file:
    directory: /etc/traefik/dynamic
    watch: true

# SSL-Zertifikate
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web

# Logging
log:
  level: INFO
  filePath: /logs/traefik.log

accessLog:
  filePath: /logs/access.log
  bufferingSize: 100
```

### 2. dynamic/middlewares.yml (Wiederverwendbare Middlewares)

```yaml
# ============================================
# Traefik - Zentrale Middlewares
# ============================================

http:
  middlewares:
    # ============================================
    # Security Headers (für ALLE Services)
    # ============================================
    secure-headers:
      headers:
        sslRedirect: true
        forceSTSHeader: true
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "same-origin"
        customFrameOptionsValue: "SAMEORIGIN"
        customResponseHeaders:
          X-Robots-Tag: "noindex,nofollow,nosnippet,noarchive,notranslate,noimageindex"
    
    # ============================================
    # GeoIP Blocking (nur Deutschland)
    # ============================================
    geoip-de:
      plugin:
        geoblock:
          allowedCountries:
            - DE
          defaultAllow: false
          logAllowedRequests: false
          logApiRequests: true
    
    # ============================================
    # Rate Limiting Profile: Standard
    # ============================================
    rate-limit-standard:
      rateLimit:
        average: 100
        burst: 50
        period: 1s
    
    # ============================================
    # Rate Limiting Profile: Streng
    # ============================================
    rate-limit-strict:
      rateLimit:
        average: 10
        burst: 5
        period: 1s
    
    # ============================================
    # Home Assistant Headers
    # ============================================
    ha-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
          X-Forwarded-For: ""
    
    # ============================================
    # Nextcloud Headers
    # ============================================
    nc-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
        customResponseHeaders:
          X-Frame-Options: "SAMEORIGIN"
          X-Content-Type-Options: "nosniff"
          X-XSS-Protection: "1; mode=block"
          X-Robots-Tag: "noindex,nofollow"
```

### 3. docker-compose.yml (Traefik + Proxies)

```yaml
# ============================================
# Traefik Reverse Proxy + Service Proxies
# ============================================

services:
  # ============================================
  # Traefik Hauptservice
  # ============================================
  traefik:
    image: traefik:v3.6
    container_name: traefik
    restart: unless-stopped
    
    environment:
      - TZ=Europe/Berlin
    
    ports:
      - "80:80"
      - "443:443"
    
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./config/dynamic:/etc/traefik/dynamic:ro
      - ./letsencrypt:/letsencrypt:rw
      - ./logs:/logs:rw
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
    
    networks:
      - proxy
    
    labels:
      # Traefik Dashboard
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.hajo63.de`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.middlewares=dashboard-auth,secure-headers@file"
      
      # Dashboard Auth (htpasswd generieren: htpasswd -nb admin password)
      - "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$apr1$$..."
      
      # Watchtower
      - "com.centurylinklabs.watchtower.enable=true"
      
      # WUD
      - "wud.watch=true"
      - "wud.tag.include=^v?3\\.\\d+$$"
      - "wud.display.name=Traefik"
      - "wud.display.icon=si:traefikproxy"

  # ============================================
  # Home Assistant Proxy
  # ============================================
  homeassistant-proxy:
    image: alpine:latest
    container_name: homeassistant-proxy
    command: tail -f /dev/null
    restart: unless-stopped
    
    networks:
      - proxy
    
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.homeassistant.rule=Host(`ha.hajo63.de`)"
      - "traefik.http.routers.homeassistant.entrypoints=websecure"
      - "traefik.http.routers.homeassistant.tls.certresolver=letsencrypt"
      - "traefik.http.services.homeassistant.loadbalancer.server.url=http://192.168.178.3:8123"
      - "traefik.http.routers.homeassistant.middlewares=secure-headers@file,ha-headers@file,geoip-de@file,rate-limit-standard@file"
      
      # WUD
      - "wud.watch=true"
      - "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"
      - "wud.display.name=Home Assistant Proxy"
      - "wud.display.icon=si:homeassistant"

  # ============================================
  # Nextcloud Proxy
  # ============================================
  nextcloud-proxy:
    image: alpine:latest
    container_name: nextcloud-proxy
    command: tail -f /dev/null
    restart: unless-stopped
    
    networks:
      - proxy
    
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(`nc.hajo63.de`)"
      - "traefik.http.routers.nextcloud.entrypoints=websecure"
      - "traefik.http.routers.nextcloud.tls.certresolver=letsencrypt"
      - "traefik.http.services.nextcloud.loadbalancer.server.url=http://192.168.178.3:8088"
      - "traefik.http.routers.nextcloud.middlewares=secure-headers@file,nc-headers@file,rate-limit-standard@file"
      
      # WUD
      - "wud.watch=true"
      - "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"
      - "wud.display.name=Nextcloud Proxy"
      - "wud.display.icon=si:nextcloud"

  # ============================================
  # Pigallery2 Proxy
  # ============================================
  pigallery2-proxy:
    image: alpine:latest
    container_name: pigallery2-proxy
    command: tail -f /dev/null
    restart: unless-stopped
    
    networks:
      - proxy
    
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pigallery2.rule=Host(`pg.hajo63.de`)"
      - "traefik.http.routers.pigallery2.entrypoints=websecure"
      - "traefik.http.routers.pigallery2.tls.certresolver=letsencrypt"
      - "traefik.http.services.pigallery2.loadbalancer.server.url=http://192.168.178.3:8001"
      - "traefik.http.routers.pigallery2.middlewares=secure-headers@file,geoip-de@file,rate-limit-standard@file"
      
      # WUD
      - "wud.watch=true"
      - "wud.tag.include=^\\d+\\.\\d+\\.\\d+$$"
      - "wud.display.name=Pigallery2 Proxy"
      - "wud.display.icon=si:image"

networks:
  proxy:
    name: proxy
    driver: bridge

# Made with Bob
```

---

## ✅ Vorteile des Hybrid-Ansatzes für Sie

### 1. Konsistenz mit BOB-Standards
```yaml
# Ihre gewohnte Arbeitsweise:
labels:
  - "wud.watch=true"                    # ✅ Wie bei allen Containern
  - "traefik.enable=true"               # ✅ Ähnlich wie WUD
  - "traefik.http.routers.xxx..."       # ✅ Alles in Labels
```

### 2. Einfache Wartung
```yaml
# Neuer Service hinzufügen? Einfach neuen Block:
nextcloud-proxy:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.nextcloud..."
    # Nutzt automatisch zentrale Middlewares!
```

### 3. Zentrale Sicherheit
```yaml
# Security Headers ändern? Nur 1 Datei:
# config/dynamic/middlewares.yml
secure-headers:
  headers:
    stsSeconds: 63072000  # Auf 2 Jahre erhöhen
# Gilt automatisch für ALLE Services!
```

### 4. Übersichtlichkeit
```
docker-compose.yml:     ~200 Zeilen (alles Routing)
middlewares.yml:        ~80 Zeilen (wiederverwendbar)
traefik.yml:            ~40 Zeilen (Basis-Setup)
─────────────────────────────────────────────────
Gesamt:                 ~320 Zeilen (sehr überschaubar!)
```

---

## 🚫 Warum NICHT die anderen Varianten?

### ❌ Reine Labels
**Problem für Sie:**
```yaml
# Middlewares müssen für JEDEN Service wiederholt werden:
homeassistant-proxy:
  labels:
    - "traefik.http.middlewares.ha-secure.headers.sslRedirect=true"
    - "traefik.http.middlewares.ha-secure.headers.forceSTSHeader=true"
    - "traefik.http.middlewares.ha-secure.headers.stsSeconds=31536000"
    # ... 20 weitere Zeilen ...
    
nextcloud-proxy:
  labels:
    - "traefik.http.middlewares.nc-secure.headers.sslRedirect=true"
    - "traefik.http.middlewares.nc-secure.headers.forceSTSHeader=true"
    # ... wieder 20 Zeilen ...
```
**Resultat:** 
- ❌ Viel Duplikation
- ❌ Fehleranfällig
- ❌ Schwer zu warten

### ❌ Reiner File Provider
**Problem für Sie:**
```
config/dynamic/
├── middlewares.yml     # Middlewares
├── routers.yml         # Alle Routen
├── services.yml        # Alle Backend-Services
└── tls.yml             # TLS-Konfiguration
```
**Resultat:**
- ❌ 4+ Dateien zu pflegen
- ❌ Routing getrennt von Service-Definition
- ❌ Nicht konsistent mit Ihren Container-Standards
- ❌ Überdimensioniert für 3 Services

---

## 📈 Skalierbarkeit

### Neuen Service hinzufügen (z.B. PhotoPrism)

**Mit Hybrid (empfohlen):**
```yaml
# In docker-compose.yml einfach hinzufügen:
photoprism-proxy:
  image: alpine:latest
  container_name: photoprism-proxy
  command: tail -f /dev/null
  networks:
    - proxy
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.photoprism.rule=Host(`photos.hajo63.de`)"
    - "traefik.http.routers.photoprism.entrypoints=websecure"
    - "traefik.http.routers.photoprism.tls.certresolver=letsencrypt"
    - "traefik.http.services.photoprism.loadbalancer.server.url=http://192.168.178.3:2342"
    - "traefik.http.routers.photoprism.middlewares=secure-headers@file,geoip-de@file,rate-limit-standard@file"
    - "wud.watch=true"
    - "wud.display.name=PhotoPrism Proxy"
```
**Fertig!** Nutzt automatisch alle zentralen Middlewares.

---

## 🎯 Finale Empfehlung

### Für Ihr Setup: **HYBRID-Ansatz**

**Begründung:**
1. ✅ **Konsistent** mit Ihren Container-Standards (Labels)
2. ✅ **Optimal** für 3-5 Services
3. ✅ **Wartbar** durch zentrale Middlewares
4. ✅ **Übersichtlich** - alles in docker-compose.yml
5. ✅ **Erweiterbar** - neue Services in 10 Zeilen
6. ✅ **Zukunftssicher** - kann bei Bedarf erweitert werden

**Dateien:**
- `docker-compose.yml` - Traefik + alle Proxy-Container (mit Labels)
- `config/traefik.yml` - Basis-Konfiguration (~40 Zeilen)
- `config/dynamic/middlewares.yml` - Wiederverwendbare Middlewares (~80 Zeilen)

**Gesamt:** ~320 Zeilen, sehr überschaubar!

---

## 📚 Nächste Schritte

1. ✅ Entscheidung getroffen: **Hybrid**
2. [ ] Ordnerstruktur auf Pi5 erstellen
3. [ ] `traefik.yml` erstellen
4. [ ] `middlewares.yml` erstellen
5. [ ] `docker-compose.yml` mit Traefik + Proxies erstellen
6. [ ] `.env` mit Secrets erstellen
7. [ ] Testen mit einem Service (z.B. Home Assistant)
8. [ ] Weitere Services hinzufügen

---

**Erstellt**: 2026-02-25  
**Für**: Raspberry Pi 5 Traefik-Setup  
**Empfehlung**: Hybrid-Ansatz (Labels + File Provider für Middlewares)