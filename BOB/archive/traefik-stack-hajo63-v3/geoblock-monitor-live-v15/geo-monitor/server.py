#!/usr/bin/env python3
"""geoblock-monitor-live v15

v15 change request: Improve Direct-IP detection.

What is counted as a "Direct-IP Hit" now:
- IPv4 literals in RequestHost or RequestAddr (with or without port).
- IPv6 literals in RequestHost or RequestAddr (bracketed or not, with or without port).
- Requests where RequestHost is empty/missing but RequestAddr contains an IP literal.

Other features kept from v14:
- GeoIP fallback chain (GEO_URLS)
- Option A: count blocked events even when Geo lookup fails
- CrowdSec bouncer log ingestion via Docker socket
- Known-good log path for your setup: /logs/access.json (host ./logs/access.json mounted to /logs)
"""

import os, time, json, threading, re, socket, ipaddress
from collections import deque, Counter
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import urlopen, Request
from datetime import datetime

LOG = os.getenv('LOG_FILE', '/logs/access.json')
STATUS = set(s.strip() for s in os.getenv('BLOCK_STATUS', '403,451').split(',') if s.strip())
FULL_SCAN = os.getenv('FULL_SCAN', '1').lower() in ('1', 'true', 'yes')
SHOW_IPS = os.getenv('SHOW_IPS', 'true').lower() in ('1', 'true', 'yes')
COUNT_BLOCKS_WITHOUT_GEO = os.getenv('COUNT_BLOCKS_WITHOUT_GEO', 'true').lower() in ('1', 'true', 'yes')

GEO_URLS = [u.strip() for u in os.getenv(
    'GEO_URLS',
    'https://ipwho.is/{ip},http://ip-api.com/json/{ip}?fields=status,countryCode,lat,lon,message,https://ipinfo.io/{ip}/json,https://get.geojs.io/v1/ip/geo/{ip}.json'
).split(',') if u.strip()]
GEO_TIMEOUT = float(os.getenv('GEO_TIMEOUT', '3'))

# CrowdSec bouncer logs via Docker socket
DOCKER_SOCK = os.getenv('DOCKER_SOCK', '/var/run/docker.sock')
DOCKER_API = os.getenv('DOCKER_API_VERSION', '1.44')
BOUNCER_CONTAINER = os.getenv('BOUNCER_CONTAINER', 'traefik-bouncer')

# --- caches & event stores ---
# cache: ip -> (lat, lon, cc, provider)
cache = {}

blocked_events = deque()      # (ts, ip, lat, lon, cc, host, provider)
all_events = deque()          # (ts, ip, host)
direct_ip_events = deque()    # (ts, src_ip, target_host, ipver)  ipver in ('v4','v6')
crowdsec_events = deque()     # (ts, ip)

last_geo_error = ''


def parse_ts(rec):
    for k in ('StartUTC', 'StartLocal', 'time'):
        v = rec.get(k)
        if isinstance(v, str) and v:
            try:
                if v.endswith('Z'):
                    v = v.replace('Z', '+00:00')
                return datetime.fromisoformat(v).timestamp()
            except Exception:
                pass
    return time.time()


def _provider_name(url_tpl: str) -> str:
    if 'ipwho.is' in url_tpl:
        return 'ipwho.is'
    if 'ip-api.com' in url_tpl:
        return 'ip-api.com'
    if 'ipinfo.io' in url_tpl:
        return 'ipinfo.io'
    if 'geojs.io' in url_tpl:
        return 'geojs.io'
    return 'geo'


def _parse_geo_payload(data: dict):
    # Provider-specific fail signals
    if data.get('success') is False:
        return None
    if data.get('status') == 'fail':
        return None
    if data.get('bogon') is True:
        return None

    # ipinfo: loc = "lat,lon", country = "DE"
    if 'loc' in data and isinstance(data.get('loc'), str):
        try:
            lat_s, lon_s = data['loc'].split(',', 1)
            lat = float(lat_s.strip()); lon = float(lon_s.strip())
            cc = (data.get('country') or '??')
            if isinstance(cc, str) and len(cc) == 2:
                return lat, lon, cc
        except Exception:
            pass

    lat = data.get('latitude')
    if lat is None:
        lat = data.get('lat')
    lon = data.get('longitude')
    if lon is None:
        lon = data.get('lon')
    if lon is None:
        lon = data.get('lng')

    cc = (data.get('country_code') or data.get('countryCode') or None)
    if cc is None:
        c = data.get('country')
        if isinstance(c, dict):
            cc = c.get('code')
        elif isinstance(c, str) and len(c) == 2:
            cc = c

    if lat is None or lon is None:
        return None
    try:
        lat = float(lat); lon = float(lon)
    except Exception:
        return None

    cc = cc if (isinstance(cc, str) and cc) else '??'
    return lat, lon, cc


def geo_lookup(ip: str):
    """Return (lat, lon, cc, provider) or None.

    Uses a fallback chain (GEO_URLS). Caches results per IP.
    """
    global last_geo_error

    if ip in cache:
        return cache[ip]

    ua = os.getenv('GEO_USER_AGENT', 'Mozilla/5.0 (geoblock-monitor-live-v15)')

    for url_tpl in GEO_URLS:
        provider = _provider_name(url_tpl)
        url = url_tpl.format(ip=ip)
        try:
            req = Request(url, headers={'User-Agent': ua, 'Accept': 'application/json'})
            with urlopen(req, timeout=GEO_TIMEOUT) as r:
                raw = r.read().decode('utf-8', errors='ignore')
            data = json.loads(raw)
            parsed = _parse_geo_payload(data)
            if not parsed:
                msg = data.get('message') or data.get('reason') or data.get('error')
                last_geo_error = f"{provider}: parse-failed" + (f" ({msg})" if msg else '')
                continue
            lat, lon, cc = parsed
            cache[ip] = (lat, lon, cc, provider)
            return cache[ip]
        except Exception as e:
            last_geo_error = f"{provider}: {type(e).__name__}: {e}"
            continue

    return None


def prune(now=None):
    now = now or time.time()
    cutoff = now - 24 * 3600
    for dq in (blocked_events, all_events, direct_ip_events, crowdsec_events):
        while dq and dq[0][0] < cutoff:
            dq.popleft()


def _strip_port(host: str) -> str:
    """Strip :port from IPv4 or hostname, and strip [v6]:port to v6."""
    h = host.strip()
    if not h:
        return h
    # bracketed IPv6
    if h.startswith('['):
        # [v6] or [v6]:port
        if ']' in h:
            return h[1:h.index(']')]
        return h.strip('[]')
    # If it looks like IPv4:port
    if h.count(':') == 1 and '.' in h:
        return h.split(':', 1)[0]
    return h


def _is_ip_literal(s: str):
    """Return ('v4'|'v6', normalized_ip) if s is an IP literal (with optional port/brackets).
    Otherwise return (None, None).
    """
    if not s:
        return None, None
    raw = s.strip()
    # RequestAddr may be host:port; RequestHost usually no port but handle anyway.
    raw_no_port = _strip_port(raw)

    # IPv6 may be unbracketed with port is ambiguous; we only reliably parse unbracketed without port.
    # If there are multiple ':' and no brackets, assume it's pure IPv6 literal.
    candidate = raw_no_port
    try:
        ip = ipaddress.ip_address(candidate)
        return ('v4' if ip.version == 4 else 'v6'), str(ip)
    except Exception:
        return None, None


def ingest_line(line: str):
    try:
        rec = json.loads(line)
        ts = parse_ts(rec)

        src_ip = (rec.get('ClientHost') or (rec.get('ClientAddr', '').split(':')[0]) or '').strip()
        req_host = (rec.get('RequestHost') or '').strip()
        req_addr = (rec.get('RequestAddr') or '').strip()
        host = (req_host or req_addr).strip()

        if src_ip:
            all_events.append((ts, src_ip, host))

        # v15: direct IP hit detection (IPv4/IPv6 + port/brackets + empty host fallback)
        ipver, _ = _is_ip_literal(req_host)
        if not ipver:
            ipver, _ = _is_ip_literal(req_addr)
        if ipver:
            direct_ip_events.append((ts, src_ip or 'unknown', host, ipver))

        prune(ts)

        # blocked-only (status filter)
        st = str(rec.get('DownstreamStatus') or rec.get('OriginStatus') or rec.get('status') or '')
        if st not in STATUS:
            return
        if not src_ip:
            return

        g = geo_lookup(src_ip)
        if not g and not COUNT_BLOCKS_WITHOUT_GEO:
            return

        if g:
            lat, lon, cc, prov = g
            lat, lon = round(lat, 2), round(lon, 2)
        else:
            lat, lon, cc, prov = None, None, '??', None

        blocked_events.append((ts, src_ip, lat, lon, cc, host, prov))
        prune(ts)

    except Exception:
        return


def follow_traefik():
    last_msg = 0
    while not os.path.exists(LOG):
        now = time.time()
        if now - last_msg > 5:
            print(f"[geoblock-monitor] waiting for access log: {LOG}")
            last_msg = now
        time.sleep(1)

    print(f"[geoblock-monitor] reading access log: {LOG} (FULL_SCAN={FULL_SCAN})")
    with open(LOG, 'r', encoding='utf-8', errors='ignore') as f:
        if not FULL_SCAN:
            f.seek(0, 2)
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.2)
                continue
            line = line.strip()
            if not line:
                continue
            ingest_line(line)


def docker_http_get(path: str) -> bytes:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(DOCKER_SOCK)
    req = f"GET {path} HTTP/1.1\r\nHost: docker\r\nConnection: close\r\n\r\n"
    s.sendall(req.encode('utf-8'))
    buf = b""
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
    s.close()
    parts = buf.split(b"\r\n\r\n", 1)
    return parts[1] if len(parts) == 2 else b""


def resolve_container_id(name: str):
    try:
        body = docker_http_get(f"/v{DOCKER_API}/containers/json?all=1")
        arr = json.loads(body.decode('utf-8'))
        for c in arr:
            names = c.get('Names') or []
            if any(n.lstrip('/') == name for n in names):
                return c.get('Id')
    except Exception:
        return None
    return None


def follow_crowdsec():
    cid = None
    while cid is None:
        cid = resolve_container_id(BOUNCER_CONTAINER)
        if cid is None:
            time.sleep(2)

    since = int(time.time()) - 5
    while True:
        try:
            path = f"/v{DOCKER_API}/containers/{cid}/logs?stdout=1&stderr=1&since={since}&timestamps=1"
            data = docker_http_get(path)

            out_lines = []
            i = 0
            while i + 8 <= len(data) and data[i] in (1, 2, 3) and data[i+1:i+4] == b"\x00\x00\x00":
                size = int.from_bytes(data[i+4:i+8], 'big')
                i += 8
                out_lines.append(data[i:i+size])
                i += size

            text = (b"".join(out_lines) if out_lines else data).decode('utf-8', 'ignore')
            for line in text.splitlines():
                line = line.strip()
                if not line:
                    continue

                j = line
                if ' ' in line and len(line) > 30 and line[4] == '-' and 'T' in line[:30]:
                    pref, rest = line.split(' ', 1)
                    j = rest

                try:
                    rec = json.loads(j)
                except Exception:
                    continue

                if str(rec.get('status')) != '403':
                    continue
                ip = str(rec.get('ip', '')).strip()
                if not ip:
                    continue

                ts = time.time()
                crowdsec_events.append((ts, ip))
                prune(ts)

            since = int(time.time()) - 2
        except Exception:
            pass

        time.sleep(2)


def _top_ips(counter: Counter, n=10):
    items = counter.most_common(n)
    if not SHOW_IPS:
        return [('hidden', v) for _, v in items]
    out = []
    for ip, v in items:
        g = geo_lookup(ip)
        cc = g[2] if g else '??'
        out.append((f"{ip} ({cc})", v))
    return out


def compute():
    now = time.time(); prune(now)
    w10 = now - 600; w1h = now - 3600

    # BLOCKED
    b10 = b1h = 0
    countries24 = Counter(); hosts24 = Counter(); ips24 = Counter(); points = Counter(); provs24 = Counter()
    for ts, ip, lat, lon, cc, host, prov in blocked_events:
        if lat is not None and lon is not None:
            points[(lat, lon, cc)] += 1
        countries24[cc] += 1
        if host:
            hosts24[host] += 1
        ips24[ip] += 1
        if prov:
            provs24[prov] += 1
        if ts >= w1h: b1h += 1
        if ts >= w10: b10 += 1

    # ALL
    a10 = a1h = 0
    all_ips24 = Counter()
    for ts, ip, host in all_events:
        if ts >= w1h: a1h += 1
        if ts >= w10: a10 += 1
        all_ips24[ip] += 1

    # DIRECT IP HITS
    d10 = d1h = 0
    dir_src24 = Counter(); dir_tgt24 = Counter(); dir_ver24 = Counter()
    for ts, src, host, ipver in direct_ip_events:
        dir_src24[src] += 1
        dir_tgt24[host] += 1
        dir_ver24[ipver] += 1
        if ts >= w1h: d1h += 1
        if ts >= w10: d10 += 1

    # CROWDSEC
    c10 = c1h = 0
    cs_ips24 = Counter()
    for ts, ip in crowdsec_events:
        cs_ips24[ip] += 1
        if ts >= w1h: c1h += 1
        if ts >= w10: c10 += 1

    return {
        'countsBlocked': {'10m': b10, '1h': b1h, '24h': len(blocked_events)},
        'countsAll': {'10m': a10, '1h': a1h, '24h': len(all_events)},
        'countsDirectIP': {'10m': d10, '1h': d1h, '24h': len(direct_ip_events)},
        'countsCrowdSec': {'10m': c10, '1h': c1h, '24h': len(crowdsec_events)},
        'topCountries24h': countries24.most_common(10),
        'topHosts24h': hosts24.most_common(10),
        'topIPsBlocked24h': _top_ips(ips24),
        'topIPsAll24h': _top_ips(all_ips24),
        'topDirectIPSrc24h': _top_ips(dir_src24),
        'topDirectIPTargets24h': dir_tgt24.most_common(5),
        'topDirectIPVersions24h': dir_ver24.most_common(2),
        'topCrowdSecIPs24h': _top_ips(cs_ips24),
        'topGeoProviders24h': provs24.most_common(10),
        'points': [ {'lat': k[0], 'lon': k[1], 'cc': k[2], 'count': v} for k, v in points.items() ],
        'config': {
            'logFile': LOG,
            'blockStatus': sorted(list(STATUS)),
            'fullScan': FULL_SCAN,
            'countBlocksWithoutGeo': COUNT_BLOCKS_WITHOUT_GEO,
            'geoUrls': GEO_URLS,
            'geoTimeout': GEO_TIMEOUT,
            'lastGeoError': last_geo_error,
            'bouncerContainer': BOUNCER_CONTAINER,
            'directIPDetection': 'v15 (IPv4+IPv6 literals, with/without port/brackets, host-empty fallback)'
        }
    }


class H(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype='application/json'):
        b = body if isinstance(body, (bytes, bytearray)) else body.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path.startswith('/api/stats'):
            self._send(200, json.dumps(compute()))
            return
        if self.path.startswith('/api/points'):
            self._send(200, json.dumps(compute()['points']))
            return

        if self.path == '/' or self.path.startswith('/index.html'):
            p = os.path.join('/app/static', 'index.html')
        else:
            p = os.path.join('/app/static', self.path.lstrip('/'))
        if not os.path.isfile(p):
            self._send(404, 'not found', 'text/plain'); return
        ctype = 'text/plain'
        if p.endswith('.html'): ctype = 'text/html'
        elif p.endswith('.css'): ctype = 'text/css'
        elif p.endswith('.js'): ctype = 'application/javascript'
        with open(p, 'rb') as f:
            self._send(200, f.read(), ctype)


if __name__ == '__main__':
    threading.Thread(target=follow_traefik, daemon=True).start()
    threading.Thread(target=follow_crowdsec, daemon=True).start()
    port = int(os.getenv('PORT', '8090'))
    print(f"[geoblock-monitor] v15 serving on :{port}")
    HTTPServer(('', port), H).serve_forever()
