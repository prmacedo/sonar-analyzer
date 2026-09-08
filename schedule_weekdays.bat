@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%.") do set "ABS_DIR=%%~fI"

set "TASK_NAME=WeekdayBatch"
set "RUN_MODE=auto"
set "RUN_TIME=09:00"
set "RUN_DAYS=MON,TUE,WED,THU,FRI"
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
if /I "%~1"=="--days" (
  if "%~2"=="" goto usage
  set "RUN_DAYS=%~2"
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

call :normalize_days
if errorlevel 1 goto usage

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
echo Schedule  : %DAYS_LABEL% at %RUN_TIME%
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

schtasks /Create %FORCE_FLAG% /TN "%TASK_NAME%" /SC WEEKLY /D %SCHTASKS_DAYS% /ST "%RUN_TIME%" /TR "%TASK_ACTION%"
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

:normalize_days
setlocal EnableDelayedExpansion
set "DAYS_LABEL="
set "SCHTASKS_DAYS="
set "RUN_DAYS_NUMS=,"
set "_raw=%RUN_DAYS: =%"
if not defined _raw ( endlocal & exit /b 1 )
if /I "%_raw%"=="ALL" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="DAILY" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="EVERYDAY" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="TODOS" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="TODO" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="DIARIO" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="DIÁRIO" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
:normalize_days_loop
if not defined _raw (
  endlocal & set "DAYS_LABEL=!DAYS_LABEL!" & set "SCHTASKS_DAYS=!SCHTASKS_DAYS!" & exit /b 0
)
for /f "tokens=1* delims=," %%A in ("!_raw!") do (
  set "_day=%%~A"
  set "_raw=%%~B"
)
call :append_day "!_day!"
if errorlevel 1 ( endlocal & exit /b 1 )
goto normalize_days_loop

:append_day
set "_day=%~1"
set "_label="
set "_schtasks="
set "_num="
if /I "%_day%"=="MON" ( set "_label=Mon" & set "_schtasks=MON" & set "_num=1" )
if /I "%_day%"=="MONDAY" ( set "_label=Mon" & set "_schtasks=MON" & set "_num=1" )
if /I "%_day%"=="SEG" ( set "_label=Mon" & set "_schtasks=MON" & set "_num=1" )
if /I "%_day%"=="SEGUNDA" ( set "_label=Mon" & set "_schtasks=MON" & set "_num=1" )
if "%_day%"=="1" ( set "_label=Mon" & set "_schtasks=MON" & set "_num=1" )
if /I "%_day%"=="TUE" ( set "_label=Tue" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="TUES" ( set "_label=Tue" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="TUESDAY" ( set "_label=Tue" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="TER" ( set "_label=Tue" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="TERCA" ( set "_label=Tue" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="TERÇA" ( set "_label=Tue" & set "_schtasks=TUE" & set "_num=2" )
if "%_day%"=="2" ( set "_label=Tue" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="WED" ( set "_label=Wed" & set "_schtasks=WED" & set "_num=3" )
if /I "%_day%"=="WEDNESDAY" ( set "_label=Wed" & set "_schtasks=WED" & set "_num=3" )
if /I "%_day%"=="QUA" ( set "_label=Wed" & set "_schtasks=WED" & set "_num=3" )
if /I "%_day%"=="QUARTA" ( set "_label=Wed" & set "_schtasks=WED" & set "_num=3" )
if "%_day%"=="3" ( set "_label=Wed" & set "_schtasks=WED" & set "_num=3" )
if /I "%_day%"=="THU" ( set "_label=Thu" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="THUR" ( set "_label=Thu" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="THURS" ( set "_label=Thu" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="THURSDAY" ( set "_label=Thu" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="QUI" ( set "_label=Thu" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="QUINTA" ( set "_label=Thu" & set "_schtasks=THU" & set "_num=4" )
if "%_day%"=="4" ( set "_label=Thu" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="FRI" ( set "_label=Fri" & set "_schtasks=FRI" & set "_num=5" )
if /I "%_day%"=="FRIDAY" ( set "_label=Fri" & set "_schtasks=FRI" & set "_num=5" )
if /I "%_day%"=="SEX" ( set "_label=Fri" & set "_schtasks=FRI" & set "_num=5" )
if /I "%_day%"=="SEXTA" ( set "_label=Fri" & set "_schtasks=FRI" & set "_num=5" )
if "%_day%"=="5" ( set "_label=Fri" & set "_schtasks=FRI" & set "_num=5" )
if /I "%_day%"=="SAT" ( set "_label=Sat" & set "_schtasks=SAT" & set "_num=6" )
if /I "%_day%"=="SATURDAY" ( set "_label=Sat" & set "_schtasks=SAT" & set "_num=6" )
if /I "%_day%"=="SAB" ( set "_label=Sat" & set "_schtasks=SAT" & set "_num=6" )
if /I "%_day%"=="SABADO" ( set "_label=Sat" & set "_schtasks=SAT" & set "_num=6" )
if /I "%_day%"=="SÁBADO" ( set "_label=Sat" & set "_schtasks=SAT" & set "_num=6" )
if "%_day%"=="6" ( set "_label=Sat" & set "_schtasks=SAT" & set "_num=6" )
if /I "%_day%"=="SUN" ( set "_label=Sun" & set "_schtasks=SUN" & set "_num=0" )
if /I "%_day%"=="SUNDAY" ( set "_label=Sun" & set "_schtasks=SUN" & set "_num=0" )
if /I "%_day%"=="DOM" ( set "_label=Sun" & set "_schtasks=SUN" & set "_num=0" )
if /I "%_day%"=="DOMINGO" ( set "_label=Sun" & set "_schtasks=SUN" & set "_num=0" )
if "%_day%"=="0" ( set "_label=Sun" & set "_schtasks=SUN" & set "_num=0" )
if "%_day%"=="7" ( set "_label=Sun" & set "_schtasks=SUN" & set "_num=0" )
if not defined _num (
  echo [scheduler] Invalid day in --days: %_day%
  exit /b 1
)
if not "!RUN_DAYS_NUMS:,%_num%,=!"=="!RUN_DAYS_NUMS!" exit /b 0
if defined DAYS_LABEL ( set "DAYS_LABEL=!DAYS_LABEL!,!_label!" ) else ( set "DAYS_LABEL=!_label!" )
if defined SCHTASKS_DAYS ( set "SCHTASKS_DAYS=!SCHTASKS_DAYS!,!_schtasks!" ) else ( set "SCHTASKS_DAYS=!_schtasks!" )
set "RUN_DAYS_NUMS=!RUN_DAYS_NUMS!!_num!,"
exit /b 0

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
echo Usage: %~nx0 [--multi^|--single] [--time HH:MM] [--days MON,WED,FRI^|ALL] [--task NAME] [--force] [--delete] [--show] [--dry-run]
echo Example: %~nx0 --time 07:30 --days ALL --multi --task SonarDaily --force
exit /b 2
