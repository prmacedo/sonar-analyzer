#!/bin/bash

# Usage:
# ./run_sonar.sh <project_dir> <project_key> <username> <output_dir>

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
SONAR_TOKEN="sqa_8d0a8d1783d6d061234c35005c8e83fc3f7e6d7b"

python3 ./sonar_analyze.py --sonar-host "$SONAR_HOST" --sonar-token "$SONAR_TOKEN"
