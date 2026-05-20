#!/usr/bin/env bash
set -euo pipefail

URL="http://127.0.0.1:8080/v1/chat/completions"
MODEL="qwen36"
PROMPT="300文字以内で、現在の稼働状態を1文で説明してください。"

http_post_json() {
  local url="$1"
  local payload="$2"

  if command -v curl >/dev/null 2>&1; then
    curl --silent --show-error --fail \
      -H 'Content-Type: application/json' \
      -X POST "${url}" \
      -d "${payload}"
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "${url}" "${payload}" <<'PY'
import sys
import urllib.request

url = sys.argv[1]
payload = sys.argv[2].encode("utf-8")
request = urllib.request.Request(
    url,
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=30) as response:
    sys.stdout.buffer.write(response.read())
PY
    return
  fi

  echo "ERROR: neither curl nor python3 is available" >&2
  exit 1
}

payload="{
  \"model\": \"${MODEL}\",
  \"messages\": [
    {\"role\": \"system\", \"content\": \"簡潔に日本語で答えてください。\"},
    {\"role\": \"user\", \"content\": \"${PROMPT}\"}
  ],
  \"temperature\": 0.2,
  \"max_tokens\": 120
}"

start_ns="$(date +%s%N)"

response="$(http_post_json "${URL}" "${payload}")"

end_ns="$(date +%s%N)"
elapsed_ms="$(( (end_ns - start_ns) / 1000000 ))"

echo "elapsed_ms=${elapsed_ms}"
echo "${response}"
