#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LLAMA_DIR="${REPO_ROOT}/llama.cpp"
LLAMA_REPO_URL="https://github.com/ggml-org/llama.cpp.git"
LLAMA_COMMIT="1a68ec93781c9014ac0a1e174887ae703c6deaf8"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] [setup-llama-cpp] $*"
}

fail() {
  log "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  local name="$1"
  command -v "${name}" >/dev/null 2>&1 || fail "required command not found: ${name}"
}

require_cmd git
require_cmd cmake

if [[ -e "${LLAMA_DIR}" ]] && [[ ! -d "${LLAMA_DIR}/.git" ]]; then
  fail "existing ${LLAMA_DIR} is not a git checkout"
fi

if [[ ! -d "${LLAMA_DIR}/.git" ]]; then
  log "cloning llama.cpp"
  git clone "${LLAMA_REPO_URL}" "${LLAMA_DIR}"
else
  log "existing llama.cpp checkout found"
fi

log "fetching target commit ${LLAMA_COMMIT}"
git -C "${LLAMA_DIR}" fetch --tags origin
git -C "${LLAMA_DIR}" checkout "${LLAMA_COMMIT}"

log "configuring build"
cmake -S "${LLAMA_DIR}" -B "${LLAMA_DIR}/build" -DGGML_CUDA=ON

log "building llama-server"
cmake --build "${LLAMA_DIR}/build" --config Release -j

[[ -x "${LLAMA_DIR}/build/bin/llama-server" ]] || fail "llama-server not found after build"

log "completed"
log "repo: ${LLAMA_REPO_URL}"
log "commit: ${LLAMA_COMMIT}"
log "binary: ${LLAMA_DIR}/build/bin/llama-server"
