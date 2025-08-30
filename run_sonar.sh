#!/bin/bash

# Usage:
# ./run_sonar.sh <project_dir> <project_key> <username> <output_dir>

PROJECT_DIR="$1"
PROJECT_KEY="$2"
USERNAME="$3"
OUTPUT_DIR="$4"

# Change if SonarQube is not on localhost:9000
SONAR_HOST="http://localhost:9000"
SONAR_TOKEN="sqa_457680be2b46b20ca333c7371d1e229ccbb2f2dc"

python3 ./sonar_analyze.py "$PROJECT_DIR" "$PROJECT_KEY" "$USERNAME" "$OUTPUT_DIR" \
  --sonar-host "$SONAR_HOST" \
  --sonar-token "$SONAR_TOKEN"
