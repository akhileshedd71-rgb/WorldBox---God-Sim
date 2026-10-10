#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_runtime="$(mktemp -d)"
trap 'rm -rf -- "$test_runtime"' EXIT
export XDG_DATA_HOME="$test_runtime/data"
export XDG_CONFIG_HOME="$test_runtime/config"
export XDG_CACHE_HOME="$test_runtime/cache"
run_check() {
  local log_file
  log_file="$(mktemp)"
  if "$repo_root/tools/godot.sh" "$@" >"$log_file" 2>&1; then
    if rg -q 'SCRIPT ERROR:|^ERROR:' "$log_file"; then
      cat "$log_file"
      rm -f "$log_file"
      return 1
    fi
    cat "$log_file"
    rm -f "$log_file"
  else
    local result=$?
    cat "$log_file"
    rm -f "$log_file"
    return "$result"
  fi
}
run_check --headless --editor --import --quit
run_check --headless --script res://tests/run_tests.gd
run_check --headless --script res://tests/test_economy.gd
run_check --headless --script res://tests/test_politics.gd
run_check --headless --script res://tests/test_military.gd
run_check --headless --script res://tests/test_heredity.gd
run_check --headless --script res://tests/test_environment.gd
run_check --headless --script res://tests/test_society.gd
run_check --headless --script res://tests/test_beta.gd
run_check --headless --script res://tests/test_ui.gd
run_check --headless --script res://tests/test_life_ui.gd
run_check --headless --script res://tests/test_environment_ui.gd
run_check --headless --script res://tests/test_society_ui.gd
run_check --headless --script res://tests/test_beta_ui.gd
run_check --headless --script res://tools/startup_smoke.gd
