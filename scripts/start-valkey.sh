#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/config/valkey-server.env"
CONFIG_TEMPLATE="${REPO_ROOT}/config/valkey.conf"
RUNTIME_CONFIG="${REPO_ROOT}/var/valkey/valkey.generated.conf"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] [valkey] $*"
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

detect_server_bin() {
  local candidate

  if [[ -n "${VALKEY_SERVER_BIN:-}" ]]; then
    [[ -x "${VALKEY_SERVER_BIN}" ]] || fail "configured server bin is not executable: ${VALKEY_SERVER_BIN}"
    echo "${VALKEY_SERVER_BIN}"
    return
  fi

  if command -v valkey-server >/dev/null 2>&1; then
    command -v valkey-server
    return
  fi

  if command -v redis-server >/dev/null 2>&1; then
    command -v redis-server
    return
  fi

  for candidate in /snap/bin/valkey /snap/bin/valkey-server /snap/bin/valkey.* /snap/bin/redis*; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return
    fi
  done

  fail "valkey-server or redis-server not found; set VALKEY_SERVER_BIN in ${ENV_FILE}"
}

is_running() {
  local pid="$1"
  kill -0 "${pid}" 2>/dev/null
}

port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn "( sport = :${port} )" 2>/dev/null | tail -n +2 | grep -q .
    return
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
    return
  fi
  fail "neither ss nor lsof is available for port check"
}

[[ -f "${ENV_FILE}" ]] || fail "env file not found: ${ENV_FILE}"
require_file "${CONFIG_TEMPLATE}" "config template"

# shellcheck disable=SC1090
source "${ENV_FILE}"

SERVER_BIN="$(detect_server_bin)"

mkdir -p "${VALKEY_SERVER_DIR}" "${VALKEY_SERVER_DB_DIR}" "$(dirname "${VALKEY_SERVER_LOG_FILE}")"

if [[ -f "${VALKEY_SERVER_PID_FILE}" ]]; then
  existing_pid="$(cat "${VALKEY_SERVER_PID_FILE}")"
  if [[ -n "${existing_pid}" ]] && is_running "${existing_pid}"; then
    fail "valkey is already running with PID ${existing_pid}"
  fi
  rm -f "${VALKEY_SERVER_PID_FILE}"
fi

if port_in_use "${VALKEY_SERVER_PORT}"; then
  fail "port ${VALKEY_SERVER_PORT} is already in use"
fi

cp "${CONFIG_TEMPLATE}" "${RUNTIME_CONFIG}"

python3 - "${RUNTIME_CONFIG}" <<'PY'
import os
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
replacements = {
    "bind 127.0.0.1": f"bind {os.environ['VALKEY_SERVER_HOST']}",
    "port 6379": f"port {os.environ['VALKEY_SERVER_PORT']}",
    "loglevel notice": f"loglevel {os.environ['VALKEY_SERVER_LOG_LEVEL']}",
    "dir __VALKEY_SERVER_DB_DIR__": f"dir {os.environ['VALKEY_SERVER_DB_DIR']}",
    "pidfile __VALKEY_SERVER_PID_FILE__": f"pidfile {os.environ['VALKEY_SERVER_PID_FILE']}",
    "logfile __VALKEY_SERVER_LOG_FILE__": f"logfile {os.environ['VALKEY_SERVER_LOG_FILE']}",
}
for source, target in replacements.items():
    text = text.replace(source, target)

password = os.environ.get("VALKEY_SERVER_PASSWORD", "")
if password:
    text += f"\nrequirepass {password}\n"

path.write_text(text)
PY

log "starting valkey"
log "server bin: ${SERVER_BIN}"
log "config: ${RUNTIME_CONFIG}"
log "port: ${VALKEY_SERVER_PORT}"
log "log file: ${VALKEY_SERVER_LOG_FILE}"

nohup "${SERVER_BIN}" "${RUNTIME_CONFIG}" >>"${VALKEY_SERVER_LOG_FILE}" 2>&1 &
server_pid="$!"
echo "${server_pid}" > "${VALKEY_SERVER_PID_FILE}"
sleep 2

if ! is_running "${server_pid}"; then
  rm -f "${VALKEY_SERVER_PID_FILE}"
  fail "valkey exited immediately; check log: ${VALKEY_SERVER_LOG_FILE}"
fi

log "started with PID ${server_pid}"
