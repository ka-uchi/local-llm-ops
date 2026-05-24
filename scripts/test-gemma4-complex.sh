#!/usr/bin/env bash
set -euo pipefail

URL="http://127.0.0.1:8081/v1/chat/completions"
MODEL="gemma4-31b"
TEMPERATURE="${TEMPERATURE:-0.0}"
MAX_TOKENS="${MAX_TOKENS:-220}"

SYSTEM_PROMPT="${SYSTEM_PROMPT:-推論過程は出さず、最終回答だけを日本語で簡潔に返してください。必要なら箇条書きを使ってください。}"
USER_PROMPT="${1:-次の3つを整理してください。1. RTX 4090でQwenを動かす理由 2. RTX 3090でGemmaを動かす理由 3. 将来70Bモデルへ切り替える際の注意点。各項目を2文以内でまとめてください。}"

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not found" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found" >&2
  exit 1
fi

payload="$(
  MODEL="${MODEL}" \
  SYSTEM_PROMPT="${SYSTEM_PROMPT}" \
  USER_PROMPT="${USER_PROMPT}" \
  TEMPERATURE="${TEMPERATURE}" \
  MAX_TOKENS="${MAX_TOKENS}" \
  python3 - <<'PY'
import json
import os

print(json.dumps({
    "model": os.environ["MODEL"],
    "messages": [
        {
            "role": "system",
            "content": os.environ["SYSTEM_PROMPT"],
        },
        {
            "role": "user",
            "content": os.environ["USER_PROMPT"],
        },
    ],
    "temperature": float(os.environ["TEMPERATURE"]),
    "max_tokens": int(os.environ["MAX_TOKENS"]),
}, ensure_ascii=False))
PY
)"

curl --silent --show-error --fail \
  -H 'Content-Type: application/json' \
  -X POST "${URL}" \
  --data-binary "${payload}"
