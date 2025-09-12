#!/bin/bash

# Usage:
# ./run_sonar.sh <project_dir> <project_key> <username> <output_dir>

# Resolve .env next to this script (works even if run from another dir)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DOTENV="${DOTENV:-"$SCRIPT_DIR/.env"}"

# Load environment variables from .env (trusted file)
if [ -f "$DOTENV" ]; then
  set -a             # auto-export all variables defined while sourcing
  # shellcheck disable=SC1090
  . "$DOTENV"        # source preserves spaces and UTF-8 chars
  set +a
else
  echo "⚠️  .env not found at: $DOTENV"
fi

# ---------- Preflight checks ----------

# Defaults
SONAR_HOST="${SONAR_HOST:-http://localhost:9000}"

missing=()

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    missing+=("$name")
  fi
}

# Required for analysis
require_var SONAR_TOKEN
require_var SONAR_PROJECT_KEY
require_var PROJECT_DIR
require_var SONAR_SCANNER_PATH
require_var USERNAME
require_var OUTPUT_DIR

if [ ${#missing[@]} -gt 0 ]; then
  echo "❌ Missing required environment variables: ${missing[*]}"
  echo "   Run ./setup.sh to configure the required variables."
  exit 1
fi

# Validate paths
if [ ! -d "$PROJECT_DIR" ]; then
  echo "❌ PROJECT_DIR does not exist or is not a directory: $PROJECT_DIR"
  exit 1
fi

if [ ! -f "$SONAR_SCANNER_PATH" ]; then
  echo "❌ SONAR_SCANNER_PATH not found: $SONAR_SCANNER_PATH"
  echo "   Re-run ./setup.sh to (re)install the scanner."
  exit 1
fi

# Ensure scanner is executable on POSIX systems
if command -v uname >/dev/null 2>&1 && [ "$(uname)" != "Windows_NT" ]; then
  chmod +x "$SONAR_SCANNER_PATH" 2>/dev/null || true
fi

# Check SonarQube availability
if command -v curl >/dev/null 2>&1; then
  status_json=$(curl -fsS -m 5 "$SONAR_HOST/api/system/status" || true)
  if [ -z "$status_json" ]; then
    echo "❌ Could not reach SonarQube at $SONAR_HOST"
    echo "   Make sure it is running (e.g., docker compose up -d) or adjust SONAR_HOST."
    exit 1
  fi
  echo "$status_json" | grep -q '"status"\s*:\s*"UP"' || {
    echo "❌ SonarQube is reachable but not UP: $status_json"
    exit 1
  }
else
  echo "⚠️ curl not found; skipping SonarQube health check."
fi

echo "[Analyzer] Sonar host: $SONAR_HOST"
echo "[Analyzer] Project dir: ${PROJECT_DIR}"
echo "[Analyzer] Scanner: ${SONAR_SCANNER_PATH}"
# Detect Flutter project
if [ -f "$PROJECT_DIR/pubspec.yaml" ] \
   && grep -q "^[[:space:]]*flutter:" "$PROJECT_DIR/pubspec.yaml"; then
  echo "✅ Detected Flutter project"
  (
    cd "$PROJECT_DIR"
    command -v flutter >/dev/null || { echo "❌ flutter not found in PATH"; exit 1; }

    echo "[Flutter] pub get…"
    flutter pub get

    echo "[Flutter] tests with coverage…"
    flutter test --machine --coverage > tests.output
  )
else
  echo "ℹ️ Not a Flutter project; skipping Flutter steps."
fi

# Activate virtual environment (relative to this repo)
if [ -d "$SCRIPT_DIR/.venv" ]; then
  echo "[Info] Activating virtual environment..."
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.venv/bin/activate"
else
  echo "[Error] Virtual environment not found. Please run ./setup.sh first."
  exit 1
fi

python3 "$SCRIPT_DIR/sonar_analyze.py" --sonar-host "$SONAR_HOST" --sonar-token "$SONAR_TOKEN"
