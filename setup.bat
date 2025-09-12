@echo off
setlocal EnableDelayedExpansion

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
    powershell -NoProfile -Command "Expand-Archive -Force '%SCANNER_ZIP%' '%SCANNER_DEST%'"

    :: Find first folder inside SCANNER_DEST
    set "INNER_DIR="
    for /d %%D in ("%SCANNER_DEST%\*") do (
        if not defined INNER_DIR (
            set "INNER_DIR=%%~fD"
        )
    )

    if defined INNER_DIR (
        set "SONAR_BIN=!INNER_DIR!\bin\sonar-scanner.bat"

        :: Replace \ for /
        set "SONAR_BIN_SLASH=!SONAR_BIN:\=/!"

        echo [Setup] SonarScanner extracted to: !SONAR_BIN_SLASH!
        echo SONAR_SCANNER_PATH="!SONAR_BIN_SLASH!" >> .env

        if exist "configs" (
            for %%F in ("configs\*.env") do (
                echo SONAR_SCANNER_PATH="!SONAR_BIN_SLASH!" >> "%%~fF"
            )
        )
    ) else (
        echo [Setup] Error: Could not find inner sonar-scanner folder.
    )
) else (
    echo [Setup] Warning: %SCANNER_ZIP% not found, skipping extraction.
)

echo [Setup] Done! Your settings have been written to .env.
echo          You can now run run.bat to analyze your project.
endlocal

