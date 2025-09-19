@echo off
setlocal EnableExtensions

REM Resolve script directory (with trailing backslash)
set "SCRIPT_DIR=%~dp0"

REM ---- SonarQube readiness gate (handles boot race with Docker) ----
if not defined SONAR_HOST set "SONAR_HOST=http://localhost:9000"
if not defined SONAR_CONTAINER_NAME set "SONAR_CONTAINER_NAME=sa_sonarqube"
if not defined SONAR_UP_TIMEOUT set "SONAR_UP_TIMEOUT=120"
if not defined SONAR_UP_RETRY_AFTER set "SONAR_UP_RETRY_AFTER=300"

call :ensure_sonar_ready || (
  echo [Error] SonarQube not ready after waits. Aborting.
  exit /b 1
)

REM Activate virtual environment (relative to this repo)
if not exist "%SCRIPT_DIR%.venv\Scripts\activate.bat" (
  echo [Error] Virtual environment not found. Please run setup.bat first.
  exit /b 1
)
call "%SCRIPT_DIR%.venv\Scripts\activate.bat"

REM SONAR_HOST already set above if missing

REM Run analyzer; sonar_analyze.py loads .env/DOTENV itself and validates env.
python "%SCRIPT_DIR%sonar_analyze.py" --sonar-host "%SONAR_HOST%"
set "_exit=%ERRORLEVEL%"

REM Deactivate venv (optional)
if exist "%SCRIPT_DIR%.venv\Scripts\deactivate.bat" call "%SCRIPT_DIR%.venv\Scripts\deactivate.bat"

exit /b %_exit%

goto :eof

REM ---------- helpers ----------
:ensure_sonar_ready
  call :wait_for_sonarqube
  if errorlevel 1 (
    echo [Prereq] SonarQube not ready; deferring %SONAR_UP_RETRY_AFTER%s then retrying once...
    timeout /t %SONAR_UP_RETRY_AFTER% /nobreak >nul
    call :wait_for_sonarqube
  )
  exit /b %ERRORLEVEL%

:wait_for_sonarqube
  setlocal EnableDelayedExpansion
  set /a _waited=0
  set /a _interval=3
  echo [Prereq] Ensuring SonarQube is UP at %SONAR_HOST% (timeout %SONAR_UP_TIMEOUT%s)
  :_wait_loop
    if !_waited! GEQ %SONAR_UP_TIMEOUT% goto _wait_fail
    call :check_ready
    if errorlevel 1 (
      timeout /t !_interval! /nobreak >nul
      set /a _waited+=!_interval!
      goto _wait_loop
    ) else (
      echo [Prereq] SonarQube is UP.
      endlocal & exit /b 0
    )
  :_wait_fail
    endlocal & exit /b 1

:check_ready
  call :docker_available
  if errorlevel 1 (
    call :sonar_up_http
    exit /b %ERRORLEVEL%
  )
  call :container_exists
  if errorlevel 1 (
    call :sonar_up_http
    exit /b %ERRORLEVEL%
  )
  call :container_running || exit /b 1
  call :sonar_up_http
  exit /b %ERRORLEVEL%

:docker_available
  where docker >nul 2>&1 || exit /b 1
  docker info >nul 2>&1 || exit /b 1
  exit /b 0

:container_exists
  set "_found="
  for /f "tokens=* usebackq" %%N in (`docker ps -a --format "{{.Names}}"`) do (
    if /I "%%~N"=="%SONAR_CONTAINER_NAME%" set "_found=1"
  )
  if defined _found ( exit /b 0 ) else ( exit /b 1 )

:container_running
  set "_running="
  for /f "usebackq tokens=*" %%S in (`docker inspect -f "{{.State.Running}}" "%SONAR_CONTAINER_NAME%" 2^>nul`) do set "_running=%%S"
  if /I "%_running%"=="true" ( exit /b 0 ) else ( exit /b 1 )

:sonar_up_http
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%check_sonar_ready.ps1" -SonarHost "%SONAR_HOST%"
  exit /b %ERRORLEVEL%
