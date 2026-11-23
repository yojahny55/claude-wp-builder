"""A stand-in Store API on loopback, for tests/checks/woo-verify-integration.sh: it answers a cart
the way WooCommerce does, but its cart token names a session no fixture database holds -- another
site on the same host. Usage: fake-store-api.py <port> <product-id>"""
import base64
import http.server
import json
import sys

port, pid = int(sys.argv[1]), int(sys.argv[2])


def b64(d):
    return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")


TOKEN = b64({"alg": "HS256"}) + "." + b64({"user_id": "t_elsewhere"}) + ".sig"


class Handler(http.server.BaseHTTPRequestHandler):
    def answer(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n:
            self.rfile.read(n)
        removed = "remove-item" in self.path
        body = json.dumps({"items_count": 0 if removed else 1,
                           "items": [] if removed else [{"id": pid, "key": "k"}]}).encode()
        self.send_response(201 if "add-item" in self.path else 200)
        self.send_header("Cart-Token", TOKEN)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    do_GET = do_POST = answer

    def log_message(self, *args):
        pass


http.server.HTTPServer(("127.0.0.1", port), Handler).serve_forever()
