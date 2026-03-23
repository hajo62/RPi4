#!/usr/bin/env python3
"""
Attack Dashboard Server
=======================
Aggregiert Angriffsdaten aus:
  1. Traefik Access Log (JSON) → HTTP-Angriffe, GeoIP-Blocks, Direct-IP-Hits
  2. CrowdSec LAPI (REST API) → aktive Decisions (geblockte IPs)
  3. nftables (via Host-Befehl) → Firewall-Drop-Statistiken
  4. /var/log/auth.log → SSH Brute-Force

Stellt bereit:
  GET /           → Dashboard HTML
  GET /api/stats  → JSON mit allen Metriken
  GET /api/events → JSON Stream der letzten Events (SSE)
"""

import os, time, json, threading, re, socket, ipaddress, subprocess, gzip
from collections import deque, Counter, defaultdict
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import urlopen, Request
from datetime import datetime, timezone

# ─── Konfiguration ────────────────────────────────────────────────────────────
TRAEFIK_LOG   = os.getenv('TRAEFIK_LOG',   '/logs/traefik/access.json')
AUTH_LOG      = os.getenv('AUTH_LOG',      '/logs/auth.log')
CROWDSEC_URL  = os.getenv('CROWDSEC_URL',  'http://crowdsec:8080')
CROWDSEC_KEY  = os.getenv('CROWDSEC_KEY',  '')
FULL_SCAN     = os.getenv('FULL_SCAN',     '1').lower() in ('1','true','yes')
SHOW_IPS      = os.getenv('SHOW_IPS',      'true').lower() in ('1','true','yes')
PORT          = int(os.getenv('PORT',      '8095'))
WINDOW_H      = 24   # Stunden Datenfenster

GEO_URLS = [u.strip() for u in os.getenv(
    'GEO_URLS',
    'https://ipwho.is/{ip},'
    'http://ip-api.com/json/{ip}?fields=status,countryCode,country,lat,lon,message,'
    'https://ipinfo.io/{ip}/json,'
    'https://get.geojs.io/v1/ip/geo/{ip}.json'
).split(',') if u.strip()]
GEO_TIMEOUT = float(os.getenv('GEO_TIMEOUT', '3'))

# ─── Globale Stores ───────────────────────────────────────────────────────────
geo_cache: dict = {}          # ip → (lat, lon, cc, country_name, provider)
geo_lock  = threading.Lock()

# Event-Queues (ts, ...)
http_blocked   = deque()   # (ts, ip, lat, lon, cc, host, status, path, method)
http_all       = deque()   # (ts, ip, host, status)
direct_ip_hits = deque()   # (ts, src_ip, target, ipver)
ssh_attempts   = deque()   # (ts, ip, user)
crowdsec_bans  = deque()   # (ts, ip, reason, duration, origin)
# Aktuell aktive Decisions (Snapshot, wird alle 30s aktualisiert)
# ip → (reason, duration, origin) – NUR für IP-Liste, NICHT für Zeitfenster-Zählung
active_decisions_snapshot: dict = {}

# FULL_SCAN Fortschritt (für Lade-Anzeige im Dashboard)
scan_progress: dict = {
    'scanning': False,   # True während FULL_SCAN läuft
    'scanned':  0,       # Zeilen eingelesen (letzte 24h)
    'skipped':  0,       # Zeilen übersprungen (älter als 24h)
    'total':    0,       # Geschätzte Gesamtzahl (aus Datei-Größe)
}

# Live-Feed (letzte 200 Events für den Event-Stream)
live_feed: deque = deque(maxlen=200)
live_lock  = threading.Lock()

last_errors: dict = {}

# ─── Geo-Lookup ───────────────────────────────────────────────────────────────
def _provider_name(url: str) -> str:
    for p in ('ipwho.is','ip-api.com','ipinfo.io','geojs.io'):
        if p in url: return p
    return 'geo'

def _parse_geo(data: dict):
    if data.get('success') is False or data.get('status') == 'fail' or data.get('bogon'):
        return None
    # ipinfo: loc="lat,lon", country="DE"
    if 'loc' in data and isinstance(data.get('loc'), str):
        try:
            lat, lon = map(float, data['loc'].split(',', 1))
            cc = (data.get('country') or '??')[:2]
            name = data.get('org', '') or ''
            return lat, lon, cc, data.get('city','') or ''
        except Exception:
            pass
    lat = data.get('latitude') or data.get('lat')
    lon = data.get('longitude') or data.get('lon') or data.get('lng')
    cc  = (data.get('country_code') or data.get('countryCode') or
           (data.get('country') if isinstance(data.get('country'), str) and len(data.get('country','')) == 2 else None) or '??')
    country_name = ''
    if isinstance(data.get('country'), str) and len(data['country']) > 2:
        country_name = data['country']
    elif data.get('country_name'):
        country_name = data['country_name']
    if lat is None or lon is None:
        return None
    try:
        return float(lat), float(lon), str(cc)[:2], country_name
    except Exception:
        return None

def geo_lookup(ip: str):
    """Gibt (lat, lon, cc, country_name, provider) zurück oder None."""
    with geo_lock:
        if ip in geo_cache:
            return geo_cache[ip]
    ua = 'Mozilla/5.0 (attack-dashboard/1.0)'
    for url_tpl in GEO_URLS:
        provider = _provider_name(url_tpl)
        try:
            req = Request(url_tpl.format(ip=ip),
                          headers={'User-Agent': ua, 'Accept': 'application/json'})
            with urlopen(req, timeout=GEO_TIMEOUT) as r:
                data = json.loads(r.read().decode('utf-8', errors='ignore'))
            parsed = _parse_geo(data)
            if not parsed:
                last_errors['geo'] = f"{provider}: parse-failed"
                continue
            lat, lon, cc, cname = parsed
            result = (round(lat,2), round(lon,2), cc, cname, provider)
            with geo_lock:
                geo_cache[ip] = result
            return result
        except Exception as e:
            last_errors['geo'] = f"{provider}: {type(e).__name__}: {e}"
    return None

# ─── Hilfsfunktionen ──────────────────────────────────────────────────────────
def _strip_port(host: str) -> str:
    h = host.strip()
    if h.startswith('['):
        return h[1:h.index(']')] if ']' in h else h.strip('[]')
    if h.count(':') == 1 and '.' in h:
        return h.split(':',1)[0]
    return h

def _is_ip_literal(s: str):
    if not s: return None, None
    try:
        ip = ipaddress.ip_address(_strip_port(s.strip()))
        return ('v4' if ip.version == 4 else 'v6'), str(ip)
    except Exception:
        return None, None

def _is_private(ip_str: str) -> bool:
    """Gibt True zurück wenn die IP privat/lokal/intern ist (RFC1918, Loopback, Link-Local, Docker)."""
    try:
        ip = ipaddress.ip_address(ip_str)
        return ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved
    except Exception:
        return False

def _parse_ts(rec: dict) -> float:
    for k in ('StartUTC','StartLocal','time'):
        v = rec.get(k)
        if isinstance(v, str) and v:
            try:
                return datetime.fromisoformat(v.replace('Z','+00:00')).timestamp()
            except Exception:
                pass
    return time.time()

def prune(now=None):
    """
    Entfernt alte Einträge aus den deques.
    Verwendet 8 Tage (192h) als Cutoff, damit 7-Tage-Ansicht funktioniert.
    """
    now = now or time.time()
    cutoff = now - 192 * 3600  # 8 Tage (7d + 1d Puffer)
    for dq in (http_blocked, http_all, direct_ip_hits, ssh_attempts, crowdsec_bans):
        while dq and dq[0][0] < cutoff:
            dq.popleft()

def _add_live(event_type: str, data: dict):
    with live_lock:
        live_feed.append({
            'ts': time.time(),
            'type': event_type,
            **data
        })

# ─── Traefik Log Ingestion ────────────────────────────────────────────────────
BLOCK_STATUS = set(s.strip() for s in os.getenv('BLOCK_STATUS','403,451').split(',') if s.strip())

def ingest_traefik_line(line: str, skip_geo: bool = False):
    """
    Verarbeitet eine Traefik-Log-Zeile.
    skip_geo=True: Kein Geo-Lookup (für initialen FULL_SCAN – spart Zeit).
                   Geo-Daten werden beim nächsten Live-Event nachgeladen.
    """
    try:
        rec  = json.loads(line)
        ts   = _parse_ts(rec)
        src  = (rec.get('ClientHost') or rec.get('ClientAddr','').split(':')[0] or '').strip()
        host = (rec.get('RequestHost') or rec.get('RequestAddr') or '').strip()
        st   = str(rec.get('DownstreamStatus') or rec.get('OriginStatus') or rec.get('status') or '')
        path = str(rec.get('RequestPath') or '')
        meth = str(rec.get('RequestMethod') or 'GET')

        if src:
            http_all.append((ts, src, host, st))

        # Direct-IP detection
        ipver, _ = _is_ip_literal(host)
        if ipver:
            direct_ip_hits.append((ts, src or 'unknown', host, ipver))
            if not skip_geo:
                _add_live('direct_ip', {'ip': src, 'target': host, 'ipver': ipver})

        prune(ts)

        if st not in BLOCK_STATUS:
            return
        if not src:
            return
        # Interne IPs markieren (nicht filtern – Nutzer will wissen warum geblockt)
        is_internal = _is_private(src)

        if skip_geo:
            # Beim initialen Scan: kein Geo-Lookup, Platzhalter verwenden
            lat, lon, cc, cname = None, None, '??', ''
        else:
            g = geo_lookup(src)
            if g:
                lat, lon, cc, cname, prov = g
            else:
                lat, lon, cc, cname, prov = None, None, '??', '', None

        http_blocked.append((ts, src, lat, lon, cc, host, st, path, meth))
        if not skip_geo:
            _add_live('http_block', {
                'ip': src if SHOW_IPS else '***',
                'cc': cc, 'country': cname,
                'host': host, 'status': st, 'path': path[:80], 'method': meth,
                'internal': is_internal,
            })
        prune(ts)
    except Exception:
        pass

def _find_rotated_logs(base_path: str) -> list:
    """
    Findet rotierte Log-Dateien in beiden Formaten:
      1. Nummeriert: access.json.1, access.json.2.gz (Standard logrotate)
      2. Datiert: access.json-20260323, access.json-20260323.gz (logrotate mit dateext)
    Gibt Liste sortiert nach Alter zurück (neueste zuerst).
    """
    import glob
    dir_path = os.path.dirname(base_path)
    base_name = os.path.basename(base_path)
    
    # Suche nach beiden Formaten
    # Format 1: access.json.1, access.json.2.gz
    pattern1 = os.path.join(dir_path, f"{base_name}.[0-9]*")
    # Format 2: access.json-20260323, access.json-20260323.gz
    pattern2 = os.path.join(dir_path, f"{base_name}-[0-9]*")
    
    rotated = glob.glob(pattern1) + glob.glob(pattern2)
    
    # Sortiere nach Datei-Änderungszeit (neueste zuerst)
    # Das funktioniert für beide Formate und ist robuster als Namens-Parsing
    try:
        rotated.sort(key=lambda p: os.path.getmtime(p), reverse=True)
    except Exception:
        # Fallback: alphabetisch sortieren (funktioniert gut für Datumsformat)
        rotated.sort(reverse=True)
    
    return rotated

def _read_log_file(path: str, cutoff: float, skip_geo: bool = True):
    """
    Liest eine Log-Datei (plain oder .gz) und ingestiert Zeilen.
    Gibt (scanned, skipped) zurück.
    """
    scanned = 0
    skipped = 0
    
    try:
        # Automatisch .gz erkennen und dekomprimieren
        if path.endswith('.gz'):
            opener = lambda: gzip.open(path, 'rt', encoding='utf-8', errors='ignore')
        else:
            opener = lambda: open(path, 'r', encoding='utf-8', errors='ignore')
        
        with opener() as f:
            for raw_line in f:
                raw_line = raw_line.strip()
                if not raw_line:
                    continue
                # Schneller Timestamp-Check vor dem vollen Parse
                try:
                    rec = json.loads(raw_line)
                    ts  = _parse_ts(rec)
                    if ts < cutoff:
                        skipped += 1
                        continue
                except Exception:
                    continue
                ingest_traefik_line(raw_line, skip_geo=skip_geo)
                scanned += 1
    except Exception as e:
        print(f"[attack-dashboard] Fehler beim Lesen von {path}: {e}")
    
    return scanned, skipped

def follow_traefik():
    import os
    last_msg = 0
    while not os.path.exists(TRAEFIK_LOG):
        now = time.time()
        if now - last_msg > 10:
            print(f"[attack-dashboard] Warte auf Traefik-Log: {TRAEFIK_LOG}")
            last_msg = now
        time.sleep(2)

    cutoff = time.time() - 192 * 3600  # Letzte 8 Tage (für 7d-Ansicht + Puffer)

    print(f"[attack-dashboard] Lese Traefik-Log: {TRAEFIK_LOG} (FULL_SCAN={FULL_SCAN})")
    
    if not FULL_SCAN:
        # Kein FULL_SCAN: nur neue Zeilen ab jetzt
        with open(TRAEFIK_LOG, 'r', encoding='utf-8', errors='ignore') as f:
            f.seek(0, 2)  # Springe ans Ende
            while True:
                line = f.readline()
                if not line:
                    time.sleep(0.3)
                    continue
                line = line.strip()
                if line:
                    ingest_traefik_line(line, skip_geo=False)
    else:
        # FULL_SCAN: rotierte Dateien + aktuelle Datei lesen
        rotated_logs = _find_rotated_logs(TRAEFIK_LOG)
        all_logs = rotated_logs + [TRAEFIK_LOG]
        
        # Geschätzte Zeilenzahl aus allen Dateien
        try:
            total_size = sum(os.path.getsize(p) for p in all_logs if os.path.exists(p))
            estimated_lines = max(1, total_size // 1100)
        except Exception:
            estimated_lines = 0

        scan_progress['scanning'] = True
        scan_progress['scanned']  = 0
        scan_progress['skipped']  = 0
        scan_progress['total']    = estimated_lines

        total_scanned = 0
        total_skipped = 0
        
        # Lese rotierte Dateien zuerst (älteste zuerst)
        for log_path in all_logs:
            if not os.path.exists(log_path):
                continue
            
            is_current = (log_path == TRAEFIK_LOG)
            print(f"[attack-dashboard] Lese {'aktuelle' if is_current else 'rotierte'} Datei: {os.path.basename(log_path)}")
            
            scanned, skipped = _read_log_file(log_path, cutoff, skip_geo=True)
            total_scanned += scanned
            total_skipped += skipped
            
            scan_progress['scanned'] = total_scanned
            scan_progress['skipped'] = total_skipped
            
            if scanned > 0:
                print(f"[attack-dashboard]   → {scanned} Zeilen eingelesen, {skipped} übersprungen")

        scan_progress['scanning'] = False
        print(f"[attack-dashboard] FULL_SCAN abgeschlossen: {total_scanned} Zeilen (letzte 24h) aus {len(all_logs)} Datei(en), {total_skipped} ältere übersprungen")
        
        # Ab hier: Live-Modus (nur aktuelle Datei, neue Zeilen mit Geo-Lookup)
        with open(TRAEFIK_LOG, 'r', encoding='utf-8', errors='ignore') as f:
            f.seek(0, 2)  # Springe ans Ende
            while True:
                line = f.readline()
                if not line:
                    time.sleep(0.3)
                    continue
                line = line.strip()
                if line:
                    ingest_traefik_line(line, skip_geo=False)

# ─── SSH Log Ingestion ────────────────────────────────────────────────────────
# Patterns für auth.log
_SSH_FAIL_RE = re.compile(
    r'(?:Failed password|Invalid user|authentication failure).*?(?:from|rhost=)\s*([\d\.a-fA-F:]+)'
    r'(?:\s+port\s+\d+)?(?:\s+for\s+(?:invalid user\s+)?(\S+))?'
)
_SSH_ACCEPT_RE = re.compile(r'Accepted \S+ for (\S+) from ([\d\.a-fA-F:]+)')

def ingest_auth_line(line: str):
    ts = time.time()
    m = _SSH_FAIL_RE.search(line)
    if m:
        ip   = m.group(1) or 'unknown'
        user = m.group(2) or 'unknown'
        ssh_attempts.append((ts, ip, user))
        _add_live('ssh_fail', {
            'ip': ip if SHOW_IPS else '***',
            'user': user
        })
        prune(ts)

def follow_auth():
    if not os.path.exists(AUTH_LOG):
        print(f"[attack-dashboard] auth.log nicht gefunden: {AUTH_LOG} – SSH-Monitoring deaktiviert")
        return
    print(f"[attack-dashboard] Lese auth.log: {AUTH_LOG}")
    with open(AUTH_LOG, 'r', encoding='utf-8', errors='ignore') as f:
        f.seek(0, 2)  # Nur neue Einträge
        while True:
            line = f.readline()
            if not line:
                time.sleep(1)
                continue
            ingest_auth_line(line)

# ─── CrowdSec API Polling ─────────────────────────────────────────────────────
def _cs_get(path: str) -> list:
    """HTTP GET gegen CrowdSec LAPI, gibt geparste JSON-Liste zurück."""
    req = Request(
        f"{CROWDSEC_URL}{path}",
        headers={'X-Api-Key': CROWDSEC_KEY, 'Accept': 'application/json'}
    )
    with urlopen(req, timeout=10) as r:
        data = json.loads(r.read().decode('utf-8'))
    return data if isinstance(data, list) else []

def _parse_cs_ts(ts_str: str) -> float:
    """CrowdSec-Timestamp (RFC3339/ISO8601) → Unix-Timestamp."""
    if not ts_str:
        return time.time()
    try:
        return datetime.fromisoformat(ts_str.replace('Z', '+00:00')).timestamp()
    except Exception:
        return time.time()

def poll_crowdsec():
    """
    Pollt CrowdSec LAPI alle 30s.

    Strategie (Bouncer-Key hat NUR Zugriff auf /v1/decisions, NICHT /v1/alerts):
      /v1/decisions → Primäre und einzige Quelle.
                      Liefert aktuell aktive Bans mit id, scenario, origin, duration.

    Zeitfenster-Zählung (10min / 1h / 24h):
      - /v1/decisions hat KEINEN Erstellungszeitpunkt.
      - Wir merken uns den Zeitpunkt, wann wir eine Decision-ID zum ERSTEN MAL sehen.
      - known_decision_first_seen: id → ts (Unix-Timestamp beim ersten Sehen)
      - Diese Map wächst nur – wird NICHT geleert (Duplikat-Schutz).
      - prune() entfernt Einträge aus crowdsec_bans die älter als 24h sind.
      - Einträge die aus known_decision_first_seen verschwinden (Decision abgelaufen)
        werden beim nächsten prune() automatisch aus crowdsec_bans entfernt.

    Ohne API-Key: Thread beendet sich sofort, alle CrowdSec-Widgets bleiben leer.
    Mit API-Key:  Befüllt KPI 'CrowdSec Bans', 'Top CrowdSec IPs',
                  'CrowdSec Szenarien' und den Live-Feed.
    """
    if not CROWDSEC_KEY:
        print("[attack-dashboard] CROWDSEC_KEY nicht gesetzt – CrowdSec-Widgets bleiben leer")
        return
    print(f"[attack-dashboard] CrowdSec-Polling aktiv: {CROWDSEC_URL}")

    # id → Unix-Timestamp beim ersten Sehen (wächst nur, wird nicht geleert)
    known_decision_first_seen: dict = {}

    while True:
        # ── Decisions (einzige verfügbare Quelle für Bouncer-Keys) ──
        try:
            decisions = _cs_get('/v1/decisions?limit=500')
            now = time.time()

            # Aktuelle aktive IPs für Snapshot merken
            active_decisions_snapshot.clear()

            for d in decisions:
                ip     = d.get('value', '')
                did    = d.get('id')
                origin = d.get('origin', 'crowdsec')
                reason = d.get('scenario', '') or d.get('reason', '') or d.get('type', origin)
                dur    = d.get('duration', '')
                if not ip:
                    continue

                # Snapshot für "aktiv jetzt"-Anzeige (alle Origins)
                active_decisions_snapshot[ip] = (reason, dur, origin)

                # Zeitfenster-Zählung: nur beim ERSTEN Sehen dieser Decision-ID
                # UND nur lokale Erkennungen (origin="crowdsec"), NICHT CAPI-Blocklist
                # CAPI-Einträge sind Community-Listen, keine eigenen Erkennungen
                if did not in known_decision_first_seen:
                    known_decision_first_seen[did] = now
                    if origin.lower() not in ('capi', 'lists', 'list'):
                        crowdsec_bans.append((now, ip, reason, dur, origin))
                        _add_live('crowdsec_ban', {
                            'ip':       ip if SHOW_IPS else '***',
                            'reason':   reason,
                            'duration': dur,
                            'origin':   origin
                        })

            prune(now)

            # known_decision_first_seen aufräumen: IDs die nicht mehr aktiv sind
            # und deren Timestamp älter als 25h ist, können entfernt werden
            cutoff = now - (WINDOW_H + 1) * 3600
            stale = [k for k, v in known_decision_first_seen.items() if v < cutoff]
            for k in stale:
                del known_decision_first_seen[k]

        except Exception as e:
            last_errors['crowdsec_decisions'] = str(e)

        time.sleep(30)

# ─── Geo-Cache Prefill (Background) ──────────────────────────────────────────
def _patch_http_blocked_geo():
    """
    Aktualisiert http_blocked-Einträge mit lat=None mit Geo-Daten aus dem Cache.
    Wird nach dem Geo-Prefill aufgerufen.
    """
    patched = 0
    # deque ist nicht direkt editierbar → neue Liste bauen und ersetzen
    entries = list(http_blocked)
    new_entries = []
    for entry in entries:
        ts, ip, lat, lon, cc, host, st, path, meth = entry
        if lat is None:
            with geo_lock:
                g = geo_cache.get(ip)
            if g:
                lat, lon, cc = g[0], g[1], g[2]
                patched += 1
        new_entries.append((ts, ip, lat, lon, cc, host, st, path, meth))
    # Deque leeren und neu befüllen
    http_blocked.clear()
    http_blocked.extend(new_entries)
    if patched:
        print(f"[attack-dashboard] Geo-Patch: {patched} Einträge in http_blocked aktualisiert")

def _geo_prefill_worker():
    """
    Befüllt den Geo-Cache für die häufigsten IPs im Hintergrund.
    Erste Runde: sofort nach FULL_SCAN (wartet bis scanning=False).
    Danach: alle 120s, max. 30 neue IPs pro Runde.
    Blockiert NICHT den Request-Handler.
    """
    # Warten bis FULL_SCAN abgeschlossen (oder kein FULL_SCAN aktiv)
    while scan_progress.get('scanning', False):
        time.sleep(1)
    # Kurze Pause damit der Server schon Requests beantworten kann
    time.sleep(3)

    while True:
        # Alle bekannten IPs aus allen Queues sammeln (nach Häufigkeit)
        ip_freq: Counter = Counter()
        for ts, ip, *_ in list(http_blocked):
            ip_freq[ip] += 2   # http_blocked höher gewichten
        for ts, ip, *_ in list(direct_ip_hits):
            ip_freq[ip] += 1
        for ts, ip, *_ in list(crowdsec_bans):
            ip_freq[ip] += 1
        # Nur IPs die noch nicht im Cache sind, häufigste zuerst
        with geo_lock:
            missing = [ip for ip, _ in ip_freq.most_common() if ip not in geo_cache]
        if missing:
            print(f"[attack-dashboard] Geo-Prefill: {len(missing)} IPs zu laden …")
        # Max 30 pro Runde (Rate-Limiting)
        for ip in missing[:30]:
            try:
                geo_lookup(ip)
                time.sleep(0.3)  # Kurze Pause zwischen Lookups
            except Exception:
                pass
        # Nach dem Laden: http_blocked mit Geo-Daten patchen
        _patch_http_blocked_geo()
        # Nächste Runde in 120s
        time.sleep(120)

# ─── Compute Stats ────────────────────────────────────────────────────────────
def _top_ips(counter: Counter, n=10):
    """Gibt Top-IPs mit Geo-Daten zurück – NUR aus Cache, kein neuer Lookup."""
    items = counter.most_common(n)
    if not SHOW_IPS:
        return [('***', v, '??', '', False) for _, v in items]
    out = []
    for ip, v in items:
        with geo_lock:
            g = geo_cache.get(ip)
        cc       = g[2] if g else '??'
        cname    = g[3] if g else ''
        internal = _is_private(ip)
        out.append((ip, v, cc, cname, internal))
    return out

def compute(window_hours: int = 24) -> dict:
    """
    Berechnet Statistiken für das angegebene Zeitfenster.
    
    Args:
        window_hours: Zeitfenster in Stunden (24 oder 168 für 7 Tage)
    """
    now = time.time()
    # NICHT prune() aufrufen! Das würde Daten löschen.
    # Stattdessen filtern wir beim Zählen.
    
    # Dynamische Sub-Zeitfenster je nach Hauptfenster
    if window_hours == 168:  # 7d-Ansicht
        w_sub1 = now - 86400   # 1 Tag
        w_sub2 = now - 3600    # 1 Stunde
        sub1_key = '1d'
        sub2_key = '1h'
    else:  # 24h-Ansicht
        w_sub1 = now - 3600    # 1 Stunde
        w_sub2 = now - 600     # 10 Minuten
        sub1_key = '1h'
        sub2_key = '10m'
    
    w6h  = now - 21600
    w_total = now - (window_hours * 3600)  # Dynamisches Gesamtfenster

    # ── HTTP Blocked ──
    b_sub1 = b_sub2 = b6h = b_total = 0
    cc_cnt        = Counter()   # HTTP blocked
    cc_cnt_direct = Counter()   # Direct-IP
    cc_cnt_cs     = Counter()   # CrowdSec bans
    host_cnt  = Counter()
    ip_cnt    = Counter()
    path_cnt  = Counter()
    meth_cnt  = Counter()
    st_cnt    = Counter()
    map_pts        = Counter()   # HTTP blocked
    map_pts_direct = Counter()   # Direct-IP hits
    map_pts_cs     = Counter()   # CrowdSec bans

    for ts, ip, lat, lon, cc, host, st, path, meth in http_blocked:
        if ts < w_total:
            continue  # Zu alt für aktuelles Zeitfenster
        b_total += 1
        cc_cnt[cc] += 1
        if host: host_cnt[host] += 1
        ip_cnt[ip] += 1
        if path: path_cnt[path[:60]] += 1
        meth_cnt[meth] += 1
        st_cnt[st] += 1
        if lat is not None:
            map_pts[(round(lat,1), round(lon,1), cc)] += 1
        if ts >= w_sub1: b_sub1 += 1
        if ts >= w_sub2: b_sub2 += 1
        if ts >= w6h:    b6h    += 1

    # ── HTTP All ──
    a_sub1 = a_sub2 = a_total = 0
    all_ip_cnt = Counter()
    for ts, ip, host, st in http_all:
        if ts < w_total:
            continue
        a_total += 1
        all_ip_cnt[ip] += 1
        if ts >= w_sub1: a_sub1 += 1
        if ts >= w_sub2: a_sub2 += 1

    # ── Direct IP ──
    d_sub1 = d_sub2 = d_total = 0
    dir_src = Counter(); dir_ver = Counter()
    for ts, src, tgt, ipver in direct_ip_hits:
        if ts < w_total:
            continue
        d_total += 1
        dir_src[src] += 1
        dir_ver[ipver] += 1
        if ts >= w_sub1: d_sub1 += 1
        if ts >= w_sub2: d_sub2 += 1
        # Geo für Karte + Länder
        with geo_lock:
            g = geo_cache.get(src)
        if g:
            map_pts_direct[(round(g[0],1), round(g[1],1), g[2])] += 1
            cc_cnt_direct[g[2]] += 1

    # ── SSH ──
    s_sub1 = s_sub2 = s_total = 0
    ssh_ip_cnt   = Counter()
    ssh_usr_cnt  = Counter()
    for ts, ip, user in ssh_attempts:
        if ts < w_total:
            continue
        s_total += 1
        ssh_ip_cnt[ip] += 1
        ssh_usr_cnt[user] += 1
        if ts >= w_sub1: s_sub1 += 1
        if ts >= w_sub2: s_sub2 += 1

    # ── CrowdSec ──
    # crowdsec_bans: nur lokale Erkennungen (origin != CAPI) mit ts=first_seen
    # active_decisions_snapshot: alle aktiven Bans (inkl. CAPI) für "aktiv gesamt"
    cs_sub1 = cs_sub2 = cs_total = 0
    cs_ip_cnt     = Counter()
    cs_reason_cnt = Counter()
    cs_origin_cnt = Counter()
    capi_cnt = 0
    local_cnt = 0
    for ts, ip, reason, dur, origin in crowdsec_bans:
        if ts < w_total:
            continue
        cs_total += 1
        # Zeitfenster-Zählung (nur lokale Erkennungen)
        if ts >= w_sub1: cs_sub1 += 1
        if ts >= w_sub2: cs_sub2 += 1
        # Szenarien und Origins
        if reason: cs_reason_cnt[reason] += 1
        if origin: cs_origin_cnt[origin] += 1
        cs_ip_cnt[ip] += 1
        # Geo für Karte + Länder
        with geo_lock:
            g = geo_cache.get(ip)
        if g:
            map_pts_cs[(round(g[0],1), round(g[1],1), g[2])] += 1
            cc_cnt_cs[g[2]] += 1

    # CAPI vs. lokal aus aktivem Snapshot
    for ip, (reason, dur, origin) in active_decisions_snapshot.items():
        if origin.lower() in ('capi', 'lists', 'list'):
            capi_cnt += 1
        else:
            local_cnt += 1

    # ── Live Feed ──
    with live_lock:
        feed = list(live_feed)[-50:]

    return {
        'ts': now,
        'countsHttpBlocked':  {sub2_key: b_sub2, sub1_key: b_sub1, '6h': b6h, '24h': b_total},
        'countsHttpAll':      {sub2_key: a_sub2, sub1_key: a_sub1, '24h': a_total},
        'countsDirectIP':     {sub2_key: d_sub2, sub1_key: d_sub1, '24h': d_total},
        'countsSsh':          {sub2_key: s_sub2, sub1_key: s_sub1, '24h': s_total},
        'countsCrowdSec':     {sub2_key: cs_sub2, sub1_key: cs_sub1, '24h': cs_total,
                               'active': len(active_decisions_snapshot),
                               'active_local': local_cnt, 'active_capi': capi_cnt},
        'topCountries':       cc_cnt.most_common(15),
        'topCountriesDirect': cc_cnt_direct.most_common(15),
        'topCountriesCS':     cc_cnt_cs.most_common(15),
        'topCountriesAll':    (cc_cnt + cc_cnt_direct + cc_cnt_cs).most_common(15),
        'topHosts':           host_cnt.most_common(10),
        'topPaths':           path_cnt.most_common(10),
        'topMethods':         meth_cnt.most_common(6),
        'topStatusCodes':     st_cnt.most_common(8),
        'topIPsBlocked':      _top_ips(ip_cnt),
        'topIPsAll':          _top_ips(all_ip_cnt, 5),
        'topSshIPs':          _top_ips(ssh_ip_cnt),
        'topSshUsers':        ssh_usr_cnt.most_common(10),
        'topCrowdSecIPs':     _top_ips(cs_ip_cnt),
        'topCrowdSecReasons': cs_reason_cnt.most_common(10),
        'topCrowdSecOrigins': cs_origin_cnt.most_common(5),
        'topDirectIPSrc':     _top_ips(dir_src, 10),
        'topDirectIPVer':     dir_ver.most_common(2),

        'mapPoints': [
            {'lat': k[0], 'lon': k[1], 'cc': k[2], 'count': v, 'type': 'http'}
            for k, v in map_pts.items()
        ] + [
            {'lat': k[0], 'lon': k[1], 'cc': k[2], 'count': v, 'type': 'direct'}
            for k, v in map_pts_direct.items()
        ] + [
            {'lat': k[0], 'lon': k[1], 'cc': k[2], 'count': v, 'type': 'cs'}
            for k, v in map_pts_cs.items()
        ],

        'liveFeed': feed,

        'scanProgress': dict(scan_progress),

        'config': {
            'traefikLog':   TRAEFIK_LOG,
            'authLog':      AUTH_LOG,
            'crowdsecUrl':  CROWDSEC_URL,
            'crowdsecKey':  '***' if CROWDSEC_KEY else '(nicht gesetzt)',
            'blockStatus':  sorted(list(BLOCK_STATUS)),
            'fullScan':     FULL_SCAN,
            'showIPs':      SHOW_IPS,
            'windowHours':  window_hours,  # Dynamisch: 24 oder 168
            'lastErrors':   last_errors,
        }
    }

# ─── HTTP Server ──────────────────────────────────────────────────────────────
STATIC_DIR = os.path.join(os.path.dirname(__file__), 'static')

def _ensure_world_geojson():
    """Lädt world.geojson herunter falls nicht vorhanden (z.B. nach Volume-Mount)."""
    fp = os.path.join(STATIC_DIR, 'world.geojson')
    if os.path.isfile(fp) and os.path.getsize(fp) > 10000:
        return  # Bereits vorhanden
    url = 'https://raw.githubusercontent.com/holtzy/D3-graph-gallery/master/DATA/world.geojson'
    print(f"[attack-dashboard] Lade world.geojson herunter: {url}")
    try:
        req = Request(url, headers={'User-Agent': 'attack-dashboard/1.0'})
        with urlopen(req, timeout=30) as r:
            data = r.read()
        os.makedirs(STATIC_DIR, exist_ok=True)
        with open(fp, 'wb') as f:
            f.write(data)
        print(f"[attack-dashboard] world.geojson geladen: {len(data)} Bytes")
    except Exception as e:
        print(f"[attack-dashboard] WARNUNG: world.geojson konnte nicht geladen werden: {e}")
        print("[attack-dashboard] Weltkarte zeigt nur Gitterlinien")

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):  # noqa: A002
        pass  # Kein Access-Log-Spam

    def _send(self, code: int, body, ctype='application/json'):
        b = body if isinstance(body, (bytes, bytearray)) else body.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        from urllib.parse import urlparse, parse_qs
        parsed = urlparse(self.path)
        p = parsed.path
        query = parse_qs(parsed.query)

        if p == '/api/stats':
            # Optional: window-Parameter (24 oder 168 für 7d)
            window_param = query.get('window', ['24'])[0]
            try:
                window_hours = int(window_param)
                if window_hours not in (24, 168):
                    window_hours = 24
            except (ValueError, TypeError):
                window_hours = 24
            self._send(200, json.dumps(compute(window_hours=window_hours)))
            return

        if p == '/api/debug/crowdsec':
            # Zeigt Rohdaten von CrowdSec LAPI für Diagnose
            now = time.time()
            out = {
                'crowdsec_key_set': bool(CROWDSEC_KEY),
                'crowdsec_url': CROWDSEC_URL,
                'crowdsec_bans_count': len(crowdsec_bans),
                'active_decisions_count': len(active_decisions_snapshot),
                'last_errors': last_errors,
                'crowdsec_bans_sample': [
                    {
                        'ts': t,
                        'ts_human': datetime.fromtimestamp(t).isoformat(),
                        'age_minutes': round((now - t) / 60, 1),
                        'ip': ip, 'reason': r, 'dur': d, 'origin': o
                    }
                    for t, ip, r, d, o in list(crowdsec_bans)[-20:]
                ],
                'active_decisions_sample': [
                    {'ip': ip, 'reason': v[0], 'dur': v[1], 'origin': v[2]}
                    for ip, v in list(active_decisions_snapshot.items())[:20]
                ],
            }
            # Direkt CrowdSec LAPI abfragen (live)
            if CROWDSEC_KEY:
                try:
                    dec_raw = _cs_get('/v1/decisions?limit=5')
                    out['decisions_live_sample'] = dec_raw[:3]
                    out['decisions_live_count'] = len(dec_raw)
                except Exception as e:
                    out['decisions_live_error'] = str(e)
            self._send(200, json.dumps(out, indent=2, default=str))
            return

        if p == '/api/world.geojson':
            fp = os.path.join(STATIC_DIR, 'world.geojson')
            exists = os.path.isfile(fp)
            readable = False
            if exists:
                try:
                    with open(fp, 'rb') as f:
                        data = f.read()
                    self._send(200, data, 'application/json')
                    return
                except Exception as e:
                    last_errors['world_geojson'] = str(e)
                    print(f"[attack-dashboard] world.geojson Lesefehler: {e}")
                    self._send(500, json.dumps({'error': str(e)}), 'application/json')
                    return
            # Datei fehlt – versuche sie jetzt herunterzuladen
            print(f"[attack-dashboard] world.geojson nicht gefunden: {fp}")
            print(f"[attack-dashboard] STATIC_DIR={STATIC_DIR}, exists={os.path.isdir(STATIC_DIR)}")
            try:
                contents = os.listdir(STATIC_DIR)
                print(f"[attack-dashboard] static/ Inhalt: {contents}")
            except Exception as e:
                print(f"[attack-dashboard] static/ nicht lesbar: {e}")
            threading.Thread(target=_ensure_world_geojson, daemon=True).start()
            self._send(404, '{}', 'application/json')
            return

        if p == '/api/live':
            # Server-Sent Events
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            last_idx = 0
            try:
                while True:
                    with live_lock:
                        feed = list(live_feed)
                    new = feed[last_idx:]
                    last_idx = len(feed)
                    for ev in new:
                        data = json.dumps(ev)
                        self.wfile.write(f"data: {data}\n\n".encode('utf-8'))
                    self.wfile.flush()
                    time.sleep(1)
            except Exception:
                return

        # Static files
        if p in ('/', '/index.html'):
            fp = os.path.join(STATIC_DIR, 'index.html')
        else:
            fp = os.path.join(STATIC_DIR, p.lstrip('/'))

        if not os.path.isfile(fp):
            self._send(404, 'not found', 'text/plain')
            return

        ext_map = {'.html':'text/html','.css':'text/css','.js':'application/javascript',
                   '.json':'application/json','.svg':'image/svg+xml','.png':'image/png'}
        ext  = os.path.splitext(fp)[1]
        ctype = ext_map.get(ext, 'text/plain')
        with open(fp, 'rb') as f:
            self._send(200, f.read(), ctype)


if __name__ == '__main__':
    print(f"[attack-dashboard] Starte v1.0 auf Port {PORT}")
    # world.geojson im Hintergrund laden – blockiert den Server-Start nicht
    threading.Thread(target=_ensure_world_geojson,  daemon=True).start()
    threading.Thread(target=follow_traefik,          daemon=True).start()
    threading.Thread(target=follow_auth,             daemon=True).start()
    threading.Thread(target=poll_crowdsec,           daemon=True).start()
    threading.Thread(target=_geo_prefill_worker,     daemon=True).start()
    HTTPServer(('', PORT), Handler).serve_forever()

# Made with Bob
