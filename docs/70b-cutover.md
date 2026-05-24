# 70B 切替フロー

## 目的

Qwen と Gemma の通常運用から、2 GPU 分散の 70B 運用へ切り替えるときの `cluster_mode` 更新フローを固定する。

## 前提

- `cluster_mode=single-70b` は「通常の Qwen/Gemma ルーティングを止める」ための制御状態
- `openclaw` は [docs/openclaw-valkey-contract.md](./openclaw-valkey-contract.md) の優先順位で判定する

## 切替手順

### 1. ルーティング停止を先に宣言する

```bash
scripts/set-cluster-mode.sh single-70b
scripts/valkey-dump.sh
```

確認点:

- `llm:control:cluster_mode_override = single-70b`
- `openclaw` が Qwen / Gemma を通常候補から外せる状態になる

### 2. 既存の単一 GPU モデルを停止する

```bash
scripts/stop-qwen36.sh
scripts/stop-gemma4-31b.sh
scripts/healthcheck.sh
```

### 3. 70B モデルを起動する

```bash
CUDA_VISIBLE_DEVICES=0,1 scripts/start-70b.sh
```

常駐化する場合は [systemd/llama-70b.service.example](../systemd/llama-70b.service.example) を参照する。

### 4. 状態を再 publish する

```bash
scripts/publish-status-valkey.sh
scripts/valkey-dump.sh
```

## 戻し手順

70B 運用を解除して通常運用へ戻す場合:

```bash
scripts/stop-70b.sh
scripts/clear-cluster-mode.sh
CUDA_VISIBLE_DEVICES=0 scripts/start-qwen36.sh
CUDA_VISIBLE_DEVICES=1 scripts/start-gemma4-31b.sh
scripts/publish-status-valkey.sh
scripts/valkey-dump.sh
```

## 注意

- `cluster_mode_override` は TTL なしなので、戻し忘れると `openclaw` 側の判定が固定されたままになる
- 70B 起動前に Qwen/Gemma を止めるが、ルーティング停止の宣言はそれより先に行う
- 切替中は `healthcheck` と `valkey-dump` の両方で実状態と共有状態を確認する
