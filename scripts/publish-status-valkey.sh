#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/config/valkey.env"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] [valkey-publisher] $*"
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
export NODE_ID
export KEY_PREFIX
export STATUS_TTL_SECONDS
export LLM_CLUSTER_MODE
export QWEN_HEALTH_URL
export GEMMA_HEALTH_URL
export QWEN_MODEL_ID
export QWEN_MODEL_NAME
export QWEN_GPU_INDEX
export QWEN_PORT
export GEMMA_MODEL_ID
export GEMMA_MODEL_NAME
export GEMMA_GPU_INDEX
export GEMMA_PORT

log "publishing runtime status to ${VALKEY_HOST}:${VALKEY_PORT}/${VALKEY_DB}"

python3 - <<'PY'
import datetime as dt
import os
import socket
import subprocess
import sys
import urllib.error
import urllib.request


def env(name: str, default: str = "") -> str:
    value = os.environ.get(name, default)
    if value == "":
        return default
    return value


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def read_line(sock: socket.socket) -> bytes:
    buf = b""
    while not buf.endswith(b"\r\n"):
        chunk = sock.recv(1)
        if not chunk:
            raise RuntimeError("unexpected EOF from valkey")
        buf += chunk
    return buf[:-2]


def fetch_bulk_string(sock: socket.socket) -> str | None:
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


def http_status(url: str) -> tuple[str, str]:
    try:
        with urllib.request.urlopen(url, timeout=3) as response:
            if 200 <= response.status < 300:
                return "ready", f"http_{response.status}"
            return "down", f"http_{response.status}"
    except urllib.error.URLError as exc:
        return "down", str(exc.reason)
    except Exception as exc:  # noqa: BLE001
        return "unknown", str(exc)


def gpu_rows() -> dict[int, dict[str, str]]:
    try:
        output = subprocess.check_output(
            [
                "nvidia-smi",
                "--query-gpu=index,name,memory.total,memory.used,utilization.gpu,temperature.gpu",
                "--format=csv,noheader,nounits",
            ],
            text=True,
            stderr=subprocess.STDOUT,
        )
    except FileNotFoundError:
        return {}
    except subprocess.CalledProcessError:
        return {}

    rows: dict[int, dict[str, str]] = {}
    for line in output.splitlines():
        parts = [part.strip() for part in line.split(",")]
        if len(parts) != 6:
            continue
        index = int(parts[0])
        rows[index] = {
            "gpu_index": parts[0],
            "gpu_name": parts[1],
            "memory_total_mb": parts[2],
            "memory_used_mb": parts[3],
            "utilization_gpu": parts[4],
            "temperature_c": parts[5],
        }
    return rows


def encode_command(*parts: str) -> bytes:
    encoded = [f"*{len(parts)}\r\n".encode()]
    for part in parts:
        blob = str(part).encode()
        encoded.append(f"${len(blob)}\r\n".encode())
        encoded.append(blob + b"\r\n")
    return b"".join(encoded)


def read_response(sock: socket.socket) -> None:
    first = sock.recv(1)
    if not first:
        raise RuntimeError("empty response from valkey")
    if first == b"+":
        read_line(sock)
        return
    if first == b":":
        read_line(sock)
        return
    if first == b"$":
        fetch_bulk_string(sock)
        return
    if first == b"*":
        count = int(read_line(sock))
        for _ in range(max(count, 0)):
            read_response(sock)
        return
    if first == b"-":
        raise RuntimeError(read_line(sock).decode())
    raise RuntimeError(f"unsupported response type: {first!r}")


def publish_hash(sock: socket.socket, key: str, values: dict[str, str], ttl: int) -> None:
    fields: list[str] = []
    for field, value in values.items():
        fields.extend([field, value])
    sock.sendall(encode_command("HSET", key, *fields))
    read_response(sock)
    sock.sendall(encode_command("EXPIRE", key, str(ttl)))
    read_response(sock)


def get_string(sock: socket.socket, key: str) -> str | None:
    sock.sendall(encode_command("GET", key))
    first = sock.recv(1)
    if not first:
        raise RuntimeError("empty response from valkey")
    if first == b"$":
        return fetch_bulk_string(sock)
    if first == b"-":
        err = b""
        while not err.endswith(b"\r\n"):
            err += sock.recv(1)
        raise RuntimeError(err[:-2].decode())
    raise RuntimeError(f"unexpected response type for GET: {first!r}")


host = env("VALKEY_HOST", "127.0.0.1")
port = int(env("VALKEY_PORT", "6379"))
db = int(env("VALKEY_DB", "0"))
password = env("VALKEY_PASSWORD")
node_id = env("NODE_ID", "echo-chamber")
prefix = env("KEY_PREFIX", "llm")
ttl = int(env("STATUS_TTL_SECONDS", "30"))
updated_at = now_iso()

models = [
    {
        "model_id": env("QWEN_MODEL_ID", "qwen36"),
        "model_name": env("QWEN_MODEL_NAME", "Qwen3.6-35B-A3B"),
        "gpu_index": env("QWEN_GPU_INDEX", "0"),
        "port": env("QWEN_PORT", "8080"),
        "health_url": env("QWEN_HEALTH_URL", "http://127.0.0.1:8080/health"),
    },
    {
        "model_id": env("GEMMA_MODEL_ID", "gemma4-31b"),
        "model_name": env("GEMMA_MODEL_NAME", "Gemma-4-31B-IT"),
        "gpu_index": env("GEMMA_GPU_INDEX", "1"),
        "port": env("GEMMA_PORT", "8081"),
        "health_url": env("GEMMA_HEALTH_URL", "http://127.0.0.1:8081/health"),
    },
]

for model in models:
    status, reason = http_status(model["health_url"])
    model["status"] = status
    model["status_reason"] = reason

gpus = gpu_rows()
try:
    sock = socket.create_connection((host, port), timeout=3)
except OSError as exc:
    print(
        f"ERROR: cannot connect to valkey at {host}:{port}: {exc}",
        file=sys.stderr,
    )
    raise SystemExit(1) from exc

try:
    if password:
        sock.sendall(encode_command("AUTH", password))
        read_response(sock)
    if db:
        sock.sendall(encode_command("SELECT", str(db)))
        read_response(sock)

    cluster_mode = get_string(sock, f"{prefix}:control:cluster_mode_override")
    if not cluster_mode:
        cluster_mode = env("LLM_CLUSTER_MODE", "dual-single")

    publish_hash(
        sock,
        f"{prefix}:node:{node_id}",
        {
            "node_id": node_id,
            "cluster_mode": cluster_mode,
            "updated_at": updated_at,
            "publisher": "publish-status-valkey.sh",
        },
        ttl,
    )

    for model in models:
        publish_hash(
            sock,
            f"{prefix}:model:{model['model_id']}",
            {
                "node_id": node_id,
                "model_id": model["model_id"],
                "model_name": model["model_name"],
                "status": model["status"],
                "status_reason": model["status_reason"],
                "gpu_index": model["gpu_index"],
                "port": model["port"],
                "health_url": model["health_url"],
                "updated_at": updated_at,
            },
            ttl,
        )

    for model in models:
        gpu_index = int(model["gpu_index"])
        gpu = gpus.get(gpu_index, {})
        publish_hash(
            sock,
            f"{prefix}:gpu:{gpu_index}",
            {
                "node_id": node_id,
                "gpu_index": str(gpu_index),
                "gpu_name": gpu.get("gpu_name", "unknown"),
                "memory_total_mb": gpu.get("memory_total_mb", "-1"),
                "memory_used_mb": gpu.get("memory_used_mb", "-1"),
                "utilization_gpu": gpu.get("utilization_gpu", "-1"),
                "temperature_c": gpu.get("temperature_c", "-1"),
                "owner_model_id": model["model_id"],
                "updated_at": updated_at,
            },
            ttl,
        )
finally:
    sock.close()
print(f"node_id={node_id} cluster_mode={cluster_mode}")
for model in models:
    print(
        f"model_id={model['model_id']} status={model['status']} gpu_index={model['gpu_index']}"
    )
PY
