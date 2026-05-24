# Valkey 導入手順

## 前提

このリポジトリ側では、`valkey-server` または `redis-server` 互換バイナリが入っている前提で起動する。

現時点の `~/llm` 実装は以下を持つ。

- [config/valkey-server.env](../config/valkey-server.env)
- [config/valkey.conf](../config/valkey.conf)
- [scripts/start-valkey.sh](../scripts/start-valkey.sh)
- [scripts/stop-valkey.sh](../scripts/stop-valkey.sh)
- [scripts/valkey-status.sh](../scripts/valkey-status.sh)
- [systemd/valkey-local.service](../systemd/valkey-local.service)

## バイナリ検出ルール

`start-valkey.sh` は次の順で実行バイナリを探す。

1. `config/valkey-server.env` の `VALKEY_SERVER_BIN`
2. `valkey-server`
3. `redis-server`
4. `/snap/bin/valkey*` または `/snap/bin/redis*`

## Ubuntu Core / snap での導入

このホストでは `apt` 系ではなく `snap` が前提になる。2026-05-21 時点で `snap info valkey` の公開 channel は `9.0-26.04/edge` だった。

導入コマンド:

```bash
sudo snap install valkey --channel=9.0-26.04/edge
```

導入後の確認:

```bash
snap list valkey
snap services valkey
ls -la /snap/bin | rg '^valkey'
```

`start-valkey.sh` が自動検出できない場合は、実行ファイルの実パスを [config/valkey-server.env](../config/valkey-server.env) の `VALKEY_SERVER_BIN` に設定する。

## 導入後の初回確認

```bash
snap services valkey
scripts/valkey-status.sh
scripts/publish-status-valkey.sh
```

`valkey.server` が `active` なら、snap 側のサービスが既に `6379` を提供している。その場合は `scripts/start-valkey.sh` を使わず、snap 管理の Valkey をそのまま利用する。

## systemd 登録

```bash
sudo cp /home/kzkchd/llm/systemd/valkey-local.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now valkey-local.service
```

ただし、snap 版 `valkey.server` を使う場合は `valkey-local.service` を登録しない。二重起動になり `6379` が競合する。

publisher timer も使う場合:

```bash
sudo cp /home/kzkchd/llm/systemd/llm-status-publisher.service /etc/systemd/system/
sudo cp /home/kzkchd/llm/systemd/llm-status-publisher.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now llm-status-publisher.timer
```

snap 版 Valkey を使っている現在の構成では、publisher service は `snap.valkey.server.service` の起動後に走るようにしてある。

有効化後の確認:

```bash
systemctl status llm-status-publisher.timer
systemctl status llm-status-publisher.service
systemctl list-timers | grep llm-status-publisher
journalctl -u llm-status-publisher.service -n 50
```

## 設定変更

- bind / port / password: [config/valkey-server.env](../config/valkey-server.env)
- 永続化設定: [config/valkey.conf](../config/valkey.conf)

## 注意

- gateway host へ移行後は `valkey-local.service` を停止する
- 移行前に `config/valkey.env` の `VALKEY_HOST` を変更し、publisher の書き込み先を切り替える
- 推論プロセスより `valkey` を先に起動しておくと状態 publish が安定する
- `snap services valkey` で `valkey.server` が `active` の場合、ローカル起動スクリプトとは併用しない
