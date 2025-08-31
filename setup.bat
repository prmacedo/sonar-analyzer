@echo off
setlocal
set "SCANNER_ZIP=scanners\scanner.zip"
set "SCANNER_DEST=scanners"

echo [Setup] Creating virtual environment...
python -m venv .venv

echo [Setup] Activating virtual environment...
call .venv\Scripts\activate

echo [Setup] Installing dependencies...
pip install --upgrade pip
pip install -r requirements.txt

echo [Setup] Running setup_sonar.py...
python setup_sonar.py

echo [Setup] Deactivating virtual environment...
call .venv\Scripts\deactivate.bat

:: ----------- Unzip scanner.zip -----------
if exist "%SCANNER_ZIP%" (
    if not exist "%SCANNER_DEST%" mkdir "%SCANNER_DEST%"
    powershell -Command "Expand-Archive -Force '%SCANNER_ZIP%' '%SCANNER_DEST%'"

    :: Get absolute path
    for %%I in ("%SCANNER_DEST%") do set ABS_PATH=%%~fI
    echo [Setup] SonarScanner extracted to: %ABS_PATH%

    :: Save to .env
    echo SONAR_SCANNER_PATH="%ABS_PATH%\bin\sonar-scanner.bat" >> .env
) else (
    echo [Setup] Warning: %SCANNER_ZIP% not found, skipping extraction.
)

echo [Setup] Done! Your settings have been written to .env.
echo          You can now run run.bat to analyze your project.
endlocal
