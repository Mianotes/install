#!/usr/bin/env python3
from __future__ import annotations

import argparse
import mimetypes
from functools import partial
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlsplit
from urllib.request import Request, urlopen

BACKEND_PREFIXES = ("/api", "/html", "/markdown", "/.profiles")
HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
}


def should_proxy(path: str) -> bool:
    clean_path = urlsplit(path).path
    if any(clean_path == prefix or clean_path.startswith(f"{prefix}/") for prefix in BACKEND_PREFIXES):
        return True
    return bool(Path(clean_path).suffix)


class DashboardRequestHandler(SimpleHTTPRequestHandler):
    backend_url = "http://127.0.0.1:8200"

    def do_GET(self) -> None:
        self._handle_request()

    def do_HEAD(self) -> None:
        self._handle_request()

    def do_POST(self) -> None:
        self._handle_request()

    def do_PUT(self) -> None:
        self._handle_request()

    def do_PATCH(self) -> None:
        self._handle_request()

    def do_DELETE(self) -> None:
        self._handle_request()

    def _handle_request(self) -> None:
        if self.command in {"GET", "HEAD"} and self._static_file_exists():
            self._serve_static_file()
            return
        if should_proxy(self.path):
            self._proxy_request()
            return
        self._send_index()

    def _static_file_exists(self) -> bool:
        clean_path = urlsplit(self.path).path
        target = Path(self.translate_path(clean_path))
        return clean_path != "/" and target.is_file()

    def _serve_static_file(self) -> None:
        if self.command == "HEAD":
            super().do_HEAD()
        else:
            super().do_GET()

    def _send_index(self) -> None:
        index_path = Path(self.directory) / "index.html"
        if not index_path.exists():
            self.send_error(HTTPStatus.NOT_FOUND, "Dashboard build not found")
            return

        content = index_path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(content)

    def _proxy_request(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(content_length) if content_length else None
        target_url = urljoin(f"{self.backend_url.rstrip('/')}/", self.path.lstrip("/"))
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in HOP_BY_HOP_HEADERS and key.lower() != "host"
        }
        request = Request(target_url, data=body, headers=headers, method=self.command)

        try:
            with urlopen(request, timeout=60) as response:
                self._send_proxy_response(response.status, response.headers.items(), response.read())
        except HTTPError as error:
            self._send_proxy_response(error.code, error.headers.items(), error.read())
        except URLError:
            payload = b"Mianotes web service is not reachable."
            self.send_response(HTTPStatus.BAD_GATEWAY)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(payload)

    def _send_proxy_response(
        self,
        status_code: int,
        headers: object,
        body: bytes,
    ) -> None:
        self.send_response(status_code)
        has_content_type = False
        for key, value in headers:
            lower_key = key.lower()
            if lower_key in HOP_BY_HOP_HEADERS or lower_key == "content-length":
                continue
            if lower_key == "content-type":
                has_content_type = True
            self.send_header(key, value)
        if not has_content_type:
            content_type = mimetypes.guess_type(self.path)[0] or "application/octet-stream"
            self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Serve the Mianotes dashboard and proxy API requests.")
    parser.add_argument("--directory", required=True)
    parser.add_argument("--backend", default="http://127.0.0.1:8200")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8201)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    handler = partial(DashboardRequestHandler, directory=args.directory)
    DashboardRequestHandler.backend_url = args.backend
    with ThreadingHTTPServer((args.host, args.port), handler) as server:
        server.serve_forever()


if __name__ == "__main__":
    main()
