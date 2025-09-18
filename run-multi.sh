#!/bin/bash

# Batch runner: executes run.sh once per env file in ./configs
# Keeps run.sh behavior unchanged (uses root .env when DOTENV is unset).

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/configs"

# ---- SonarQube readiness gate (handles boot race with Docker) ----
# Allows overrides via env vars if needed.
SONAR_HOST="${SONAR_HOST:-http://localhost:9000}"
SONAR_CONTAINER_NAME="${SONAR_CONTAINER_NAME:-sa_sonarqube}"
SONAR_UP_TIMEOUT="${SONAR_UP_TIMEOUT:-120}"        # seconds to wait for UP
SONAR_UP_RETRY_AFTER="${SONAR_UP_RETRY_AFTER:-300}" # seconds to defer if not ready

log() { echo "[Prereq] $*"; }

docker_available() {
  command -v docker >/dev/null 2>&1 || return 1
  docker info >/dev/null 2>&1 || return 1
}

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -Fxq "$SONAR_CONTAINER_NAME"
}

container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$SONAR_CONTAINER_NAME" 2>/dev/null || echo false)" = "true" ]
}

sonar_up_http() {
  command -v curl >/dev/null 2>&1 || return 1
  local j
  j=$(curl -fsS -m 5 "$SONAR_HOST/api/system/status" 2>/dev/null || true)
  echo "$j" | grep -q '"status"\s*:\s*"UP"'
}

wait_for_sonarqube() {
  local waited=0 interval=3
  log "Ensuring SonarQube is UP at $SONAR_HOST (timeout ${SONAR_UP_TIMEOUT}s)"

  while [ $waited -lt "$SONAR_UP_TIMEOUT" ]; do
    # Prefer container state when Docker is available
    if docker_available && container_exists; then
      if container_running && sonar_up_http; then
        log "Container '$SONAR_CONTAINER_NAME' running and API is UP."
        return 0
      fi
    else
      # Fallback to HTTP only (works for remote or non-Docker setups)
      if sonar_up_http; then
        log "SonarQube API reports UP."
        return 0
      fi
    fi
    sleep "$interval"
    waited=$((waited + interval))
  done
  return 1
}

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

# Ensure SonarQube is ready (wait, or defer once by 5 minutes)
if ! wait_for_sonarqube; then
  log "SonarQube not ready; deferring ${SONAR_UP_RETRY_AFTER}s then retrying once..."
  sleep "$SONAR_UP_RETRY_AFTER"
  if ! wait_for_sonarqube; then
    echo "❌ SonarQube service is not UP after waiting. Aborting batch."
    echo "   Checked container '$SONAR_CONTAINER_NAME' and $SONAR_HOST/api/system/status"
    exit 1
  fi
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
