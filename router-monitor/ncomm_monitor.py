#!/usr/bin/env python3
"""
NCOMM Router Intrusion Monitor
===============================
Scans the local network for connected devices using nmap, compares against
a whitelist of known MACs, logs intruders, and serves a JSON HTTP API
that Grafana can query for live dashboards.

Usage:
    sudo python3 ncomm_monitor.py                  # scan + API server (default)
    sudo python3 ncomm_monitor.py --scan-only       # single scan, no server
    sudo python3 ncomm_monitor.py --api-only        # API server only (no scanning)
    sudo python3 ncomm_monitor.py --port 8199       # custom API port

Requires: nmap (installed via brew), sudo for OS fingerprinting.
"""

import argparse
import json
import logging
import os
import re
import signal
import sqlite3
import subprocess
import sys
import threading
import time
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "monitor_config.json"
DB_PATH = BASE_DIR / "logs" / "ncomm_monitor.sqlite"
OUI_CACHE_PATH = BASE_DIR / "logs" / "oui_cache.json"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger("ncomm-monitor")

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def load_config() -> dict:
    with open(CONFIG_PATH) as f:
        return json.load(f)

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

def init_db(db: sqlite3.Connection):
    db.executescript("""
        CREATE TABLE IF NOT EXISTS scans (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            ts          TEXT NOT NULL,
            duration_s  REAL,
            hosts_up    INTEGER
        );

        CREATE TABLE IF NOT EXISTS devices (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_id     INTEGER NOT NULL REFERENCES scans(id),
            ip          TEXT NOT NULL,
            mac         TEXT,
            vendor      TEXT,
            hostname    TEXT,
            os_guess    TEXT,
            open_ports  TEXT,
            is_known    INTEGER NOT NULL DEFAULT 0,
            device_name TEXT,
            ts          TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS alerts (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_id     INTEGER REFERENCES scans(id),
            ts          TEXT NOT NULL,
            severity    TEXT NOT NULL,
            mac         TEXT,
            ip          TEXT,
            message     TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_devices_mac ON devices(mac);
        CREATE INDEX IF NOT EXISTS idx_devices_ts ON devices(ts);
        CREATE INDEX IF NOT EXISTS idx_alerts_ts ON alerts(ts);
    """)
    db.commit()

def get_db() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    init_db(conn)
    return conn

# ---------------------------------------------------------------------------
# MAC Vendor Lookup (OSINT)
# ---------------------------------------------------------------------------

_oui_cache: dict = {}

def _load_oui_cache():
    global _oui_cache
    if OUI_CACHE_PATH.exists():
        try:
            _oui_cache = json.loads(OUI_CACHE_PATH.read_text())
        except Exception:
            _oui_cache = {}

def _save_oui_cache():
    try:
        OUI_CACHE_PATH.write_text(json.dumps(_oui_cache, indent=2))
    except Exception:
        pass

def lookup_mac_vendor(mac: str) -> str:
    """Resolve MAC to vendor via macvendors.com API (rate-limited, cached)."""
    if not mac:
        return ""
    prefix = mac.replace(":", "").replace("-", "")[:6].upper()
    if prefix in _oui_cache:
        return _oui_cache[prefix]
    try:
        url = f"https://api.macvendors.com/{mac}"
        req = urllib.request.Request(url, headers={"User-Agent": "NCOMM-Monitor/1.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            vendor = resp.read().decode().strip()
    except Exception:
        vendor = ""
    _oui_cache[prefix] = vendor
    _save_oui_cache()
    time.sleep(1.1)  # respect rate limit (1 req/sec free tier)
    return vendor

# ---------------------------------------------------------------------------
# Nmap Scanner
# ---------------------------------------------------------------------------

def run_nmap_scan(subnet: str, flags: str) -> ET.Element:
    """Run nmap and return parsed XML output."""
    effective_flags = flags.split()
    if os.geteuid() != 0 and "-O" in effective_flags:
        effective_flags = [flag for flag in effective_flags if flag != "-O"]
        log.warning("Running without root; dropping -O from nmap flags for compatibility")
    cmd = ["nmap"] + effective_flags + ["-oX", "-", subnet]
    log.info("Running: %s", " ".join(cmd))
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    if result.returncode not in (0, 1):  # 1 = some hosts down, OK
        log.error("nmap error: %s", result.stderr)
    return ET.fromstring(result.stdout)

def parse_nmap_hosts(xml_root: ET.Element) -> list[dict]:
    """Extract host records from nmap XML."""
    hosts = []
    for host_el in xml_root.findall("host"):
        if host_el.find("status").get("state") != "up":
            continue
        rec = {"ip": "", "mac": "", "vendor": "", "hostname": "", "os_guess": "", "open_ports": []}

        for addr in host_el.findall("address"):
            if addr.get("addrtype") == "ipv4":
                rec["ip"] = addr.get("addr", "")
            elif addr.get("addrtype") == "mac":
                rec["mac"] = addr.get("addr", "").lower().replace("-", ":")
                rec["vendor"] = addr.get("vendor", "")

        hostnames = host_el.find("hostnames")
        if hostnames is not None:
            hn = hostnames.find("hostname")
            if hn is not None:
                rec["hostname"] = hn.get("name", "")

        os_el = host_el.find("os")
        if os_el is not None:
            match = os_el.find("osmatch")
            if match is not None:
                rec["os_guess"] = match.get("name", "")

        ports_el = host_el.find("ports")
        if ports_el is not None:
            for port in ports_el.findall("port"):
                state = port.find("state")
                if state is not None and state.get("state") == "open":
                    svc = port.find("service")
                    svc_name = svc.get("name", "") if svc is not None else ""
                    rec["open_ports"].append(
                        f"{port.get('portid')}/{port.get('protocol')} ({svc_name})"
                    )
        hosts.append(rec)
    return hosts

# ---------------------------------------------------------------------------
# Core Scan Logic
# ---------------------------------------------------------------------------

def perform_scan(db: sqlite3.Connection, config: dict) -> dict:
    """Run a full scan cycle: discover hosts, classify, alert, store."""
    net = config["network"]
    scan_cfg = config["scan"]
    known_macs = {d["mac"].lower() for d in config["known_devices"]}
    known_names = {d["mac"].lower(): d["name"] for d in config["known_devices"]}

    now = datetime.now(timezone.utc).isoformat()
    t0 = time.time()

    # Phase 1 — ping sweep
    xml = run_nmap_scan(net["subnet"], scan_cfg["nmap_flags"])
    hosts = parse_nmap_hosts(xml)

    # Phase 2 — deep scan unknown devices
    unknown_ips = [h["ip"] for h in hosts if h["mac"].lower() not in known_macs and h["ip"] != net["gateway"]]
    if scan_cfg.get("deep_scan_unknown") and unknown_ips:
        log.warning("Deep-scanning %d unknown device(s): %s", len(unknown_ips), unknown_ips)
        for ip in unknown_ips:
            try:
                deep_xml = run_nmap_scan(ip, scan_cfg["deep_scan_flags"])
                deep_hosts = parse_nmap_hosts(deep_xml)
                # merge deep info back
                for dh in deep_hosts:
                    for h in hosts:
                        if h["ip"] == dh["ip"]:
                            h["os_guess"] = dh.get("os_guess", h["os_guess"])
                            h["open_ports"] = dh.get("open_ports", h["open_ports"])
                            break
            except Exception as e:
                log.error("Deep scan failed for %s: %s", ip, e)

    # Phase 3 — vendor enrichment for unknowns missing vendor info
    for h in hosts:
        if not h["vendor"] and h["mac"]:
            h["vendor"] = lookup_mac_vendor(h["mac"])

    duration = time.time() - t0

    # Phase 4 — store
    cur = db.execute("INSERT INTO scans (ts, duration_s, hosts_up) VALUES (?, ?, ?)",
                     (now, round(duration, 2), len(hosts)))
    scan_id = cur.lastrowid

    alerts_generated = []
    for h in hosts:
        mac_lower = h["mac"].lower()
        is_known = mac_lower in known_macs
        device_name = known_names.get(mac_lower, "")

        db.execute(
            """INSERT INTO devices (scan_id, ip, mac, vendor, hostname, os_guess, open_ports, is_known, device_name, ts)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (scan_id, h["ip"], h["mac"], h["vendor"], h["hostname"],
             h["os_guess"], json.dumps(h["open_ports"]),
             1 if is_known else 0, device_name, now),
        )

        # Alert on unknown device (skip gateway)
        if not is_known and h["ip"] != net["gateway"]:
            severity = "CRITICAL"
            msg = (f"INTRUDER DETECTED — Unknown device on network. "
                   f"IP={h['ip']} MAC={h['mac']} Vendor={h['vendor']} "
                   f"Hostname={h['hostname']} OS={h['os_guess']} "
                   f"Ports={h['open_ports']}")
            log.critical("\033[91m%s\033[0m", msg)
            db.execute(
                "INSERT INTO alerts (scan_id, ts, severity, mac, ip, message) VALUES (?, ?, ?, ?, ?, ?)",
                (scan_id, now, severity, h["mac"], h["ip"], msg),
            )
            alerts_generated.append({"severity": severity, "ip": h["ip"], "mac": h["mac"], "message": msg})

    db.commit()

    summary = {
        "scan_id": scan_id,
        "timestamp": now,
        "duration_s": round(duration, 2),
        "total_hosts": len(hosts),
        "known": sum(1 for h in hosts if h["mac"].lower() in known_macs),
        "unknown": sum(1 for h in hosts if h["mac"].lower() not in known_macs and h["ip"] != net["gateway"]),
        "alerts": len(alerts_generated),
    }

    log.info("Scan #%d complete — %d hosts (%d known, %d UNKNOWN) in %.1fs",
             scan_id, summary["total_hosts"], summary["known"], summary["unknown"], duration)
    return summary

# ---------------------------------------------------------------------------
# JSON HTTP API for Grafana
# ---------------------------------------------------------------------------

class MonitorAPIHandler(BaseHTTPRequestHandler):
    """Serves scan data as JSON for the Grafana Infinity datasource."""

    db: sqlite3.Connection = None
    gateway_ip: str = ""

    def log_message(self, fmt, *args):
        log.debug("API: %s", fmt % args)

    def _json_response(self, data, status=200):
        body = json.dumps(data, default=str).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self._json_response({})

    def do_GET(self):
        path = self.path.split("?")[0]
        params = {}
        if "?" in self.path:
            params = dict(p.split("=", 1) for p in self.path.split("?")[1].split("&") if "=" in p)

        routes = {
            "/":                self._health,
            "/health":          self._health,
            "/api/devices":     self._devices,
            "/api/latest-devices": self._latest_devices,
            "/api/alerts":      self._alerts,
            "/api/scans":       self._scans,
            "/api/timeline":    self._timeline,
            "/api/summary":     self._summary,
            "/api/intruders":   self._intruders,
        }

        handler = routes.get(path)
        if handler:
            handler(params)
        else:
            self._json_response({"error": "not found"}, 404)

    # --- Endpoints ---

    def _health(self, params):
        self._json_response({"status": "ok", "service": "ncomm-monitor"})

    def _summary(self, params):
        """Current network summary stats."""
        db = self.__class__.db
        gateway_ip = self.__class__.gateway_ip
        row = db.execute("""
            SELECT s.id, s.ts, s.hosts_up, s.duration_s,
                   COALESCE(SUM(d.is_known), 0) as known_count,
                   COALESCE(COUNT(d.id) - SUM(d.is_known), 0) as unknown_count
            FROM scans s LEFT JOIN devices d ON d.scan_id = s.id
            GROUP BY s.id ORDER BY s.id DESC LIMIT 1
        """).fetchone()
        if row:
            total_alerts = db.execute("SELECT COUNT(*) FROM alerts").fetchone()[0]
            total_intruders = db.execute(
                "SELECT COUNT(DISTINCT mac) FROM devices WHERE is_known = 0 AND ip != ?",
                (gateway_ip,),
            ).fetchone()[0]
            self._json_response([{
                "last_scan_id": row["id"],
                "last_scan_time": row["ts"],
                "hosts_up": row["hosts_up"],
                "known_devices": row["known_count"],
                "unknown_devices": row["unknown_count"],
                "total_alerts_all_time": total_alerts,
                "unique_intruders_all_time": total_intruders,
                "scan_duration_s": row["duration_s"],
            }])
        else:
            self._json_response([])

    def _devices(self, params):
        """All devices from the last N scans."""
        limit = int(params.get("limit", "100"))
        rows = self.__class__.db.execute(
            """SELECT d.*, s.ts as scan_time FROM devices d
               JOIN scans s ON s.id = d.scan_id
               ORDER BY d.ts DESC LIMIT ?""", (limit,)
        ).fetchall()
        self._json_response([dict(r) for r in rows])

    def _latest_devices(self, params):
        """Devices seen in the most recent scan only."""
        rows = self.__class__.db.execute(
            """SELECT d.*, s.ts as scan_time FROM devices d
               JOIN scans s ON s.id = d.scan_id
               WHERE d.scan_id = (SELECT MAX(id) FROM scans)
               ORDER BY d.is_known DESC, d.device_name ASC, d.ip ASC"""
        ).fetchall()
        self._json_response([dict(r) for r in rows])

    def _alerts(self, params):
        """All alerts, newest first."""
        limit = int(params.get("limit", "200"))
        rows = self.__class__.db.execute(
            "SELECT * FROM alerts ORDER BY ts DESC LIMIT ?", (limit,)
        ).fetchall()
        self._json_response([dict(r) for r in rows])

    def _scans(self, params):
        """Scan history."""
        limit = int(params.get("limit", "50"))
        rows = self.__class__.db.execute(
            "SELECT * FROM scans ORDER BY ts DESC LIMIT ?", (limit,)
        ).fetchall()
        self._json_response([dict(r) for r in rows])

    def _timeline(self, params):
        """Device count over time — for Grafana time-series panels."""
        rows = self.__class__.db.execute("""
            SELECT s.ts as time,
                   SUM(CASE WHEN d.is_known = 1 THEN 1 ELSE 0 END) as known,
                   SUM(CASE WHEN d.is_known = 0 THEN 1 ELSE 0 END) as unknown,
                   COUNT(d.id) as total
            FROM scans s LEFT JOIN devices d ON d.scan_id = s.id
            GROUP BY s.id ORDER BY s.ts ASC
        """).fetchall()
        self._json_response([dict(r) for r in rows])

    def _intruders(self, params):
        """All unique unknown devices ever seen."""
        rows = self.__class__.db.execute("""
            SELECT mac, ip, vendor, hostname, os_guess, open_ports,
                   MIN(ts) as first_seen, MAX(ts) as last_seen, COUNT(*) as times_seen
            FROM devices WHERE is_known = 0 AND ip != ?
            GROUP BY mac ORDER BY first_seen DESC
        """, (self.__class__.gateway_ip,)).fetchall()
        self._json_response([dict(r) for r in rows])

def start_api_server(db: sqlite3.Connection, port: int, gateway_ip: str):
    MonitorAPIHandler.db = db
    MonitorAPIHandler.gateway_ip = gateway_ip
    server = HTTPServer(("127.0.0.1", port), MonitorAPIHandler)
    log.info("API server listening on http://localhost:%d", port)
    log.info("  Grafana endpoints:")
    for ep in ["/api/summary", "/api/latest-devices", "/api/devices", "/api/alerts", "/api/timeline", "/api/intruders", "/api/scans"]:
        log.info("    http://localhost:%d%s", port, ep)
    server.serve_forever()

# ---------------------------------------------------------------------------
# Scanner Loop
# ---------------------------------------------------------------------------

def scan_loop(db: sqlite3.Connection, config: dict):
    interval = config["scan"]["interval_seconds"]
    while True:
        try:
            perform_scan(db, config)
        except Exception as e:
            log.error("Scan failed: %s", e)
        log.info("Next scan in %ds...", interval)
        time.sleep(interval)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="NCOMM Router Intrusion Monitor")
    parser.add_argument("--scan-only", action="store_true", help="Run a single scan and exit")
    parser.add_argument("--api-only", action="store_true", help="Start API server only (no scanning)")
    parser.add_argument("--port", type=int, default=8199, help="API server port (default: 8199)")
    parser.add_argument("--interval", type=int, help="Override scan interval (seconds)")
    args = parser.parse_args()

    config = load_config()
    if args.interval:
        config["scan"]["interval_seconds"] = args.interval

    _load_oui_cache()
    db = get_db()

    # Graceful shutdown
    def shutdown(sig, frame):
        log.info("Shutting down...")
        db.close()
        sys.exit(0)
    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    if args.scan_only:
        summary = perform_scan(db, config)
        print(json.dumps(summary, indent=2))
        db.close()
        return

    if args.api_only:
        start_api_server(db, args.port, config["network"]["gateway"])
        return

    # Default: run scanner in background thread + API server in foreground
    scanner_thread = threading.Thread(target=scan_loop, args=(db, config), daemon=True)
    scanner_thread.start()
    start_api_server(db, args.port, config["network"]["gateway"])


if __name__ == "__main__":
    main()
