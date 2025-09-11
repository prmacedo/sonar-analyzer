#!/bin/bash

# Batch runner: executes run.sh once per env file in ./configs
# Keeps run.sh behavior unchanged (uses root .env when DOTENV is unset).

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/configs"

if [ ! -d "$CONFIG_DIR" ]; then
  echo "❌ configs directory not found at: $CONFIG_DIR"
  echo "   Run ./setup.sh and provide multiple project paths to generate configs."
  exit 1
fi

shopt -s nullglob
env_files=("$CONFIG_DIR"/*.env)
if [ ${#env_files[@]} -eq 0 ]; then
  echo "❌ No .env files found in $CONFIG_DIR"
  echo "   Expected files like $CONFIG_DIR/<project_key>.env"
  exit 1
fi

echo "[Batch] Found ${#env_files[@]} project config(s) in $CONFIG_DIR"

failed=()
for envf in "${env_files[@]}"; do
  echo -e "\n[Batch] Running analysis for: $(basename "$envf")"
  DOTENV="$envf" "$SCRIPT_DIR/run.sh"
  status=$?
  if [ $status -ne 0 ]; then
    echo "[Batch] ❌ Failed: $(basename "$envf") (exit $status)"
    failed+=("$envf")
  else
    echo "[Batch] ✅ Completed: $(basename "$envf")"
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  echo -e "\n[Batch] Completed with failures (${#failed[@]}):"
  for f in "${failed[@]}"; do echo " - $(basename "$f")"; done
  exit 1
fi

echo -e "\n[Batch] All analyses completed successfully."

