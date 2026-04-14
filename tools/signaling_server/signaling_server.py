#!/usr/bin/env python3
"""
Minimal HTTP signaling for room codes (maps code -> public host + UDP game port).

Run on a VPS (example):
  python3 signaling_server.py 0.0.0.0 8787

Firewall: allow TCP on the chosen port. Game still uses its own UDP port on the host/VPS.

Behind nginx, set X-Forwarded-For so registrations get the real client IP, or use JSON
"advertise_host" from a trusted dedicated server.
"""
from __future__ import annotations

import json
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn

TTL_SECONDS = 120

_lock = threading.Lock()
# code (upper str) -> {"host": str, "port": int, "exp": float}
_rooms: dict[str, dict] = {}


def _client_ip(handler: BaseHTTPRequestHandler) -> str:
    xff = handler.headers.get("X-Forwarded-For")
    if xff:
        return xff.split(",")[0].strip()
    return handler.client_address[0]


def _purge_locked(now: float) -> None:
    dead = [k for k, v in _rooms.items() if v["exp"] < now]
    for k in dead:
        del _rooms[k]


def _read_json(handler: BaseHTTPRequestHandler) -> dict | None:
    n = int(handler.headers.get("Content-Length", "0") or "0")
    if n <= 0 or n > 4096:
        return {}
    raw = handler.rfile.read(n)
    try:
        data = json.loads(raw.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None
    return data if isinstance(data, dict) else None


def _send_json(handler: BaseHTTPRequestHandler, status: int, obj: dict) -> None:
    body = json.dumps(obj).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _normalize_code(s: str) -> str:
    out = []
    for ch in s.upper():
        if ch.isalnum() and len(out) < 8:
            out.append(ch)
    return "".join(out)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        print("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), fmt % args))

    def do_GET(self) -> None:
        if self.path.startswith("/lookup/"):
            code = _normalize_code(self.path[len("/lookup/") :].split("?", 1)[0])
        elif self.path.startswith("/lookup?"):
            from urllib.parse import parse_qs, urlparse

            q = parse_qs(urlparse(self.path).query)
            raw = (q.get("code") or [""])[0]
            code = _normalize_code(raw)
        else:
            _send_json(self, 404, {"ok": False, "error": "not_found"})
            return

        if len(code) < 4:
            _send_json(self, 400, {"ok": False, "error": "bad_code"})
            return

        now = time.monotonic()
        with _lock:
            _purge_locked(now)
            row = _rooms.get(code)
            if row is None or row["exp"] < now:
                _send_json(self, 404, {"ok": False, "error": "no_room"})
                return
            _send_json(
                self,
                200,
                {"ok": True, "host": row["host"], "port": row["port"]},
            )

    def do_POST(self) -> None:
        if self.path not in ("/register", "/heartbeat", "/unregister"):
            _send_json(self, 404, {"ok": False, "error": "not_found"})
            return

        data = _read_json(self)
        if data is None:
            _send_json(self, 400, {"ok": False, "error": "bad_json"})
            return

        code = _normalize_code(str(data.get("code", "")))
        port = int(data.get("port", 0) or 0)
        adv = str(data.get("advertise_host", "") or "").strip()

        if len(code) < 4 or port < 1 or port > 65535:
            _send_json(self, 400, {"ok": False, "error": "bad_params"})
            return

        ip = _client_ip(self)
        host = adv if adv else ip

        now = time.monotonic()
        exp = now + TTL_SECONDS

        with _lock:
            _purge_locked(now)

            if self.path == "/register":
                _rooms[code] = {"host": host, "port": port, "exp": exp}
                _send_json(self, 200, {"ok": True})
                return

            if self.path == "/heartbeat":
                row = _rooms.get(code)
                if row is None:
                    _send_json(self, 404, {"ok": False, "error": "no_room"})
                    return
                if row["host"] != host or row["port"] != port:
                    _send_json(self, 403, {"ok": False, "error": "mismatch"})
                    return
                row["exp"] = exp
                _send_json(self, 200, {"ok": True})
                return

            # unregister
            row = _rooms.get(code)
            if row is not None and row["host"] == host and row["port"] == port:
                del _rooms[code]
            _send_json(self, 200, {"ok": True})


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


def main() -> None:
    import sys

    host = sys.argv[1] if len(sys.argv) > 1 else "0.0.0.0"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8787
    httpd = ThreadedHTTPServer((host, port), Handler)
    print("Signaling server on http://%s:%d" % (host, port))
    httpd.serve_forever()


if __name__ == "__main__":
    main()
