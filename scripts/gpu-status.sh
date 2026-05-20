#!/usr/bin/env bash
set -euo pipefail

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "ERROR: nvidia-smi not found" >&2
  exit 1
fi

echo "[GPU summary]"
nvidia-smi --query-gpu=index,name,uuid,memory.total,memory.used,utilization.gpu,temperature.gpu --format=csv

echo
echo "[Compute processes]"
nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv,noheader || true
