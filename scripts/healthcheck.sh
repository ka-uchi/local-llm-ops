#!/usr/bin/env bash
set -euo pipefail

QWEN_URL="http://127.0.0.1:8080/health"
GEMMA_URL="http://127.0.0.1:8081/health"

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

check_one "qwen36" "${QWEN_URL}" || status=1
check_one "gemma4-31b" "${GEMMA_URL}" || status=1

exit "${status}"
