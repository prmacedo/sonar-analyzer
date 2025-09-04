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

echo "[Analyzer] Project dir: ${PROJECT_DIR:-<unset>}"
echo $SONAR_SCANNER_PATH
# Detect Flutter project
if [ -n "${PROJECT_DIR:-}" ] \
   && [ -f "$PROJECT_DIR/pubspec.yaml" ] \
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
  echo "ℹ️ Not a Flutter project (or PROJECT_DIR unset); skipping Flutter steps."
fi

# Activate virtual environment
if [ -d ".venv" ]; then
  echo "[Info] Activating virtual environment..."
  source .venv/bin/activate
else
  echo "[Error] Virtual environment not found. Please run ./setup.sh first."
  exit 1
fi

# Change if SonarQube is not on localhost:9000
SONAR_HOST="http://localhost:9000"

python3 ./sonar_analyze.py --sonar-host "$SONAR_HOST" --sonar-token "$SONAR_TOKEN"
