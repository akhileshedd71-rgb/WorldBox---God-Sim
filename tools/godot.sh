#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$repo_root/.local/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$repo_root/.local/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$repo_root/.local/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
engine="${GODOT_BIN:-godot}"
exec "$engine" --path "$repo_root" "$@"
