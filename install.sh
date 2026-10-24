#!/usr/bin/env bash
# Link this project into the places its tools expect. Existing files are kept as *.bak.
set -eu
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
link() { mkdir -p "$(dirname "$2")"; [ -e "$2" ] && [ ! -L "$2" ] && mv "$2" "$2.bak"; ln -sfn "$1" "$2"; echo "$2 -> $1"; }
link "$ROOT/bin/model-bench" ~/.local/bin/model-bench
link "$ROOT/bin/swap" ~/.local/bin/swap
link "$ROOT/bin/model-stats" ~/.local/bin/model-stats
link "$ROOT/bin/model-failures" ~/.local/bin/model-failures
link "$ROOT/bin/model-purge" ~/.local/bin/model-purge
link "$ROOT/bin/model-recheck" ~/.local/bin/model-recheck
link "$ROOT/llama-swap/config.yaml" ~/.config/llama-swap/config.yaml
command -v llama-swap >/dev/null || echo "missing: llama-swap (put the binary in ~/.local/bin)"
[ -x ~/Github/llama.cpp/build/bin/llama-server ] || echo "missing: ~/Github/llama.cpp/build/bin/llama-server"
command -v claude >/dev/null || echo "missing: claude CLI"
