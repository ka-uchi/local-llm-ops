#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/config/70b.env"
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/70b.log"
PID_FILE="${LOG_DIR}/70b.pid"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] [70b] $*"
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

require_cuda_visible_devices() {
  [[ -n "${CUDA_VISIBLE_DEVICES:-}" ]] || fail "CUDA_VISIBLE_DEVICES is not set; expected 0,1"
  [[ "${CUDA_VISIBLE_DEVICES}" == "0,1" ]] || fail "CUDA_VISIBLE_DEVICES must be 0,1, got ${CUDA_VISIBLE_DEVICES}"
}

mkdir -p "${LOG_DIR}"

[[ -f "${ENV_FILE}" ]] || fail "env file not found: ${ENV_FILE}"
# shellcheck disable=SC1090
source "${ENV_FILE}"

require_cmd bash
require_cuda_visible_devices
require_file "${SERVER_BIN}" "llama-server binary"
require_file "${MODEL_PATH}" "model file"

if [[ -f "${REPO_ROOT}/logs/qwen36.pid" ]] || [[ -f "${REPO_ROOT}/logs/gemma4-31b.pid" ]]; then
  fail "qwen36/gemma4-31b must be stopped before starting 70b"
fi

if [[ -f "${PID_FILE}" ]]; then
  existing_pid="$(cat "${PID_FILE}")"
  if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
    fail "70b is already running with PID ${existing_pid}"
  fi
  rm -f "${PID_FILE}"
fi

if port_in_use "${PORT}" || port_in_use 8080 || port_in_use 8081; then
  fail "required port is already in use; stop qwen/gemma and free 8090 before starting 70b"
fi

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
  --split-mode "${SPLIT_MODE}"
  --tensor-split "${TENSOR_SPLIT}"
)

if [[ -n "${CHAT_TEMPLATE:-}" ]]; then
  cmd+=(--chat-template "${CHAT_TEMPLATE}")
fi

if [[ -n "${API_KEY:-}" ]]; then
  cmd+=(--api-key "${API_KEY}")
fi

if [[ -n "${EXTRA_ARGS:-}" ]]; then
  read -r -a extra_args <<< "${EXTRA_ARGS}"
  cmd+=("${extra_args[@]}")
fi

log "starting ${MODEL_NAME}"
log "model path: ${MODEL_PATH}"
log "port: ${PORT}"
log "CUDA_VISIBLE_DEVICES: ${CUDA_VISIBLE_DEVICES}"
log "stdout/stderr log: ${LOG_FILE}"

if [[ "${RUN_FOREGROUND:-0}" == "1" ]]; then
  echo "$$" > "${PID_FILE}"
  exec "${cmd[@]}" >>"${LOG_FILE}" 2>&1
fi

require_cmd nohup
nohup "${cmd[@]}" >>"${LOG_FILE}" 2>&1 &
server_pid="$!"
echo "${server_pid}" > "${PID_FILE}"
sleep 2

if ! kill -0 "${server_pid}" 2>/dev/null; then
  rm -f "${PID_FILE}"
  fail "server exited immediately; check log: ${LOG_FILE}"
fi

log "started with PID ${server_pid}"
