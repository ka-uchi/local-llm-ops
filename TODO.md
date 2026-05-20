# TODO

## 優先

- `openclaw` 側の Valkey 読み取り実装を着手する
- boulevard 側の `VALKEY_HOST` / `VALKEY_PORT` 切替方法を固定する
- 70B 用の `config/70b.env` を追加する
- 70B 用の `scripts/start-70b.sh` と `scripts/stop-70b.sh` を追加する
- 70B 起動後の `llm:model:model-70b` キー仕様を追加する

## 運用改善

- `publish-status-valkey.sh` の GPU 取得失敗時ログを明示化する
- `valkey-dump.sh` の出力を hash 配列ではなく key-value 形式でも見やすくする
- `healthcheck.sh` に待受ポート情報の補助出力を追加する
- `bench-*.sh` の結果保存先を `logs/` に切り替えるか検討する
- systemd サービス群の `EnvironmentFile=` 化を検討する

## openclaw 連携

- `cluster_mode_override` を `openclaw` が最優先で参照するようにする
- `dual-single` 時のモデル選択ルールを `openclaw` 側コードに実装する
- `single-70b` 時の通常ルーティング停止を `openclaw` 側で実装する
- stale な `updated_at` を弾く基準秒数を `openclaw` 側で決める

## Git 管理メモ

- `~/llm` トップレベルは git 管理する
- `llama.cpp` は内部に独自 `.git` を持つ
- `llama.cpp` をどう扱うかは次のいずれかに決める
- サブモジュールとして扱う
- vendor ディレクトリとして `.git` を外して取り込む
- トップレベル repo からは除外してローカル依存として扱う

## 将来

- boulevard 側へ Valkey を移設する
- `proxy` / Discord bot / OpenClaw の経路ごとの利用制限を設計する
- 70B と常用モデルの切替自動化を検討する
