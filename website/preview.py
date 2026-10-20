#!/usr/bin/env python3
"""Serve the generated documentation on loopback only."""
import argparse
import functools
import http.server
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--port", type=int, default=8095)
args = parser.parse_args()
root = Path(__file__).resolve().parent / "_site"
if not (root / "index.html").is_file():
    parser.error("Build first: python3 website/build.py")
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(root))
with http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
    print(f"Local documentation: http://127.0.0.1:{args.port}/", flush=True)
    print("Loopback only; Ctrl-C to stop.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
