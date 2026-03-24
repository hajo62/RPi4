Kurz: Router waren disabled, weil GeoBlock Plugin eine API-URL erwartet (Fehler: "no api uri given").
Diese Version nutzt die Plugin-Doku-Parameter `api` + `countries` (DE) und aktiviert `allowLocalRequests`.

1) Zertifikate in data/certs ablegen.
2) logs/access.log anlegen: `touch logs/access.log`
3) .env erstellen und API-Key setzen (CrowdSec bouncer).
4) Start: `docker compose up -d`

Test Router:
`curl -s http://127.0.0.1:8080/api/http/routers | grep -E 'ha@file|nc@file'`

Wenn 403: GeoBlock oder CrowdSec. Für GeoBlock-Logs: `docker logs traefik | grep -i geoblock`
