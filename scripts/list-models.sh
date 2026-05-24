#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REGISTRY_TOOL="${REPO_ROOT}/scripts/model-registry.py"

if [[ ! -x "${REGISTRY_TOOL}" ]]; then
  echo "ERROR: registry tool not executable: ${REGISTRY_TOOL}" >&2
  exit 1
fi

printf 'id\trole\tport\tenv_file\n'
"${REGISTRY_TOOL}" list
