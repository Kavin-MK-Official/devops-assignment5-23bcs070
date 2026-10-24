#!/usr/bin/env python3
"""
TechNova Solutions - DevOps Mastery Assignment 5
CI/CD, deployment strategies and monitoring demo application.

Roll No: 23BCS070

The application keeps the Assignment 3 feature set (roll number page,
PostgreSQL-backed visitor counter, liveness/readiness endpoints) and adds:

  * APP_VERSION reported by /version, the page and the X-App-Version header
    so a rolling update or a blue-green switch is visible to an operator;
  * Prometheus instrumentation on /metrics (request count, request latency,
    database reachability, visits) exposed in gunicorn multi-process mode.
"""
import logging
import os
import socket
import time
from datetime import datetime, timezone

import psycopg2
from flask import Flask, Response, g, jsonify, render_template_string, request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    REGISTRY,
    CollectorRegistry,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)
from prometheus_client.multiprocess import MultiProcessCollector

ROLL_NUMBER = "23BCS070"
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")

DB_HOST = os.environ.get("DB_HOST", "db")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME", "technova")
DB_USER = os.environ.get("DB_USER", "technova")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("technova")

app = Flask(__name__)

# --------------------------------------------------------------------------
# Prometheus metrics
# --------------------------------------------------------------------------
REQUEST_COUNT = Counter(
    "http_requests", "HTTP requests served by the application",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds", "HTTP request latency in seconds",
    ["endpoint"],
)
DB_UP = Gauge(
    "technova_db_up", "1 when PostgreSQL is reachable from this pod",
    multiprocess_mode="max",
)
VISITS = Counter(
    "technova_page_visits", "Page visits persisted to PostgreSQL",
)
APP_INFO = Gauge(
    "technova_app_info", "Build information for the running image", ["version"],
)
APP_INFO.labels(version=APP_VERSION).set(1)


@app.before_request
def _start_timer():
    g.request_started = time.perf_counter()


@app.after_request
def _record_request(response):
    endpoint = request.endpoint or request.path
    REQUEST_COUNT.labels(request.method, endpoint, str(response.status_code)).inc()
    REQUEST_LATENCY.labels(endpoint).observe(time.perf_counter() - g.request_started)
    response.headers["X-App-Version"] = APP_VERSION
    return response


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>TechNova Solutions | {{ roll }}</title>
<style>
  * { box-sizing: border-box; }
  body {
    margin: 0; min-height: 100vh;
    font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
    background: radial-gradient(circle at 20% 0%, #1e3a8a 0%, #0f172a 45%, #020617 100%);
    color: #e2e8f0; display: flex; align-items: center; justify-content: center;
    padding: 24px;
  }
  .card {
    width: min(760px, 100%);
    background: rgba(30, 41, 59, 0.72);
    border: 1px solid rgba(148, 163, 184, 0.28);
    border-radius: 20px; padding: 40px;
    box-shadow: 0 24px 60px rgba(2, 6, 23, 0.6);
    backdrop-filter: blur(12px);
  }
  .badge {
    display: inline-block; font-size: 12px; letter-spacing: .14em;
    text-transform: uppercase; color: #93c5fd;
    border: 1px solid rgba(147, 197, 253, .4);
    border-radius: 999px; padding: 6px 14px; margin-bottom: 22px;
  }
  h1 { margin: 0 0 6px; font-size: 30px; letter-spacing: -.02em; }
  .sub { color: #94a3b8; margin: 0 0 30px; font-size: 15px; }
  .roll {
    font-family: "Cascadia Code", Consolas, monospace;
    font-size: 46px; font-weight: 700; letter-spacing: .04em;
    background: linear-gradient(90deg, #60a5fa, #22d3ee);
    -webkit-background-clip: text; background-clip: text;
    -webkit-text-fill-color: transparent;
    margin: 0 0 30px;
  }
  .grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 14px; }
  .cell {
    background: rgba(15, 23, 42, .72);
    border: 1px solid rgba(148, 163, 184, .16);
    border-radius: 12px; padding: 16px 18px;
  }
  .cell .k {
    font-size: 11px; text-transform: uppercase; letter-spacing: .1em;
    color: #64748b; margin-bottom: 7px;
  }
  .cell .v { font-family: "Cascadia Code", Consolas, monospace; font-size: 15px; color: #f1f5f9; }
  .ok { color: #4ade80; } .bad { color: #f87171; }
  footer {
    margin-top: 30px; padding-top: 20px;
    border-top: 1px solid rgba(148, 163, 184, .16);
    color: #64748b; font-size: 13px; line-height: 1.6;
  }
</style>
</head>
<body>
  <main class="card">
    <span class="badge">TechNova Solutions &middot; DevOps</span>
    <h1>Containerized Web Application</h1>
    <p class="sub">Assignment 5 &middot; CI/CD, deployment strategies and monitoring</p>
    <p class="roll">{{ roll }}</p>
    <div class="grid">
      <div class="cell"><div class="k">Application Version</div><div class="v">{{ version }}</div></div>
      <div class="cell"><div class="k">Serving Pod</div><div class="v">{{ hostname }}</div></div>
      <div class="cell"><div class="k">Served At (UTC)</div><div class="v">{{ served }}</div></div>
      <div class="cell">
        <div class="k">Database</div>
        <div class="v {{ 'ok' if db_ok else 'bad' }}">{{ db_status }}</div>
      </div>
      <div class="cell" style="grid-column: 1 / -1;">
        <div class="k">Total Page Visits Recorded in PostgreSQL</div>
        <div class="v">{{ visits }}</div>
      </div>
    </div>
    <footer>
      Served by a container image built by Jenkins, loaded into the Kubernetes
      cluster and monitored with Prometheus and Grafana. <code>/metrics</code>
      exposes the metrics scraped by Prometheus.
    </footer>
  </main>
</body>
</html>"""


def connect(retries=1):
    """Connect to PostgreSQL, retrying briefly while it starts up."""
    last = None
    for _ in range(retries):
        try:
            return psycopg2.connect(
                host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
                user=DB_USER, password=DB_PASSWORD, connect_timeout=4,
            )
        except Exception as exc:  # noqa: BLE001
            last = exc
            time.sleep(2)
    raise last


def record_visit():
    """Create the counter table if needed, increment it and return the total."""
    conn = connect(retries=2)
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS visits ("
                "  id SERIAL PRIMARY KEY,"
                "  visited_at TIMESTAMPTZ NOT NULL DEFAULT NOW()"
                ")"
            )
            cur.execute("INSERT INTO visits DEFAULT VALUES")
            cur.execute("SELECT COUNT(*) FROM visits")
            total = cur.fetchone()[0]
        VISITS.inc()
        log.info("visit recorded total=%s version=%s", total, APP_VERSION)
        return total
    finally:
        conn.close()


@app.route("/")
def index():
    db_ok, db_status, visits = False, "not connected", "n/a"
    try:
        visits = record_visit()
        db_ok, db_status = True, "connected"
        DB_UP.set(1)
    except Exception as exc:  # noqa: BLE001
        DB_UP.set(0)
        db_status = "unavailable: %s" % type(exc).__name__
        log.warning("database unavailable during page render: %s", type(exc).__name__)
    return render_template_string(
        PAGE,
        roll=ROLL_NUMBER,
        version=APP_VERSION,
        hostname=socket.gethostname(),
        served=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
        db_ok=db_ok,
        db_status=db_status,
        visits=visits,
    )


@app.route("/health")
def health():
    """Liveness probe: the process is up and serving requests."""
    return jsonify(status="alive", roll=ROLL_NUMBER, version=APP_VERSION), 200


@app.route("/ready")
def ready():
    """Readiness probe: the application can reach its database."""
    try:
        record_visit()
        DB_UP.set(1)
        return jsonify(status="ready", roll=ROLL_NUMBER, version=APP_VERSION,
                       database="connected"), 200
    except Exception as exc:  # noqa: BLE001
        DB_UP.set(0)
        log.warning("readiness check failed: %s", type(exc).__name__)
        return jsonify(status="not-ready", version=APP_VERSION,
                       database="unavailable",
                       error=type(exc).__name__), 503


@app.route("/version")
def version():
    return jsonify(roll=ROLL_NUMBER, version=APP_VERSION,
                   hostname=socket.gethostname()), 200


@app.route("/metrics")
def metrics():
    """Prometheus scrape endpoint (multi-process aware)."""
    if os.environ.get("PROMETHEUS_MULTIPROC_DIR"):
        registry = CollectorRegistry()
        MultiProcessCollector(registry)
        payload = generate_latest(registry)
    else:
        payload = generate_latest(REGISTRY)
    return Response(payload, mimetype=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
