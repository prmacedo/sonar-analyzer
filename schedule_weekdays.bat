@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%.") do set "ABS_DIR=%%~fI"

set "TASK_NAME=WeekdayBatch"
set "RUN_MODE=auto"
set "RUN_TIME=09:00"
set "FORCE_FLAG="
set "DELETE_MODE=0"
set "SHOW_MODE=0"
set "DRY_RUN=0"

:parse_args
if "%~1"=="" goto after_args
if /I "%~1"=="--multi" ( set "RUN_MODE=multi" & shift & goto parse_args )
if /I "%~1"=="--single" ( set "RUN_MODE=single" & shift & goto parse_args )
if /I "%~1"=="--time" (
  if "%~2"=="" goto usage
  set "RUN_TIME=%~2"
  shift
  shift
  goto parse_args
)
if /I "%~1"=="--task" (
  if "%~2"=="" goto usage
  set "TASK_NAME=%~2"
  shift
  shift
  goto parse_args
)
if /I "%~1"=="--force" ( set "FORCE_FLAG=/F" & shift & goto parse_args )
if /I "%~1"=="--delete" ( set "DELETE_MODE=1" & shift & goto parse_args )
if /I "%~1"=="--show" ( set "SHOW_MODE=1" & shift & goto parse_args )
if /I "%~1"=="--dry-run" ( set "DRY_RUN=1" & shift & goto parse_args )
if /I "%~1"=="--help" goto usage
echo [scheduler] Unknown option: %~1
goto usage

:after_args
if "%DELETE_MODE%"=="1" goto delete_task
if "%SHOW_MODE%"=="1" goto show_task

call :normalize_time "%RUN_TIME%" NORMALIZED_TIME
if errorlevel 1 goto invalid_time
set "RUN_TIME=%NORMALIZED_TIME%"

call :resolve_run_mode

set "RUN_CMD=run.bat"
if /I "%RUN_MODE%"=="multi" set "RUN_CMD=run-multi.bat"

if not exist "%ABS_DIR%\%RUN_CMD%" (
  echo [scheduler] Expected %RUN_CMD% in %ABS_DIR%
  exit /b 2
)

set "STATE_DIR=%ABS_DIR%\.state"
set "TASK_SCRIPT=%STATE_DIR%\%TASK_NAME%.ps1"
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "TASK_ACTION=%POWERSHELL% -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""%TASK_SCRIPT%"""
set "DISPLAY_ACTION=%TASK_ACTION:""="%"

echo Task name : %TASK_NAME%
echo Runner    : %RUN_CMD% (mode %RUN_MODE%)
echo Schedule  : Mon-Fri at %RUN_TIME%
echo Action    : %DISPLAY_ACTION%
if "%DRY_RUN%"=="1" (
  echo [scheduler] Dry run. Task not created.
  exit /b 0
)

if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
if not exist "%STATE_DIR%" (
  echo [scheduler] Failed to create state directory: %STATE_DIR%
  exit /b 1
)

> "%TASK_SCRIPT%" echo $ErrorActionPreference = 'Stop'
>> "%TASK_SCRIPT%" echo $workDir = '%ABS_DIR%'
>> "%TASK_SCRIPT%" echo $runner = '%RUN_CMD%'
>> "%TASK_SCRIPT%" echo $scheduler = Join-Path -Path $workDir -ChildPath 'scheduler_run.ps1'
>> "%TASK_SCRIPT%" echo if (-not (Test-Path -Path $scheduler -PathType Leaf)) { throw "Helper not found: $scheduler" }
>> "%TASK_SCRIPT%" echo ^& $scheduler -Runner $runner -WorkingDirectory $workDir

schtasks /Create %FORCE_FLAG% /TN "%TASK_NAME%" /SC WEEKLY /D MON,TUE,WED,THU,FRI /ST "%RUN_TIME%" /TR "%TASK_ACTION%"
if errorlevel 1 (
  echo [scheduler] Failed to create or update the task.
  exit /b 1
)

echo [scheduler] Task stored successfully.
exit /b 0

:delete_task
schtasks /Delete /TN "%TASK_NAME%" /F >nul 2>&1
if errorlevel 1 (
  echo [scheduler] Task '%TASK_NAME%' not found.
  exit /b 1
)
echo [scheduler] Task '%TASK_NAME%' removed.
exit /b 0

:show_task
schtasks /Query /TN "%TASK_NAME%" /FO LIST /V
exit /b %ERRORLEVEL%

:invalid_time
echo [scheduler] Invalid time: %RUN_TIME% (expected HH:MM, 24h)
exit /b 2

:normalize_time
setlocal EnableDelayedExpansion
set "_in=%~1"
for /f "tokens=1,2 delims=:" %%H in ("!_in!") do (
  set "HH=%%H"
  set "MM=%%I"
)
if not defined HH ( endlocal & exit /b 1 )
if not defined MM ( endlocal & exit /b 1 )
for /f "delims=0123456789" %%X in ("!HH!") do if not "%%X"=="" ( endlocal & exit /b 1 )
for /f "delims=0123456789" %%X in ("!MM!") do if not "%%X"=="" ( endlocal & exit /b 1 )
set /a _hh=1!HH! - 100 >nul 2>&1 || ( endlocal & exit /b 1 )
set /a _mm=1!MM! - 100 >nul 2>&1 || ( endlocal & exit /b 1 )
if !_hh! LSS 0 ( endlocal & exit /b 1 )
if !_hh! GTR 23 ( endlocal & exit /b 1 )
if !_mm! LSS 0 ( endlocal & exit /b 1 )
if !_mm! GTR 59 ( endlocal & exit /b 1 )
if !_hh! LSS 10 ( set "HH=0!_hh!" ) else ( set "HH=!_hh!" )
if !_mm! LSS 10 ( set "MM=0!_mm!" ) else ( set "MM=!_mm!" )
set "OUT=!HH!:!MM!"
endlocal & set "%~2=%OUT%"
exit /b 0

:resolve_run_mode
if /I "%RUN_MODE%"=="auto" (
  dir /b "%ABS_DIR%\configs\*.env" >nul 2>&1
  if errorlevel 1 ( set "RUN_MODE=single" ) else ( set "RUN_MODE=multi" )
)
exit /b 0

:usage
echo Usage: %~nx0 [--multi^|--single] [--time HH:MM] [--task NAME] [--force] [--delete] [--show] [--dry-run]
echo Example: %~nx0 --time 07:30 --multi --task SonarWeekdays --force
exit /b 2
