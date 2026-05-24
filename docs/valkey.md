# Valkey 暫定運用

## 目的

当面は `inference host` 側に `valkey` を置き、`openclaw` から参照するモデル状態を一元化する。

この構成では、推論実体と状態更新元が同居するため、初期実装を最短で立ち上げやすい。

## 位置づけ

- `llama.cpp` / `systemd`: 実プロセスの起動停止を担当
- `publish-status-valkey.sh`: 実状態を `valkey` に反映
- `openclaw` / proxy / bot: `valkey` を読んでルーティング判断

`valkey` は「共有状態ストア」であり、実プロセスの権威そのものではない。真の状態は常に `healthcheck` と GPU 実測から取る。

## 当面の配置

- `valkey`: inference host 上
- 参照先: gateway host 上の `openclaw`
- 将来: gateway host に移設しても、キー設計は維持する

## キー設計

### ノード全体

- `llm:node:inference-node-01`
  - `node_id`
  - `cluster_mode`
  - `updated_at`
  - `publisher`

### モデル状態

- `llm:model:qwen36`
- `llm:model:gemma4-31b`

格納項目:

- `node_id`
- `model_id`
- `model_name`
- `status`
- `status_reason`
- `gpu_index`
- `port`
- `health_url`
- `updated_at`

### GPU 状態

- `llm:gpu:0`
- `llm:gpu:1`

格納項目:

- `node_id`
- `gpu_index`
- `gpu_name`
- `memory_total_mb`
- `memory_used_mb`
- `utilization_gpu`
- `temperature_c`
- `owner_model_id`
- `updated_at`

## ステータス定義

- `ready`: `/health` が成功
- `down`: 接続失敗またはタイムアウト
- `unknown`: 判定不能

## 更新方式

`scripts/publish-status-valkey.sh` が以下を実施する。

1. `8080` と `8081` の `/health` を確認
2. `nvidia-smi` から GPU の基本状態を取得
3. `valkey` に hash と TTL を書き込む

対象モデル一覧は [config/model-registry.yaml](../config/model-registry.yaml) の primary モデルから取得する。

TTL を付けることで、publisher が止まった場合に古い状態が残り続けないようにする。

## 設定

設定ファイルは [config/valkey.env](../config/valkey.env) を使う。

主な項目:

- `VALKEY_HOST`
- `VALKEY_PORT`
- `VALKEY_DB`
- `KEY_PREFIX`
- `STATUS_TTL_SECONDS`

## 実行

単発更新:

```bash
scripts/publish-status-valkey.sh
```

systemd timer で定期更新:

```bash
sudo cp /home/kzkchd/llm/systemd/llm-status-publisher.service /etc/systemd/system/
sudo cp /home/kzkchd/llm/systemd/llm-status-publisher.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now llm-status-publisher.timer
```

## gateway host への移行方針

後で `valkey` を gateway host に移す場合も、以下は変えない。

- キー名
- hash の項目名
- `openclaw` 側の参照ロジック

変更対象は次だけに留める。

- `VALKEY_HOST`
- `VALKEY_PORT`
- 必要なら認証情報

## 注意

- `valkey` に書かれた状態だけを絶対視しない
- 70B 切替時は `cluster_mode` を先に更新し、`openclaw` の振り先を整合させる
- publisher が失敗した場合は `journalctl` または標準エラーを確認する
