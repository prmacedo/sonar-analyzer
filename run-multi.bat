@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Resolve script directory
set "SCRIPT_DIR=%~dp0"
set "CONFIG_DIR=%SCRIPT_DIR%configs"

REM ---- SonarQube readiness gate (handles boot race with Docker) ----
if not defined SONAR_HOST set "SONAR_HOST=http://localhost:9000"
if not defined SONAR_CONTAINER_NAME set "SONAR_CONTAINER_NAME=sa_sonarqube"
if not defined SONAR_UP_TIMEOUT set "SONAR_UP_TIMEOUT=120"
if not defined SONAR_UP_RETRY_AFTER set "SONAR_UP_RETRY_AFTER=300"

call :ensure_sonar_ready || (
  echo [Error] SonarQube not ready after waits. Aborting batch.
  exit /b 1
)

if not exist "%CONFIG_DIR%" (
  echo [Error] configs directory not found at: %CONFIG_DIR%
  echo        Run setup.bat and provide multiple project paths to generate configs.
  exit /b 1
)

REM Check for any .env files
set "_hasfiles="
for %%A in ("%CONFIG_DIR%\*.env") do (
  if exist "%%~fA" (
    set "_hasfiles=1"
    goto :_gotfiles
  )
)
:_gotfiles
if not defined _hasfiles (
  echo [Error] No .env files found in %CONFIG_DIR%
  echo        Expected files like %CONFIG_DIR%\<project_key>.env
  exit /b 1
)

echo [Batch] Scanning configs in %CONFIG_DIR%
set "FAILED="

for %%E in ("%CONFIG_DIR%\*.env") do (
  if exist "%%~fE" (
    echo.
    echo [Batch] Running analysis for: %%~nxE
    set "DOTENV=%%~fE"
    call "%SCRIPT_DIR%run.bat"
    if errorlevel 1 (
      echo [Batch] Failed: %%~nxE
      if defined FAILED (
        set "FAILED=!FAILED! %%~nxE"
      ) else (
        set "FAILED=%%~nxE"
      )
    ) else (
      echo [Batch] Completed: %%~nxE
    )
  )
)

if defined FAILED (
  echo.
  echo [Batch] Completed with failures:
  echo   !FAILED!
  exit /b 1
)

echo.
echo [Batch] All analyses completed successfully.
exit /b 0

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
    if !
_waited! GEQ %SONAR_UP_TIMEOUT% goto _wait_fail
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
  powershell -NoProfile -Command "try { $j = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 \"%SONAR_HOST%/api/system/status\"; if ($j.Content -match '""status""\s*:\s*""UP""') { exit 0 } else { exit 1 } } catch { exit 1 }"
  exit /b %ERRORLEVEL%
