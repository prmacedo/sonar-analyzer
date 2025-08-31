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

echo "[Setup] Deactivating virtual environment..."
deactivate

# ----------- Unzip scanner.zip -----------
SCANNER_ZIP="./scanners/scanner.zip"
SCANNER_DEST="./scanners"

if [ -f "$SCANNER_ZIP" ]; then
    mkdir -p "$SCANNER_DEST"
    unzip -oq "$SCANNER_ZIP" -d "$SCANNER_DEST"

    # Restore executable permissions
    if [[ "$OSTYPE" != "msys"* && "$OSTYPE" != "win32" ]]; then
        chmod -R 755 "$SCANNER_DEST"/*
    fi

    # Get absolute path
    ABS_PATH=$(cd "$SCANNER_DEST" && pwd)
    echo "[Setup] SonarScanner extracted to: $ABS_PATH"

    # Save to .env
    echo "SONAR_SCANNER_PATH=\"$ABS_PATH/bin/sonar-scanner\"" >> .env
else
    echo "[Setup] Warning: $SCANNER_ZIP not found, skipping extraction."
fi

echo "[Setup] Done! Your settings have been written to .env."
echo "         You can now run './run.sh' to analyze your project."
