@echo off
REM Usage: run_sonar.bat <project_dir> <project_key> <username> <output_dir>

set PROJECT_DIR=%1
set PROJECT_KEY=%2
set USERNAME=%3
set OUTPUT_DIR=%4

REM Change this if your SonarQube server is not on localhost:9000
set SONAR_HOST=http://localhost:9000

REM Sonar token must be set as an environment variable in Windows
set SONAR_TOKEN=sqa_457680be2b46b20ca333c7371d1e229ccbb2f2dc

REM Adjust python path if needed (e.g., python instead of python3)
python sonar_analyze.py %PROJECT_DIR% %PROJECT_KEY% %USERNAME% %OUTPUT_DIR% ^
  --sonar-host %SONAR_HOST% ^
  --sonar-token %SONAR_TOKEN%
