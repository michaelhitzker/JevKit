#!/usr/bin/env python3
"""Test the real URLSession transport against an isolated, loopback-only fixture."""
import http.server
import json
import os
import subprocess
import threading
from pathlib import Path

seen = set()
seen_lock = threading.Lock()
stopping = threading.Event()


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, status, body, headers=None):
        data = body.encode()
        self.send_response(status)
        self.send_header("Content-Length", str(len(data)))
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        with seen_lock:
            present = self.path.removeprefix("/seen/") in seen
        self.reply(200, "yes" if present else "no")

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length))
        if self.headers.get("Authorization") != "Bearer local-fixture":
            self.reply(401, "wrong authorization")
            return
        if self.headers.get("Content-Type") != "application/json":
            self.reply(422, "wrong content type")
            return
        state = body["state"]
        with seen_lock:
            seen.add(state)
        if state == "redirect" and self.path != "/redirected":
            self.reply(307, "redirect", {"Location": "/redirected"})
            return
        if state == "timeout" or state.startswith("cancel-"):
            stopping.wait(20)
        self.reply(200, json.dumps({
            "model": "fixture", "answers": {"bug": {"type": "noul", "noul": 0.91}},
            "usage": {"input_tokens": 1, "output_tokens": 1}
        }), {"Content-Type": "application/json"})


if __name__ == "__main__":
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    env = os.environ.copy()
    env.pop("JEV_API_KEY", None)
    env["JEV_TEST_HTTP_URL"] = f"http://127.0.0.1:{server.server_port}"
    try:
        result = subprocess.run(
            ["swift", "test", "-Xswiftc", "-warnings-as-errors", "--filter", "HTTPTransportTests"],
            cwd=Path(__file__).resolve().parent.parent, env=env, check=False
        )
    finally:
        stopping.set()
        server.shutdown()
        server.server_close()
        thread.join()
    raise SystemExit(result.returncode)
