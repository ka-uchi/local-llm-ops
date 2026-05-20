#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_ROOT}/logs"
PID_FILE="${LOG_DIR}/gemma4-31b.pid"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] [gemma4-31b] $*"
}

fail() {
  log "ERROR: $*" >&2
  exit 1
}

[[ -d "${LOG_DIR}" ]] || fail "log directory not found: ${LOG_DIR}"
[[ -f "${PID_FILE}" ]] || fail "pid file not found: ${PID_FILE}"

pid="$(cat "${PID_FILE}")"
[[ -n "${pid}" ]] || fail "pid file is empty: ${PID_FILE}"

if ! kill -0 "${pid}" 2>/dev/null; then
  rm -f "${PID_FILE}"
  fail "process ${pid} is not running; stale pid file removed"
fi

log "stopping PID ${pid}"
kill "${pid}"

for _ in {1..15}; do
  if ! kill -0 "${pid}" 2>/dev/null; then
    rm -f "${PID_FILE}"
    log "stopped"
    exit 0
  fi
  sleep 1
done

fail "process ${pid} did not stop within timeout"
