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

[[ -f "${VALKEY_SERVER_PID_FILE}" ]] || fail "pid file not found: ${VALKEY_SERVER_PID_FILE}"
pid="$(cat "${VALKEY_SERVER_PID_FILE}")"
[[ -n "${pid}" ]] || fail "pid file is empty: ${VALKEY_SERVER_PID_FILE}"

if ! kill -0 "${pid}" 2>/dev/null; then
  rm -f "${VALKEY_SERVER_PID_FILE}"
  fail "process ${pid} is not running; stale pid file removed"
fi

log "stopping PID ${pid}"
kill "${pid}"

for _ in {1..15}; do
  if ! kill -0 "${pid}" 2>/dev/null; then
    rm -f "${VALKEY_SERVER_PID_FILE}"
    log "stopped"
    exit 0
  fi
  sleep 1
done

fail "process ${pid} did not stop within timeout"
