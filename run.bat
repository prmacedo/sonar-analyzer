@echo off
setlocal EnableExtensions

REM Resolve script directory (with trailing backslash)
set "SCRIPT_DIR=%~dp0"

REM Activate virtual environment (relative to this repo)
if not exist "%SCRIPT_DIR%.venv\Scripts\activate.bat" (
  echo [Error] Virtual environment not found. Please run setup.bat first.
  exit /b 1
)
call "%SCRIPT_DIR%.venv\Scripts\activate.bat"

REM Optional: respect existing SONAR_HOST or just rely on Python defaults
if not defined SONAR_HOST set "SONAR_HOST=http://localhost:9000"

REM Run analyzer; sonar_analyze.py loads .env/DOTENV itself and validates env.
python "%SCRIPT_DIR%sonar_analyze.py" --sonar-host "%SONAR_HOST%"
set "_exit=%ERRORLEVEL%"

REM Deactivate venv (optional)
if exist "%SCRIPT_DIR%.venv\Scripts\deactivate.bat" call "%SCRIPT_DIR%.venv\Scripts\deactivate.bat"

exit /b %_exit%
