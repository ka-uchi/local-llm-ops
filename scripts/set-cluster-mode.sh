#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <dual-single|single-70b>" >&2
  exit 1
fi

MODE="$1"
case "${MODE}" in
  dual-single|single-70b)
    ;;
  *)
    echo "ERROR: unsupported cluster mode: ${MODE}" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/config/valkey.env"

[[ -f "${ENV_FILE}" ]] || {
  echo "ERROR: env file not found: ${ENV_FILE}" >&2
  exit 1
}

# shellcheck disable=SC1090
source "${ENV_FILE}"

export VALKEY_HOST
export VALKEY_PORT
export VALKEY_DB
export VALKEY_PASSWORD
export KEY_PREFIX
export MODE

python3 - <<'PY'
import os
import socket
import sys


def encode_command(*parts: str) -> bytes:
    encoded = [f"*{len(parts)}\r\n".encode()]
    for part in parts:
        blob = str(part).encode()
        encoded.append(f"${len(blob)}\r\n".encode())
        encoded.append(blob + b"\r\n")
    return b"".join(encoded)


def read_line(sock: socket.socket) -> bytes:
    buf = b""
    while not buf.endswith(b"\r\n"):
        chunk = sock.recv(1)
        if not chunk:
            raise RuntimeError("unexpected EOF from valkey")
        buf += chunk
    return buf[:-2]


def read_response(sock: socket.socket):
    first = sock.recv(1)
    if not first:
        raise RuntimeError("empty response from valkey")
    if first in {b"+", b":", b"$"}:
        return read_line(sock).decode()
    if first == b"-":
        raise RuntimeError(read_line(sock).decode())
    raise RuntimeError(f"unsupported response type: {first!r}")


def command(sock: socket.socket, *parts: str):
    sock.sendall(encode_command(*parts))
    return read_response(sock)


host = os.environ["VALKEY_HOST"]
port = int(os.environ["VALKEY_PORT"])
db = int(os.environ["VALKEY_DB"])
password = os.environ.get("VALKEY_PASSWORD", "")
prefix = os.environ["KEY_PREFIX"]
mode = os.environ["MODE"]

try:
    sock = socket.create_connection((host, port), timeout=3)
except OSError as exc:
    print(f"ERROR: cannot connect to valkey at {host}:{port}: {exc}", file=sys.stderr)
    raise SystemExit(1) from exc

try:
    if password:
        command(sock, "AUTH", password)
    if db:
        command(sock, "SELECT", str(db))
    command(sock, "SET", f"{prefix}:control:cluster_mode_override", mode)
    print(f"cluster_mode_override={mode}")
finally:
    sock.close()
PY
