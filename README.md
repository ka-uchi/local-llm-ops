# ~/llm ローカルLLM運用リポジトリ

inference host 上で `llama.cpp` を使うローカル LLM 運用基盤のサンプル実装です。

このリポジトリには、現在使っている一例として以下の構成を含みます。

- Qwen3.6-35B-A3B: `RTX 4090`, `port 8080`
- Gemma 4 31B IT: `RTX 3090`, `port 8081`
- 将来の 70B 級モデル: `RTX 4090 + RTX 3090`, `port 8090`

現在は実行可能な雛形として、設定ファイル、起動停止スクリプト、systemd サンプル、運用ドキュメントを配置しています。

## ディレクトリ構成

```text
~/llm
├── config/
├── docs/
├── logs/
├── models/
├── scripts/
├── systemd/
└── llama.cpp/
```

## 運用方針

- GPU 固定は `CUDA_VISIBLE_DEVICES` で行う
- 単一 GPU 運用では `main-gpu 0` を使う
- 単一 GPU 運用では `tensor-split` を渡さない
- 2 GPU 分散時のみ `--split-mode layer` と `--tensor-split` を使う
- 起動スクリプトは `CUDA_VISIBLE_DEVICES` を上書きしない
- `systemd` 側で `Environment=CUDA_VISIBLE_DEVICES=...` を指定する

## 主要ファイル

- [config/qwen36.env](./config/qwen36.env)
- [config/gemma4-31b.env](./config/gemma4-31b.env)
- [config/model-registry.yaml](./config/model-registry.yaml)
- [config/70b.env](./config/70b.env)
- [config/valkey-server.env](./config/valkey-server.env)
- [config/valkey.conf](./config/valkey.conf)
- [scripts/start-qwen36.sh](./scripts/start-qwen36.sh)
- [scripts/start-gemma4-31b.sh](./scripts/start-gemma4-31b.sh)
- [scripts/start-70b.sh](./scripts/start-70b.sh)
- [scripts/start-valkey.sh](./scripts/start-valkey.sh)
- [scripts/healthcheck.sh](./scripts/healthcheck.sh)
- [scripts/list-models.sh](./scripts/list-models.sh)
- [systemd/llama-qwen36.service](./systemd/llama-qwen36.service)
- [systemd/llama-gemma4-31b.service](./systemd/llama-gemma4-31b.service)
- [systemd/valkey-local.service](./systemd/valkey-local.service)
- [systemd/llama-70b.service.example](./systemd/llama-70b.service.example)

## 使い方

### 1. 前提確認

- `llama.cpp/build/bin/llama-server` が存在すること
- `models/` 配下に GGUF が存在すること
- `curl` と `nvidia-smi` が使えること

### 2. 手動起動

```bash
CUDA_VISIBLE_DEVICES=0 scripts/start-qwen36.sh
CUDA_VISIBLE_DEVICES=1 scripts/start-gemma4-31b.sh
scripts/list-models.sh
```

停止:

```bash
scripts/stop-qwen36.sh
scripts/stop-gemma4-31b.sh
```

### 3. ヘルスチェックと簡易ベンチ

```bash
scripts/healthcheck.sh
scripts/bench-qwen36.sh
scripts/bench-gemma4-31b.sh
scripts/test-gemma4-complex.sh
MAX_TOKENS=512 scripts/test-gemma4-complex.sh "複雑な問い合わせ"
```

### 4. ローカル Valkey

```bash
scripts/start-valkey.sh
scripts/valkey-status.sh
scripts/publish-status-valkey.sh
```

### 5. systemd 運用

`systemd/` 配下のサンプルを `/etc/systemd/system/` に配置して使います。詳細は [docs/systemd.md](./docs/systemd.md) を参照してください。

## ドキュメント

- [docs/setup.md](./docs/setup.md)
- [docs/overview.md](./docs/overview.md)
- [docs/operations.md](./docs/operations.md)
- [docs/systemd.md](./docs/systemd.md)
- [docs/future-70b.md](./docs/future-70b.md)
- [docs/troubleshooting.md](./docs/troubleshooting.md)
- [docs/valkey.md](./docs/valkey.md)
- [docs/valkey-install.md](./docs/valkey-install.md)
- [docs/openclaw-valkey-contract.md](./docs/openclaw-valkey-contract.md)
- [docs/70b-cutover.md](./docs/70b-cutover.md)
- [docs/security.md](./docs/security.md)

## 注意

破壊的操作はスクリプト化していません。モデル差し替え、ログ削除、70B への切替などの手順は [docs/operations.md](./docs/operations.md) に注意事項付きで記載しています。
