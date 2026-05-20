# 運用手順

## 日常運用

### 手動起動

```bash
CUDA_VISIBLE_DEVICES=0 scripts/start-qwen36.sh
CUDA_VISIBLE_DEVICES=1 scripts/start-gemma4-31b.sh
```

### 手動停止

```bash
scripts/stop-qwen36.sh
scripts/stop-gemma4-31b.sh
```

### 状態確認

```bash
scripts/healthcheck.sh
scripts/gpu-status.sh
scripts/valkey-status.sh
scripts/publish-status-valkey.sh
scripts/valkey-dump.sh
```

### 定期 publish

```bash
sudo cp /home/kzkchd/llm/systemd/llm-status-publisher.service /etc/systemd/system/
sudo cp /home/kzkchd/llm/systemd/llm-status-publisher.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now llm-status-publisher.timer
```

### 簡易ベンチ

```bash
scripts/bench-qwen36.sh
scripts/bench-gemma4-31b.sh
```

## ログ

- ログ出力先は `~/llm/logs`
- 起動ログは `qwen36.log`, `gemma4-31b.log`
- PID 管理は `qwen36.pid`, `gemma4-31b.pid`

## 注意事項

- スクリプトは `CUDA_VISIBLE_DEVICES` を上書きしない
- 起動スクリプトは想定値の `CUDA_VISIBLE_DEVICES` を要求し、不一致なら失敗する
- `systemd` または呼び出し元シェルで GPU を固定する
- 単一 GPU 運用で `tensor-split` を渡さない
- モデル差し替え前に、参照プロセスが停止していることを必ず確認する

## 破壊的操作に関する扱い

破壊的操作は `scripts/` に入れない。以下の作業は手順書を見ながら明示的に実施する。

- モデルファイルの削除
- ログの一括削除
- 稼働中モデルの差し替え
- 70B 用への切替

実施前チェック:

- 停止対象サービスが本当に対象モデルか確認する
- `nvidia-smi` と `scripts/healthcheck.sh` で現状を確認する
- gateway host 側の proxy 接続先への影響を確認する
