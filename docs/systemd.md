# systemd 運用

## 配置

サンプル定義は `systemd/` にある。必要に応じて `/etc/systemd/system/` へ配置する。

`systemd/*.service` の以下は事前に置換する。

- `REPLACE_WITH_LOCAL_USER`
- `REPLACE_WITH_REPO_ROOT`

```bash
sudo cp ${HOME}/llm/systemd/llama-qwen36.service /etc/systemd/system/
sudo cp ${HOME}/llm/systemd/llama-gemma4-31b.service /etc/systemd/system/
sudo systemctl daemon-reload
```

## 有効化

```bash
sudo systemctl enable --now llama-qwen36.service
sudo systemctl enable --now llama-gemma4-31b.service
```

## 確認

```bash
systemctl status llama-qwen36.service
systemctl status llama-gemma4-31b.service
journalctl -u llama-qwen36.service -n 100
journalctl -u llama-gemma4-31b.service -n 100
```

## 設計意図

- Qwen サービスは `Environment=CUDA_VISIBLE_DEVICES=0`
- Gemma サービスは `Environment=CUDA_VISIBLE_DEVICES=1`
- `RUN_FOREGROUND=1` で起動スクリプトが `llama-server` を foreground 実行する
- そのため `systemd` は `Type=simple` と `Restart=on-failure` で本体プロセスを直接監視する
- そのため、手動起動時も同じ前提を再現したい場合は呼び出し側で `CUDA_VISIBLE_DEVICES` を指定する

例:

```bash
CUDA_VISIBLE_DEVICES=0 scripts/start-qwen36.sh
CUDA_VISIBLE_DEVICES=1 scripts/start-gemma4-31b.sh
```
