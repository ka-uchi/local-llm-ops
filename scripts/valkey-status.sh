#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/config/valkey-server.env"

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

[[ -f "${ENV_FILE}" ]] || fail "env file not found: ${ENV_FILE}"
# shellcheck disable=SC1090
source "${ENV_FILE}"

echo "host=${VALKEY_SERVER_HOST}"
echo "port=${VALKEY_SERVER_PORT}"
echo "pid_file=${VALKEY_SERVER_PID_FILE}"
echo "log_file=${VALKEY_SERVER_LOG_FILE}"

if [[ -f "${VALKEY_SERVER_PID_FILE}" ]]; then
  pid="$(cat "${VALKEY_SERVER_PID_FILE}")"
  echo "pid=${pid}"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
    echo "process=running"
  else
    echo "process=stale-pid-file"
  fi
else
  echo "pid=missing"
  echo "process=down"
fi

if command -v ss >/dev/null 2>&1; then
  if ss -ltn "( sport = :${VALKEY_SERVER_PORT} )" 2>/dev/null | tail -n +2 | grep -q .; then
    echo "listen=up"
  else
    echo "listen=down"
  fi
else
  echo "listen=unknown"
fi
