Rolle & Arbeitsweise
- Du agierst als erfahrener Linux-/Docker-/Traefik-/CrowdSec‑Admin.
- Nicht von vorne erklären, kein ForwardAuth vorschlagen.
- Schrittweise vorgehen, immer nur einen nächsten Schritt.
- Bestehende Dateien nur erweitern/anpassen, nichts neu erfinden.
- Fokus: Traefik v3.6 + CrowdSec LAPI Container + CrowdSec‑Bouncer‑Plugin (kein Bouncer‑Container), saubere Logs, kein “alles 403” bei kurzem LAPI‑Ausfall.

Ziel
Stabiles CrowdSec‑Setup mit:
- Traefik v3.x
- CrowdSec LAPI als Container
- Traefik CrowdSec Plugin (github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin)
- Fallback so, dass bei LAPI‑Ausfall nicht alles 403 wird
- Nachvollziehbare Blocks / saubere Logs

Umgebung (Docker Compose)
- Netz: traefik_proxy
- Traefik: traefik:v3.6
  - Ports: 80:80, 443:443, Dashboard 127.0.0.1:8080
  - Volumes:
    - /var/run/docker.sock:ro
    - ./data/traefik.yml:/etc/traefik/traefik.yml:ro
    - ./data/dynamic_conf.yml:/etc/traefik/dynamic_conf.yml:ro
    - ./data/certs:/certs:ro
    - ./logs:/var/log/traefik
  - ENV enthält: CROWDSEC_TRAEFIK_BOUNCER_API_KEY (aus .env)
- CrowdSec: crowdsecurity/crowdsec:latest
  - LAPI erreichbar als crowdsec:8080 im gleichen Docker‑Netz
  - Volumes:
    - ./logs:/var/log/traefik:ro (Traefik Access‑Logs)
    - ./crowdsec/acquis.yaml:/etc/crowdsec/acquis.yaml:ro
    - crowdsec-data:/var/lib/crowdsec/data
    - crowdsec-config:/etc/crowdsec

Traefik (static) traefik.yml — relevante Auszüge
experimental:
  plugins:
    geoblock:
      moduleName: github.com/PascalMinder/geoblock
      version: v0.3.3
    crowdsec-bouncer:
      moduleName: github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin
      version: v1.5.0

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false
  file:
    filename: /etc/traefik/dynamic_conf.yml
    watch: true

accessLog:
  format: json
  filePath: /var/log/traefik/access.json

Traefik (dynamic) dynamic_conf.yml — relevante Auszüge
Router/Services/Middlewares sind definiert; crowdsec‑Middleware wie folgt (korrekt funktionierend):

http:
  routers:
    ha:
      rule: "Host(`ha.hajo63.de`) || Host(`ha.hajo62.duckdns.org`)"
      entryPoints: ["websecure"]
      service: pi4
      middlewares:
        - geoblock-de
        - crowdsec
        - secure-headers
      tls:
        options: tls-modern
    nc:
      # analog zu ha …
    pg:
      # analog zu ha …

  services:
    pi4:
      loadBalancer:
        passHostHeader: true
        servers:
          - url: "http://192.168.178.3:80"

  middlewares:
    geoblock-de:
      plugin:
        geoblock:
          blackListMode: false
          allowLocalRequests: true
          allowUnknownCountries: true
          api: "https://get.geojs.io/v1/ip/country/{ip}"
          apiTimeoutMs: 1500
          cacheSize: 50
          forceMonthlyUpdate: true
          countries:
            - DE

    crowdsec:
      plugin:
        crowdsec-bouncer:
          crowdsecMode: "live"
          crowdsecLapiScheme: "http"
          crowdsecLapiHost: "crowdsec:8080"
          crowdsecLapiKey: '{{ env "CROWDSEC_TRAEFIK_BOUNCER_API_KEY" }}'
          # (Optionale Feinschliff-Optionen werden erst später wieder aktiviert)

    secure-headers:
      headers:
        stsSeconds: 63072000
        stsIncludeSubdomains: true
        stsPreload: true
        frameDeny: true
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: strict-origin-when-cross-origin

tls:
  options:
    tls-modern:
      minVersion: VersionTLS12
      sniStrict: true
      cipherSuites:
        - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305

Bouncer‑Key / LAPI
- Bouncer via cscli bouncers add traefik-bouncer erzeugt.
- .env: CROWDSEC_TRAEFIK_BOUNCER_API_KEY=<alphanumerischer Key ohne Sonderzeichen>
- In Traefik‑API sichtbar:
  GET /api/http/middlewares/crowdsec@file zeigt:
  {
    "plugin": {
      "crowdsec-bouncer": {
        "crowdsecLapiHost": "crowdsec:8080",
        "crowdsecLapiKey": "****",
        "crowdsecLapiScheme": "http",
        "crowdsecMode": "live"
      }
    },
    "type": "crowdsec-bouncer",
    "status": "enabled",
    "usedBy": ["ha@file","nc@file","pg@file"]
  }

Bisheriger Befund
- Plugin wird geladen (Traefik‑Logs bestätigen).
- Middleware crowdsec@file geladen und Parameter korrekt (Host+Port, Scheme, Key, Mode).
- Bouncer in cscli bouncers list: Valid ✔️, aber Last API pull war zuletzt leer.
- Wir haben dann korrekte SNI‑Tests begonnen (per curl --resolve), um echte Router‑Treffer zu erzeugen und den Pull zu triggern.

Offener Punkt / Aktueller Fokus
- Nachweis „Last API pull“ in cscli bouncers list bleibt aus.
- Nächste Untersuchung: CrowdSec‑LAPI‑Logs während eines echten Router‑Treffers prüfen (Filter auf bouncer|lapi|decision|auth|api) und ggf. Traefik‑Access‑Logs gegenprüfen, ob Requests wirklich den Router treffen (421 vermeiden, SNI/Host korrekt).

Arbeitsregeln
1. Nur einen nächsten Schritt liefern.
2. Keine Neu‑Erfindungen, nur bestehende Dateien anpassen.
3. Kein ForwardAuth.
4. Erst Beobachten/Verifizieren, dann Ändern.
5. Ziel: Stabile Plugin‑Abfragen, kein 403‑Sturm bei LAPI‑Hiccups, saubere Logs.

Als nächstes (Startpunkt für die Fortsetzung)
- Einen echten Request an ha.hajo63.de über Traefik schicken mit korrektem SNI:
  curl -k -I --resolve ha.hajo63.de:443:127.0.0.1 https://ha.hajo63.de/
- Parallel CrowdSec‑Logs beobachten:
  docker logs -f crowdsec | grep -iE 'bouncer|lapi|decision|auth|api'
- Danach:
  docker exec -it crowdsec cscli bouncers list
- Erwartung: Log‑Treffer (auth/decisions) und Last API pull aktualisiert.

Bitte dort weitermachen und nur einen nächsten Schritt anbieten.