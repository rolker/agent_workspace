"""Servers on 127.0.0.1 for the tests that read a manifest from a git repo over http: one that
serves git's smart http protocol from a directory of repos (through `git http-backend`), with
redirects and an answer of 401 on request, and one that accepts connections and never answers.
Imported by the tests, not collected. No test reaches the network."""

from __future__ import annotations

import os
import socket
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, List


class _GitHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, *args):  # quiet
        pass

    def do_GET(self):  # noqa: N802 (the name http.server calls)
        self._serve()

    def do_POST(self):  # noqa: N802
        self._serve()

    def _serve(self):
        server: GitServer = self.server  # type: ignore[assignment]
        server.requests.append(self.path)
        path, _, query = self.path.partition("?")
        for old, new in server.redirects.items():
            if path.startswith(old):
                self.send_response(301)
                target = new + path[len(old) :] + (f"?{query}" if query else "")
                self.send_header("Location", target)
                self.end_headers()
                return
        if server.unauthorised:
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="test"')
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        env = {
            "PATH": os.environ.get("PATH", ""),
            "GIT_PROJECT_ROOT": str(server.root),
            "GIT_HTTP_EXPORT_ALL": "1",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "PATH_INFO": path,
            "QUERY_STRING": query,
            "REQUEST_METHOD": self.command,
            "CONTENT_TYPE": self.headers.get("Content-Type", ""),
            "CONTENT_LENGTH": str(length),
            "REMOTE_ADDR": "127.0.0.1",
        }
        if self.headers.get("Content-Encoding"):
            env["HTTP_CONTENT_ENCODING"] = self.headers["Content-Encoding"]
        if self.headers.get("Git-Protocol"):
            env["GIT_PROTOCOL"] = self.headers["Git-Protocol"]
        done = subprocess.run(
            ["git", "http-backend"], input=body, env=env, capture_output=True, check=False
        )
        out = done.stdout
        end = out.find(b"\r\n\r\n")
        head, rest = (out[:end], out[end + 4 :]) if end >= 0 else out.split(b"\n\n", 1)
        status = 200
        headers = []
        for line in head.decode("latin-1").splitlines():
            name, _, value = line.partition(":")
            if name.lower() == "status":
                status = int(value.split()[0])
            elif name:
                headers.append((name, value.strip()))
        self.send_response(status)
        for name, value in headers:
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(rest)


class GitServer(ThreadingHTTPServer):
    """Serves the repos below `root` at `http://127.0.0.1:<port>/<name>`."""

    daemon_threads = True

    def __init__(self, root: Path):
        super().__init__(("127.0.0.1", 0), _GitHandler)
        self.root = root
        self.redirects: Dict[str, str] = {}  # a path prefix -> the url it moves to
        self.unauthorised = False
        self.requests: List[str] = []
        self._thread = threading.Thread(target=self.serve_forever, daemon=True)
        self._thread.start()

    @property
    def url(self) -> str:
        return f"http://127.0.0.1:{self.server_address[1]}"

    def close(self) -> None:
        self.shutdown()
        self.server_close()


class SilentServer:
    """Accepts connections on 127.0.0.1 and never answers: a server that hangs."""

    def __init__(self):
        self.socket = socket.socket()
        self.socket.bind(("127.0.0.1", 0))
        self.socket.listen(16)
        self.port = self.socket.getsockname()[1]
        self.held: List[socket.socket] = []
        self._thread = threading.Thread(target=self._accept, daemon=True)
        self._thread.start()

    def _accept(self):
        while True:
            try:
                connection, _ = self.socket.accept()
            except OSError:
                return
            self.held.append(connection)

    @property
    def url(self) -> str:
        return f"http://127.0.0.1:{self.port}"

    def close(self) -> None:
        self.socket.close()
        for connection in self.held:
            connection.close()


def processes_naming(text: str) -> List[int]:
    """The pids of the processes whose command line holds `text`, from /proc."""
    found = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            cmdline = (entry / "cmdline").read_bytes()
        except OSError:
            continue
        if text.encode() in cmdline and int(entry.name) != os.getpid():
            found.append(int(entry.name))
    return found
