"""
Dev server for the Relax Space frontend.

Serves static files from the frontend folder on port 8001 and transparently
proxies every request that starts with /api/ to the FastAPI backend at
127.0.0.1:8000, so the browser never issues a cross-origin request.

Run:  python3 proxy_server.py
"""

import urllib.request
import urllib.error
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

FRONTEND_PORT = 8001
BACKEND_HOST = "127.0.0.1"
BACKEND_PORT = 8000
API_PREFIX = "/api/"


class ProxyHandler(SimpleHTTPRequestHandler):
    def _proxy_to_backend(self):
        path = self.path[len("/api"):] or "/"
        url = f"http://{BACKEND_HOST}:{BACKEND_PORT}{path}"

        content_length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(content_length) if content_length else None

        request = urllib.request.Request(url, data=body, method=self.command)
        for header in ("Content-Type", "Accept"):
            value = self.headers.get(header)
            if value:
                request.add_header(header, value)

        try:
            with urllib.request.urlopen(request) as response:
                payload = response.read()
                self.send_response(response.status)
                content_type = response.headers.get("Content-Type", "application/json")
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
        except urllib.error.HTTPError as err:
            payload = err.read()
            self.send_response(err.code)
            self.send_header("Content-Type", err.headers.get("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except Exception:
            self.send_error(502, "Backend is not reachable")

    def do_GET(self):
        if self.path.startswith(API_PREFIX):
            self._proxy_to_backend()
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith(API_PREFIX):
            self._proxy_to_backend()
        else:
            self.send_error(405, "Method not allowed")

    def log_message(self, fmt, *args):
        print(f"[frontend:{FRONTEND_PORT}] {fmt % args}")


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", FRONTEND_PORT), ProxyHandler)
    print(f"Frontend running at http://127.0.0.1:{FRONTEND_PORT}")
    print(f"API requests under /api/ are proxied to http://{BACKEND_HOST}:{BACKEND_PORT}")
    server.serve_forever()
