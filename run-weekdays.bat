@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Weekday runner and scheduler helper for Windows.
REM
REM Run now (auto single/multi):
REM   run-weekdays.bat
REM Force multi or single:
REM   run-weekdays.bat --multi | --single
REM Install Task Scheduler job (Mon-Fri) at given time:
REM   run-weekdays.bat --install [--time HH:MM] [--multi|--single]

set "SCRIPT_DIR=%~dp0"
set "DEFAULT_TIME=09:00"

set "MODE=run"
set "RUN_VARIANT=auto"  REM auto|multi|single
set "RUN_TIME=%DEFAULT_TIME%"

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--install" ( set "MODE=install" & shift & goto parse_args )
if /I "%~1"=="--time" ( set "RUN_TIME=%~2" & shift & shift & goto parse_args )
if /I "%~1"=="--multi" ( set "RUN_VARIANT=multi" & shift & goto parse_args )
if /I "%~1"=="--single" ( set "RUN_VARIANT=single" & shift & goto parse_args )
if /I "%~1"=="-h" ( goto :usage )
if /I "%~1"=="--help" ( goto :usage )
echo Unknown argument: %~1 1>&2
goto :usage

:args_done

REM Decide variant if auto: presence of configs\*.env
call :pick_variant
set "VARIANT=%ERRORLEVEL%"
if "%VARIANT%"=="1" (
  set "VARIANT=multi"
) else (
  set "VARIANT=single"
)

if /I "%MODE%"=="install" (
  call :install_schedule
  goto :eof
) else (
  call :run_now
  goto :eof
)

:usage
echo Usage: %~nx0 [--install] [--time HH:MM] [--multi^|--single]
exit /b 2

:pick_variant
if /I "%RUN_VARIANT%"=="multi" exit /b 1
if /I "%RUN_VARIANT%"=="single" exit /b 0
set "_hasenv="
for %%E in ("%SCRIPT_DIR%configs\*.env") do (
  if exist "%%~fE" (
    set "_hasenv=1"
    goto :pv_done
  )
)
:pv_done
if defined _hasenv ( exit /b 1 ) else ( exit /b 0 )

:ensure_stamp
set "STAMP_DIR=%SCRIPT_DIR%.state"
set "STAMP_FILE=%STAMP_DIR%\last_run.date"
if not exist "%STAMP_DIR%" mkdir "%STAMP_DIR%" >nul 2>nul
exit /b 0

:run_now
REM Skip weekends (0=Sunday, 6=Saturday)
for /f %%D in ('powershell -NoProfile -Command "(Get-Date).DayOfWeek.value__"') do set "DOW=%%D"
if "%DOW%"=="0" ( echo [Weekdays] Weekend (Sun). Skipping. & exit /b 0 )
if "%DOW%"=="6" ( echo [Weekdays] Weekend (Sat). Skipping. & exit /b 0 )

call :ensure_stamp
for /f %%T in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd')"') do set "TODAY=%%T"

if exist "%STAMP_FILE%" (
  set "_last="
  set /p _last=<"%STAMP_FILE%"
  if /I "%_last%"=="%TODAY%" (
    echo [Weekdays] Already ran today (%TODAY%); skipping.
    exit /b 0
  )
)

if /I "%VARIANT%"=="multi" (
  call "%SCRIPT_DIR%run-multi.bat"
) else (
  call "%SCRIPT_DIR%run.bat"
)
set "_code=%ERRORLEVEL%"
if "%_code%"=="0" (
  >"%STAMP_FILE%" echo %TODAY%
)
exit /b %_code%

:install_schedule
REM Create/replace a Windows Scheduled Task (Mon-Fri at %RUN_TIME%)
set "TASK_NAME=sonar-weekdays"

REM First, try PowerShell-based task for better settings (StartWhenAvailable, logon trigger)
for /f "tokens=1,2 delims=:" %%H in ("%RUN_TIME%") do ( set "_HH=%%H" & set "_MM=%%I" )
set "_TMPPS=%TEMP%\sonar_weekdays_install.ps1"
(
  echo $ErrorActionPreference = 'Stop'
  echo $taskName = '%TASK_NAME%'
  echo $scriptDir = '%SCRIPT_DIR%'
  echo $variant = '%VARIANT%'
  echo $hh = %_HH%
  echo $mm = %_MM%
  echo $cmd = "cmd.exe"
  echo $args = "/c cd /d `"`"$scriptDir`"`" ^&^& `"`"$scriptDir`"`"run-weekdays.bat`" --$variant"
  echo $action = New-ScheduledTaskAction -Execute $cmd -Argument $args
  echo $t1 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At (Get-Date -Hour $hh -Minute $mm -Second 0)
  echo $t2 = New-ScheduledTaskTrigger -AtLogOn
  echo $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable
  echo Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($t1, $t2) -Settings $settings -Description 'Run Sonar scripts on weekdays' -Force ^| Out-Null
) > "%_TMPPS%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%_TMPPS%" >nul 2>nul
if not errorlevel 1 (
  del /q "%_TMPPS%" >nul 2>nul
  echo [Install] Scheduled task '%TASK_NAME%' created with PowerShell (Mon..Fri %RUN_TIME%, StartWhenAvailable, +AtLogOn).
  exit /b 0
)
del /q "%_TMPPS%" >nul 2>nul

REM Fallback: SCHTASKS basic weekly schedule
REM Build the task action; fully-quoted paths and script
set "TASK_ACTION=cmd /c \"cd /d \"\"%SCRIPT_DIR%\"\" ^&^& \"\"%SCRIPT_DIR%run-weekdays.bat\"\" --%VARIANT%\""

echo [Install] Creating scheduled task '%TASK_NAME%' with schtasks (Mon..Fri %RUN_TIME%)
schtasks /Create /F /TN "%TASK_NAME%" /TR "%TASK_ACTION%" /SC WEEKLY /D MON,TUE,WED,THU,FRI /ST "%RUN_TIME%" >nul 2>nul
if errorlevel 1 (
  echo [Error] Failed to create the scheduled task. Try running as Administrator or create it manually.
  exit /b 1
)
echo [Install] Task created. It runs whether a console is open or not.
echo           Adjust credentials in Task Scheduler if you want it to run when logged off.
exit /b 0

:eof
endlocal
