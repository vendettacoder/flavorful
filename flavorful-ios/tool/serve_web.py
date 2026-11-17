"""Serve only a Flutter web build on this Mac, with app route fallback."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class AppHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        path = urlsplit(self.path).path
        # Only known app paths get index.html. Missing assets remain 404s.
        if path in {"/", "/sign-in", "/auth/callback", "/login-callback"} or (
            path.startswith("/recipes/") and "." not in path
        ) or "." not in path.rsplit("/", 1)[-1]:
            self.path = "/index.html"
        super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--demo", action="store_true", help="Serve build/web-demo, not build/web")
    parser.add_argument("--port", type=int, default=5173)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1] / "build" / ("web-demo" if args.demo else "web")
    if not (root / "index.html").is_file():
        parser.error(f"Build the web app first: {root}")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), partial(AppHandler, directory=str(root)))
    print(f"Serving {root} at http://127.0.0.1:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
