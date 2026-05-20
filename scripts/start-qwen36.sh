#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/config/qwen36.env"
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/qwen36.log"
PID_FILE="${LOG_DIR}/qwen36.pid"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] [qwen36] $*"
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

require_cuda_visible_devices() {
  local expected="$1"
  [[ -n "${CUDA_VISIBLE_DEVICES:-}" ]] || fail "CUDA_VISIBLE_DEVICES is not set; expected ${expected}"
  [[ "${CUDA_VISIBLE_DEVICES}" == "${expected}" ]] || fail "CUDA_VISIBLE_DEVICES must be ${expected}, got ${CUDA_VISIBLE_DEVICES}"
}

port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn "( sport = :${port} )" 2>/dev/null | tail -n +2 | grep -q .
  elif command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
  else
    fail "neither ss nor lsof is available for port check"
  fi
}

mkdir -p "${LOG_DIR}"
require_cmd nohup
require_cmd bash

[[ -f "${ENV_FILE}" ]] || fail "env file not found: ${ENV_FILE}"
# shellcheck disable=SC1090
source "${ENV_FILE}"

require_cuda_visible_devices "0"

require_file "${SERVER_BIN}" "llama-server binary"
require_file "${MODEL_PATH}" "model file"

if [[ -f "${PID_FILE}" ]]; then
  existing_pid="$(cat "${PID_FILE}")"
  if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
    fail "qwen36 is already running with PID ${existing_pid}"
  fi
  rm -f "${PID_FILE}"
fi

if port_in_use "${PORT}"; then
  fail "port ${PORT} is already in use"
fi

log "starting ${MODEL_NAME}"
log "repo root: ${REPO_ROOT}"
log "server bin: ${SERVER_BIN}"
log "model path: ${MODEL_PATH}"
log "port: ${PORT}"
log "CUDA_VISIBLE_DEVICES: ${CUDA_VISIBLE_DEVICES:-<unset>}"
log "stdout/stderr log: ${LOG_FILE}"

declare -a cmd=(
  "${SERVER_BIN}"
  --host "${HOST}"
  --port "${PORT}"
  --model "${MODEL_PATH}"
  --alias "${ALIAS}"
  --ctx-size "${CTX_SIZE}"
  --batch-size "${BATCH_SIZE}"
  --ubatch-size "${UBATCH_SIZE}"
  --gpu-layers "${GPU_LAYERS}"
  --threads "${THREADS}"
  --parallel "${PARALLEL}"
  --main-gpu "${MAIN_GPU}"
  --chat-template "${CHAT_TEMPLATE}"
)

if [[ -n "${API_KEY:-}" ]]; then
  cmd+=(--api-key "${API_KEY}")
fi

if [[ -n "${EXTRA_ARGS:-}" ]]; then
  # EXTRA_ARGS is intentionally split on shell words to keep env configuration simple.
  read -r -a extra_args <<< "${EXTRA_ARGS}"
  cmd+=("${extra_args[@]}")
fi

nohup "${cmd[@]}" >>"${LOG_FILE}" 2>&1 &

server_pid="$!"
echo "${server_pid}" > "${PID_FILE}"
sleep 2

if ! kill -0 "${server_pid}" 2>/dev/null; then
  rm -f "${PID_FILE}"
  fail "server exited immediately; check log: ${LOG_FILE}"
fi

log "started with PID ${server_pid}"
