#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/config/valkey.env"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] [valkey-dump] $*"
}

fail() {
  log "ERROR: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  local label="$2"
  [[ -f "${path}" ]] || fail "${label} not found: ${path}"
}

require_cmd() {
  local name="$1"
  command -v "${name}" >/dev/null 2>&1 || fail "required command not found: ${name}"
}

require_file "${ENV_FILE}" "env file"
require_cmd python3

# shellcheck disable=SC1090
source "${ENV_FILE}"

export VALKEY_HOST
export VALKEY_PORT
export VALKEY_DB
export VALKEY_PASSWORD
export KEY_PREFIX

python3 - <<'PY'
import json
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


def read_bulk(sock: socket.socket) -> str | None:
    size = int(read_line(sock))
    if size < 0:
      return None
    remaining = size + 2
    chunks = []
    while remaining > 0:
        chunk = sock.recv(min(remaining, 4096))
        if not chunk:
            raise RuntimeError("unexpected EOF from valkey")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)[:-2].decode()


def read_response(sock: socket.socket):
    first = sock.recv(1)
    if not first:
        raise RuntimeError("empty response from valkey")
    if first == b"+":
        return read_line(sock).decode()
    if first == b":":
        return int(read_line(sock))
    if first == b"$":
        return read_bulk(sock)
    if first == b"*":
        count = int(read_line(sock))
        return [read_response(sock) for _ in range(max(count, 0))]
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

keys = [
    f"{prefix}:node:inference-node-01",
    f"{prefix}:model:qwen36",
    f"{prefix}:model:gemma4-31b",
    f"{prefix}:gpu:0",
    f"{prefix}:gpu:1",
    f"{prefix}:control:cluster_mode_override",
]

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

    dump = {}
    for key in keys:
        key_type = command(sock, "TYPE", key)
        if key_type == "hash":
            dump[key] = command(sock, "HGETALL", key)
        elif key_type == "string":
            dump[key] = command(sock, "GET", key)
        else:
            dump[key] = None

    print(json.dumps(dump, ensure_ascii=False, indent=2))
finally:
    sock.close()
PY
