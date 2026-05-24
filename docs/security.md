# セキュリティ境界

## 原則

- `llama-server` は外部公開しない
- 外部アクセスは gateway host 上の proxy / OpenClaw 経由に限定する
- inference host 上の `8080`, `8081`, `8090` は閉域用途として扱う

## 現在の設定

- Qwen / Gemma / 70B は `HOST=0.0.0.0` で待ち受け可能
- `API_KEY` は既定で空
- そのため、LAN や VPN を跨ぐ経路では firewall または上位 proxy による制御が前提

## 推奨

- LAN 内でも不要な端末からの到達は firewall で制限する
- 外部クライアントは `llama-server` に直接接続しない
- 必要に応じて `API_KEY` を設定する
- OpenClaw 側で利用可能モデルと公開範囲を絞る

## 最低限の確認項目

- `ss -ltn` で待受ポートを確認する
- `curl http://127.0.0.1:8080/health` などでローカル疎通を確認する
- LAN から到達させる場合は、意図した IP のみ開いているか確認する
