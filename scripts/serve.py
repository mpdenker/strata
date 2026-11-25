#!/usr/bin/env python3
"""Run the Strata website locally (Python standard library only).

    python3 scripts/serve.py            # http://localhost:8000
    python3 scripts/serve.py --lan      # also reachable from your phone on the same Wi-Fi

Serves web/ at /, Content/ at /content/, plus three generated files:
  /content/index.json   every lesson file in Content/Lessons (so a new lesson is just one JSON file)
  /app-config.json      the app name, read from Config/App.xcconfig (one place to rename, iOS and web)
  /manifest.webmanifest the home-screen app manifest, using that name
"""
import argparse, http.server, json, pathlib, re, socket

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB, CONTENT = ROOT / "web", ROOT / "Content"


def xcconfig(key, default):
    text = (ROOT / "Config" / "App.xcconfig").read_text()
    m = re.search(rf"^\s*{key}\s*=\s*(.+?)\s*$", text, re.M)
    return m.group(1) if m else default


def generated():
    name = xcconfig("APP_DISPLAY_NAME", "Strata")
    lessons = sorted(str(p.relative_to(CONTENT)) for p in (CONTENT / "Lessons").rglob("*.json"))
    return {
        "/content/index.json": {"lessons": lessons},
        "/app-config.json": {"name": name, "version": xcconfig("MARKETING_VERSION", "0") + "-web"},
        "/manifest.webmanifest": {
            "name": name, "short_name": name, "start_url": "./", "scope": "./", "display": "standalone",
            "background_color": "#F6F1E7", "theme_color": "#F6F1E7",
            "icons": [{"src": "icon.svg", "sizes": "any", "type": "image/svg+xml"},
                      {"src": "icon-180.png", "sizes": "180x180", "type": "image/png"}],
        },
    }


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".js": "text/javascript", ".json": "application/json", ".webmanifest": "application/manifest+json",
                      ".svg": "image/svg+xml"}

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        gen = generated()
        if path in gen:
            body = json.dumps(gen[path], indent=1).encode()
            self.send_response(200)
            self.send_header("Content-Type", self.extensions_map[".webmanifest" if path.endswith("manifest") else ".json"])
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def translate_path(self, path):
        path = path.split("?", 1)[0].split("#", 1)[0]
        base, rest = (CONTENT, path[len("/content/"):]) if path.startswith("/content/") else (WEB, path.lstrip("/"))
        target = (base / rest).resolve()
        if base.resolve() not in [target, *target.parents]:
            return str(base / "__forbidden__")
        return str(target)

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--lan", action="store_true", help="listen on all interfaces so a phone on the same Wi-Fi can connect")
    a = ap.parse_args()
    host = "0.0.0.0" if a.lan else "127.0.0.1"
    server = http.server.ThreadingHTTPServer((host, a.port), Handler)
    print(f"Strata: http://localhost:{a.port}")
    if a.lan:
        try:
            ip = socket.gethostbyname(socket.gethostname())
            print(f"On your phone (same Wi-Fi): http://{ip}:{a.port}")
        except OSError:
            pass
    print("Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
