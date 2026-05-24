# OpenClaw 向け Valkey キー仕様

## 目的

`openclaw` が inference host 上のローカル LLM 稼働状態を参照し、ルーティング先と利用可否を判断できるようにする。

## 参照キー

この仕様における primary モデル一覧は [config/model-registry.yaml](/home/kzkchd/llm/config/model-registry.yaml) を基準にする。

### ノード全体

キー: `llm:node:inference-node-01`

hash 項目:

- `node_id`
- `cluster_mode`
- `updated_at`
- `publisher`

### モデル

キー:

- `llm:model:qwen36`
- `llm:model:gemma4-31b`

hash 項目:

- `node_id`
- `model_id`
- `model_name`
- `status`
- `status_reason`
- `gpu_index`
- `port`
- `health_url`
- `updated_at`

### GPU

キー:

- `llm:gpu:0`
- `llm:gpu:1`

hash 項目:

- `node_id`
- `gpu_index`
- `gpu_name`
- `memory_total_mb`
- `memory_used_mb`
- `utilization_gpu`
- `temperature_c`
- `owner_model_id`
- `updated_at`

### 制御キー

キー: `llm:control:cluster_mode_override`

型: string

値:

- `dual-single`
- `single-70b`

## 読み取り優先順位

`openclaw` は以下の順で判定する。

1. `llm:control:cluster_mode_override`
2. `llm:node:inference-node-01.cluster_mode`
3. 個別モデルの `status`

## 判定ルール

### `dual-single`

- `qwen36.status=ready` なら `:8080` を候補にする
- `gemma4-31b.status=ready` なら `:8081` を候補にする
- 片方が `down` の場合は利用可能な方だけを候補にする

### `single-70b`

- `qwen36` と `gemma4-31b` は通常のルーティング候補から外す
- 将来 `llm:model:model-70b` または `:8090` 系のキーを参照する

## TTL と鮮度

- hash キーは publisher により TTL 付きで更新される
- `updated_at` が古すぎる場合は stale とみなす
- `cluster_mode_override` は手動制御キーなので TTL を付けない

## 実装メモ

- `openclaw` 側はキー名をハードコードしてよいが、`VALKEY_HOST` と `VALKEY_PORT` は環境変数化する
- `cluster_mode_override` がある場合は、ノード hash の `cluster_mode` より常に優先する
- Chat Completions 応答では `message.content` のみを最終回答として扱う
- `reasoning_content` が返ってきても、`openclaw` 側ではユーザー向け応答として採用しない
- gateway host へ移行後もキー名と項目名は変えない
