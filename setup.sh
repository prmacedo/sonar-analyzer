#!/bin/bash
set -e

echo "[Setup] Creating virtual environment..."
python3 -m venv .venv

echo "[Setup] Activating virtual environment..."
source .venv/bin/activate

echo "[Setup] Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "[Setup] Running setup_sonar.py..."
python setup_sonar.py

echo "[Setup] Done! Your settings have been written to .env."
echo "         You can now run './run.sh' to analyze your project."
