#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REGISTRY_TOOL="${REPO_ROOT}/scripts/model-registry.py"

[[ -x "${REGISTRY_TOOL}" ]] || {
  echo "ERROR: registry tool not executable: ${REGISTRY_TOOL}" >&2
  exit 1
}

http_get() {
  local url="$1"

  if command -v curl >/dev/null 2>&1; then
    curl --silent --show-error --fail --max-time 5 "${url}"
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "${url}" <<'PY'
import sys
import urllib.request

url = sys.argv[1]
with urllib.request.urlopen(url, timeout=5) as response:
    sys.stdout.buffer.write(response.read())
PY
    return
  fi

  echo "ERROR: neither curl nor python3 is available" >&2
  exit 1
}

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

check_one() {
  local name="$1"
  local url="$2"

  echo "[$(timestamp)] checking ${name}: ${url}"
  if http_get "${url}" >/dev/null; then
    echo "[$(timestamp)] ${name}: OK"
  else
    echo "[$(timestamp)] ${name}: NG" >&2
    return 1
  fi
}

status=0

while IFS=$'\t' read -r model_id host port; do
  check_one "${model_id}" "http://${host}:${port}/health" || status=1
done < <("${REGISTRY_TOOL}" health-targets)

exit "${status}"
