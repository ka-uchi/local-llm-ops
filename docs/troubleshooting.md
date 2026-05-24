# トラブルシュート

## `llama-server binary not found`

`${HOME}/llm/llama.cpp/build/bin/llama-server` の存在を確認する。

## `valkey-server or redis-server not found`

- `scripts/start-valkey.sh` は `valkey-server` または `redis-server` を必要とする
- バイナリが別パスにある場合は [config/valkey-server.env](../config/valkey-server.env) の `VALKEY_SERVER_BIN` に絶対パスを設定する
- 導入手順は [docs/valkey-install.md](./valkey-install.md) を参照する

## `model file not found`

`config/*.env` の `MODEL_PATH` と実ファイルの場所が一致しているか確認する。

## `port ... is already in use`

- 既存サービスが起動済みの可能性がある
- `ss -ltnp` または `lsof -iTCP` で確認する

`scripts/start-valkey.sh` で `port 6379 is already in use` が出る場合:

- `snap services valkey` で `valkey.server` が `active` か確認する
- active なら snap 側の Valkey が正しく起動している
- その場合は `scripts/start-valkey.sh` を使わず、`scripts/publish-status-valkey.sh` だけを使う

## `server exited immediately`

- `~/llm/logs/*.log` を確認する
- `CUDA_VISIBLE_DEVICES` が想定どおりか確認する
- モデルサイズに対して VRAM が足りているか確認する

## ヘルスチェック失敗

- `curl http://127.0.0.1:8080/health`
- `curl http://127.0.0.1:8081/health`
- ポート待受とプロセス PID を確認する

## GPU が想定と違う

- `systemctl cat` で `Environment=CUDA_VISIBLE_DEVICES=...` を確認する
- `scripts/gpu-status.sh` で実プロセスと使用メモリを確認する
