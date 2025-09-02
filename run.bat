@echo off
REM Usage: run_sonar.bat <project_dir> <project_key> <username> <output_dir>

:: Check if venv exists
if not exist ".venv\Scripts\activate.bat" (
    echo [Error] Virtual environment not found. Please run setup.bat first.
    exit /b 1
)

:: Activate venv
call .venv\Scripts\activate.bat

REM Change this if your SonarQube server is not on localhost:9000
set SONAR_HOST=http://localhost:9000

REM Sonar token must be set as an environment variable in Windows
set SONAR_TOKEN=sqa_8d0a8d1783d6d061234c35005c8e83fc3f7e6d7b

REM Adjust python path if needed (e.g., python instead of python3)
python sonar_analyze.py --sonar-host %SONAR_HOST% --sonar-token %SONAR_TOKEN%
