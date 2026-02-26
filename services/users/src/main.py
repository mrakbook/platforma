import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer


def _payload(path: str) -> dict:
    service_name = os.getenv("SERVICE_NAME", "platforma-service")
    message = os.getenv("APP_MESSAGE", "Hello from platforma")
    if path == "/health":
        return {"status": "ok", "service": service_name}
    return {"message": message, "service": service_name}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        payload = _payload(self.path)
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        return


def main() -> None:
    host = os.getenv("APP_HOST", "0.0.0.0")
    port = int(os.getenv("APP_PORT", "50300"))
    server = HTTPServer((host, port), Handler)
    print(f"starting {os.getenv('SERVICE_NAME', 'platforma-service')} on {host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
