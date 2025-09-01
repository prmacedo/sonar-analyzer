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
SCANNER_DEST="./scanners/sonar-scanner"

if [ -f "$SCANNER_ZIP" ]; then
    rm -rf "$SCANNER_DEST"
    mkdir -p "$SCANNER_DEST"
    unzip -oq "$SCANNER_ZIP" -d "$SCANNER_DEST"

    # Detect inner directory (the first folder inside SCANNER_DEST)
    INNER_DIR=$(find "$SCANNER_DEST" -mindepth 1 -maxdepth 1 -type d | head -n 1)

    # If found, set path to its bin folder
    if [ -n "$INNER_DIR" ]; then
        ABS_PATH=$(cd "$INNER_DIR" && pwd)
        SONAR_BIN="$ABS_PATH/bin/sonar-scanner"
        echo "[Setup] SonarScanner extracted to: $SONAR_BIN"
        echo "SONAR_SCANNER_PATH=\"$SONAR_BIN\"" >> .env
    else
        echo "[Setup] Error: Could not find inner sonar-scanner folder."
    fi
else
    echo "[Setup] Warning: $SCANNER_ZIP not found, skipping extraction."
fi

echo "[Setup] Done! Your settings have been written to .env."
echo "         You can now run './run.sh' to analyze your project."
