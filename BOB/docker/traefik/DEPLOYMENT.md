# 🚀 Traefik Deployment - rsync Befehle

## ⚠️ WICHTIG: Nginx auf Pi4 muss auch aktualisiert werden!

Wenn Home Assistant Konfiguration geändert wird, muss auch die Nginx-Konfiguration auf Pi4 aktualisiert werden:

```bash
# Nginx-Konfiguration auf Pi4 aktualisieren
rsync -avz ~/Privat/RaspberryPi/BOB/Pi4/docker/nginx/etc/nginx.conf \
  hajo@192.168.178.3:/home/hajo/docker-volumes/nginx/etc/

# Nginx auf Pi4 neu laden
ssh hajo@192.168.178.3 "docker exec nginx nginx -s reload"
```

## Deployment von Mac zu Pi5

### Komplettes Traefik-Verzeichnis synchronisieren

```bash
# Gesamtes Traefik-Verzeichnis (ohne logs und certs)
rsync -avz --exclude='logs/' --exclude='certs/' \
  ~/Privat/RaspberryPi/BOB/docker/traefik/ \
  hajo@192.168.178.55:/home/hajo/docker/traefik/
```

### Einzelne Konfigurationsdateien

```bash
# Statische Konfiguration
rsync -avz ~/Privat/RaspberryPi/BOB/docker/traefik/config/traefik.yml \
  hajo@192.168.178.55:/home/hajo/docker/traefik/config/

# Dynamische Konfigurationen (alle)
rsync -avz ~/Privat/RaspberryPi/BOB/docker/traefik/config/dynamic/ \
  hajo@192.168.178.55:/home/hajo/docker/traefik/config/dynamic/

# Nur Home Assistant Konfiguration
rsync -avz ~/Privat/RaspberryPi/BOB/docker/traefik/config/dynamic/homeassistant.yml \
  hajo@192.168.178.55:/home/hajo/docker/traefik/config/dynamic/

# Nur Routes Konfiguration
rsync -avz ~/Privat/RaspberryPi/BOB/docker/traefik/config/dynamic/routes.yml \
  hajo@192.168.178.55:/home/hajo/docker/traefik/config/dynamic/

# Middlewares
rsync -avz ~/Privat/RaspberryPi/BOB/docker/traefik/config/dynamic/middlewares.yml \
  hajo@192.168.178.55:/home/hajo/docker/traefik/config/dynamic/

# TLS Konfiguration
rsync -avz ~/Privat/RaspberryPi/BOB/docker/traefik/config/dynamic/tls.yml \
  hajo@192.168.178.55:/home/hajo/docker/traefik/config/dynamic/

# Nextcloud Konfiguration
rsync -avz ~/Privat/RaspberryPi/BOB/docker/traefik/config/dynamic/nextcloud.yml \
  hajo@192.168.178.55:/home/hajo/docker/traefik/config/dynamic/

# docker-compose.yml
rsync -avz ~/Privat/RaspberryPi/BOB/docker/traefik/docker-compose.yml \
  hajo@192.168.178.55:/home/hajo/docker/traefik/
```

### Nach dem Deployment

```bash
# SSH auf Pi5
ssh hajo@192.168.178.55

# Traefik neu starten (lädt neue Konfiguration)
cd /home/hajo/docker/traefik
docker compose down
docker compose up -d

# Logs prüfen
docker compose logs -f traefik

# Konfiguration testen
curl -I https://ha.hajo63.de
curl -I https://ha.hajo62.duckdns.org
```

## Schnell-Deployment (Home Assistant Update)

```bash
# Home Assistant Konfiguration aktualisieren und Traefik neu laden
rsync -avz ~/Privat/RaspberryPi/BOB/docker/traefik/config/dynamic/homeassistant.yml \
  hajo@192.168.178.55:/home/hajo/docker/traefik/config/dynamic/ && \
ssh hajo@192.168.178.55 "cd /home/hajo/docker/traefik && docker compose restart traefik"
```

## Backup vor Deployment

```bash
# Backup der aktuellen Konfiguration auf Pi5 erstellen
ssh hajo@192.168.178.55 "cd /home/hajo/docker/traefik && \
  tar -czf ~/backups/traefik-config-$(date +%Y%m%d-%H%M%S).tar.gz config/"
```

## Verzeichnisstruktur auf Pi5

```
/home/hajo/docker/traefik/
├── docker-compose.yml
├── config/
│   ├── traefik.yml                    # Statische Konfiguration
│   └── dynamic/
│       ├── homeassistant.yml          # Home Assistant Routes (NEU)
│       ├── routes.yml                 # Allgemeine Routes
│       ├── middlewares.yml            # Middlewares
│       ├── nextcloud.yml              # Nextcloud Routes
│       └── tls.yml                    # TLS Konfiguration
├── certs/                             # SSL-Zertifikate (NICHT überschreiben!)
├── logs/                              # Logs (NICHT überschreiben!)
└── scripts/
    ├── backup.sh
    └── setup.sh
```

## Wichtige Hinweise

1. **Zertifikate**: Die `certs/` werden NICHT synchronisiert (existieren nur auf Pi5)
2. **Logs**: Die `logs/` werden NICHT synchronisiert (existieren nur auf Pi5)
3. **File Provider**: Traefik lädt Änderungen automatisch (watch: true)
4. **Restart**: Bei Änderungen an `traefik.yml` ist ein Restart erforderlich
5. **Dynamic Config**: Änderungen in `config/dynamic/` werden automatisch geladen

## Troubleshooting

```bash
# Traefik Dashboard prüfen (nur im LAN)
open http://192.168.178.55:8092

# Konfiguration validieren
ssh hajo@192.168.178.55 "cd /home/hajo/docker/traefik && \
  docker compose config"

# Traefik Logs live anzeigen
ssh hajo@192.168.178.55 "cd /home/hajo/docker/traefik && \
  docker compose logs -f --tail=100 traefik"
```

---

*Made with Bob* 🤖