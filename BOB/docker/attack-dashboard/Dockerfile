FROM python:3.12-slim

LABEL maintainer="Made with Bob"
LABEL description="Attack Dashboard – Traefik + CrowdSec + nftables Angriffs-Übersicht"

WORKDIR /app

# Keine externen Python-Abhängigkeiten – nur stdlib
COPY server.py /app/server.py
COPY static/   /app/static/

# Weltkarte (Natural Earth, vereinfacht, ~500 KB) herunterladen
# Quelle: holtzy/D3-graph-gallery (Public Domain)
# Fallback: Karte zeigt nur Gitterlinien wenn Download fehlschlägt
RUN python3 -c "\
import urllib.request, os; \
url = 'https://raw.githubusercontent.com/holtzy/D3-graph-gallery/master/DATA/world.geojson'; \
print('Lade Weltkarte herunter...'); \
urllib.request.urlretrieve(url, '/app/static/world.geojson'); \
print('Weltkarte geladen:', os.path.getsize('/app/static/world.geojson'), 'Bytes') \
" || echo "WARNUNG: Weltkarte konnte nicht geladen werden – Karte zeigt nur Gitterlinien"

# Nicht als root laufen
RUN useradd -r -u 1000 -s /sbin/nologin dashboard
USER dashboard

EXPOSE 8095

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8095/api/stats', timeout=4)" || exit 1

CMD ["python3", "-u", "/app/server.py"]