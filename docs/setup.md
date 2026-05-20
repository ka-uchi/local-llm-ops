# セットアップ

## 方針

このリポジトリでは `llama.cpp/` と `models/` を git 管理しない。

再現性は以下で担保する。

- `llama.cpp` は固定 commit で取得する
- build 手順は [scripts/setup-llama-cpp.sh](/home/kzkchd/llm/scripts/setup-llama-cpp.sh) に固定する
- モデルファイルの配置先と名前は `config/*.env` に固定する

## 対象コミット

- `llama.cpp`: `1a68ec93781c9014ac0a1e174887ae703c6deaf8`

## 前提

- `git`
- `cmake`
- CUDA build に必要な開発環境
- モデルファイルを `~/llm/models/` に配置できること

## llama.cpp の取得と build

```bash
scripts/setup-llama-cpp.sh
```

このスクリプトは次を行う。

1. `https://github.com/ggml-org/llama.cpp.git` を `~/llm/llama.cpp` へ clone
2. 固定 commit `1a68ec93781c9014ac0a1e174887ae703c6deaf8` へ checkout
3. `cmake -DGGML_CUDA=ON` で configure
4. `build/bin/llama-server` を build

## モデル配置

現在の前提:

- Qwen: `/home/kzkchd/llm/models/Qwen3.6-35B-A3B-GGUF/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf`
- Gemma: `/home/kzkchd/llm/models/gemma-4-31b-it/google_gemma-4-31B-it-Q4_K_M.gguf`

配置後は以下を確認する。

```bash
CUDA_VISIBLE_DEVICES=0 scripts/start-qwen36.sh
CUDA_VISIBLE_DEVICES=1 scripts/start-gemma4-31b.sh
scripts/healthcheck.sh
```

## 注意

- `llama.cpp/` はトップレベル git repo の管理対象外
- `models/` も管理対象外
- `llama.cpp` を更新したい場合は、先に固定 commit を更新してから `scripts/setup-llama-cpp.sh` を再実行する
