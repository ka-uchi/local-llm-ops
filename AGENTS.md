# AGENTS.md

このディレクトリは inference host 上のローカル LLM 運用管理を目的とする。

## 目的

- `llama.cpp` ベースの常用モデル運用
- Qwen3.6-35B-A3B を `RTX 4090` に固定
- Gemma 4 31B IT を `RTX 3090` に固定
- 将来は 70B 級モデルを 2 GPU 分散で起動
- gateway host 上の proxy / OpenClaw / Discord bot から利用

## 変更方針

- ドキュメントは日本語で書く
- bash スクリプトは `set -euo pipefail` を使う
- 実行前に前提条件の存在確認を行う
- エラーは即時終了し、原因が分かるメッセージを出す
- ログは `~/llm/logs` に集約する
- 単一 GPU 起動では `tensor-split` を使わない
- 2 GPU 分散時のみ `--split-mode layer` と `--tensor-split` を使う
- `CUDA_VISIBLE_DEVICES` は原則 `systemd` 側で指定する

## ファイル配置ルール

- `config/`: モデルごとの env とレジストリ
- `config/valkey.env`: inference host 上の暫定状態ストア設定
- `config/valkey-server.env`: inference host 上のローカル Valkey サーバ設定
- `config/70b.env`: 将来の 70B 起動設定
- `scripts/`: 起動停止、ヘルスチェック、GPU 状態確認、ベンチ
- `systemd/`: サービス定義サンプル
- `docs/`: 運用手順、注意点、将来拡張
- `docs/openclaw-valkey-contract.md`: openclaw 側が参照するキー仕様
- `scripts/model-registry.py`: model-registry.yaml を読む共通ツール
- `llama.cpp/` と `models/` はトップレベル git 管理対象外。再現性は setup 手順で担保する

## 安全方針

- 破壊的操作は `scripts/` に入れない
- モデル削除や大規模切替の手順は `docs/` にのみ書く
- 既存の `llama.cpp` や `models/` 配置は勝手に変更しない
