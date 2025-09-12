@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Resolve script directory
set "SCRIPT_DIR=%~dp0"
set "CONFIG_DIR=%SCRIPT_DIR%configs"

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

