# 概要

このリポジトリは、Echo-Chamber 上で `llama.cpp` を使ったローカル LLM 運用を安定化するための管理レイヤーです。

## 現在の運用

- Qwen3.6-35B-A3B: `CUDA_VISIBLE_DEVICES=0`, `port 8080`
- Gemma 4 31B IT: `CUDA_VISIBLE_DEVICES=1`, `port 8081`
- boulevard 上の proxy から OpenClaw / Discord bot が利用

## GPU 固定の考え方

- GPU 固定は `CUDA_VISIBLE_DEVICES` で行う
- `CUDA_VISIBLE_DEVICES=0` のプロセスから見える GPU は 1 枚なので `--main-gpu 0`
- `CUDA_VISIBLE_DEVICES=1` のプロセスでも、見えている GPU は 1 枚だけなので `--main-gpu 0`
- 単一 GPU 時は `--tensor-split` を使わない
- 2 GPU 分散時のみ `--split-mode layer --tensor-split ...` を使う

## 主要ポート

- `8080`: Qwen
- `8081`: Gemma
- `8090`: 将来の 70B 級モデル
