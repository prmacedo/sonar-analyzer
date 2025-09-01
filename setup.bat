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
    rmdir /s /q "%SCANNER_DEST%" 2>nul
    mkdir "%SCANNER_DEST%"
    powershell -Command "Expand-Archive -Force '%SCANNER_ZIP%' '%SCANNER_DEST%'"

    :: Find first folder inside SCANNER_DEST
    for /d %%D in ("%SCANNER_DEST%\*") do (
        set "INNER_DIR=%%~fD"
        goto founddir
    )
    :founddir

    if defined INNER_DIR (
        set "SONAR_BIN=%INNER_DIR%\bin\sonar-scanner.bat"
        echo [Setup] SonarScanner extracted to: %SONAR_BIN%
        echo SONAR_SCANNER_PATH="%SONAR_BIN%" >> .env
    ) else (
        echo [Setup] Error: Could not find inner sonar-scanner folder.
    )
) else (
    echo [Setup] Warning: %SCANNER_ZIP% not found, skipping extraction.
)

echo [Setup] Done! Your settings have been written to .env.
echo          You can now run run.bat to analyze your project.
endlocal
