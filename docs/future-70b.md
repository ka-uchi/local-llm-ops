# 将来の 70B 級モデル運用

## 目的

Qwen と Gemma を停止し、`RTX 4090 + RTX 3090` の 2 GPU を束ねて 70B 級モデルを起動できるようにする。

## 前提

- `CUDA_VISIBLE_DEVICES=0,1`
- `--main-gpu 0`
- `--split-mode layer`
- `--tensor-split 1,1`
- `port 8090`

## 注意

- 単一 GPU 用スクリプトを流用しない
- 2 GPU 分散はメモリ使用量と分割比の再調整が必要
- 稼働中の Qwen / Gemma を止めてから起動する
- gateway host 側 proxy の接続先切替も合わせて行う

## 雛形

サービス雛形は [systemd/llama-70b.service.example](/home/kzkchd/llm/systemd/llama-70b.service.example) を参照。

実行雛形:

- [config/70b.env](/home/kzkchd/llm/config/70b.env)
- [scripts/start-70b.sh](/home/kzkchd/llm/scripts/start-70b.sh)
- [scripts/stop-70b.sh](/home/kzkchd/llm/scripts/stop-70b.sh)

## 今後追加したいもの

- split 比較用のベンチマーク手順
