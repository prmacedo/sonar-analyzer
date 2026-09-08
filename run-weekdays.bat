@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Scheduled runner and scheduler helper for Windows.
REM
REM Run now (auto single/multi):
REM   run-weekdays.bat
REM Force multi or single:
REM   run-weekdays.bat --multi | --single
REM Install Task Scheduler job at given time:
REM   run-weekdays.bat --install [--time HH:MM] [--days MON,WED,FRI|ALL] [--multi|--single]

set "SCRIPT_DIR=%~dp0"
set "DEFAULT_TIME=09:00"
set "DEFAULT_DAYS=MON,TUE,WED,THU,FRI"

set "MODE=run"
set "RUN_VARIANT=auto"  REM auto|multi|single
set "RUN_TIME=%DEFAULT_TIME%"
set "RUN_DAYS=%DEFAULT_DAYS%"

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--install" ( set "MODE=install" & shift & goto parse_args )
if /I "%~1"=="--time" ( set "RUN_TIME=%~2" & shift & shift & goto parse_args )
if /I "%~1"=="--days" ( set "RUN_DAYS=%~2" & shift & shift & goto parse_args )
if /I "%~1"=="--multi" ( set "RUN_VARIANT=multi" & shift & goto parse_args )
if /I "%~1"=="--single" ( set "RUN_VARIANT=single" & shift & goto parse_args )
if /I "%~1"=="-h" ( goto :usage )
if /I "%~1"=="--help" ( goto :usage )
echo Unknown argument: %~1 1>&2
goto :usage

:args_done
call :normalize_days
if errorlevel 1 goto :usage

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
echo Usage: %~nx0 [--install] [--time HH:MM] [--days MON,TUE,WED,THU,FRI^|ALL] [--multi^|--single]
exit /b 2

:normalize_days
set "DAYS_LABEL="
set "PS_DAYS="
set "SCHTASKS_DAYS="
set "RUN_DAYS_NUMS=,"
set "_raw=%RUN_DAYS: =%"
if not defined _raw exit /b 1
if /I "%_raw%"=="ALL" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="DAILY" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="EVERYDAY" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="TODOS" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="TODO" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="DIARIO" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
if /I "%_raw%"=="DIÁRIO" set "_raw=MON,TUE,WED,THU,FRI,SAT,SUN"
:normalize_days_loop
if not defined _raw exit /b 0
for /f "tokens=1* delims=," %%A in ("!_raw!") do (
  set "_day=%%~A"
  set "_raw=%%~B"
)
call :append_day "!_day!"
if errorlevel 1 exit /b 1
goto normalize_days_loop

:append_day
set "_day=%~1"
set "_label="
set "_ps="
set "_schtasks="
set "_num="
if /I "%_day%"=="MON" ( set "_label=Mon" & set "_ps=Monday" & set "_schtasks=MON" & set "_num=1" )
if /I "%_day%"=="MONDAY" ( set "_label=Mon" & set "_ps=Monday" & set "_schtasks=MON" & set "_num=1" )
if /I "%_day%"=="SEG" ( set "_label=Mon" & set "_ps=Monday" & set "_schtasks=MON" & set "_num=1" )
if /I "%_day%"=="SEGUNDA" ( set "_label=Mon" & set "_ps=Monday" & set "_schtasks=MON" & set "_num=1" )
if "%_day%"=="1" ( set "_label=Mon" & set "_ps=Monday" & set "_schtasks=MON" & set "_num=1" )
if /I "%_day%"=="TUE" ( set "_label=Tue" & set "_ps=Tuesday" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="TUES" ( set "_label=Tue" & set "_ps=Tuesday" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="TUESDAY" ( set "_label=Tue" & set "_ps=Tuesday" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="TER" ( set "_label=Tue" & set "_ps=Tuesday" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="TERCA" ( set "_label=Tue" & set "_ps=Tuesday" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="TERÇA" ( set "_label=Tue" & set "_ps=Tuesday" & set "_schtasks=TUE" & set "_num=2" )
if "%_day%"=="2" ( set "_label=Tue" & set "_ps=Tuesday" & set "_schtasks=TUE" & set "_num=2" )
if /I "%_day%"=="WED" ( set "_label=Wed" & set "_ps=Wednesday" & set "_schtasks=WED" & set "_num=3" )
if /I "%_day%"=="WEDNESDAY" ( set "_label=Wed" & set "_ps=Wednesday" & set "_schtasks=WED" & set "_num=3" )
if /I "%_day%"=="QUA" ( set "_label=Wed" & set "_ps=Wednesday" & set "_schtasks=WED" & set "_num=3" )
if /I "%_day%"=="QUARTA" ( set "_label=Wed" & set "_ps=Wednesday" & set "_schtasks=WED" & set "_num=3" )
if "%_day%"=="3" ( set "_label=Wed" & set "_ps=Wednesday" & set "_schtasks=WED" & set "_num=3" )
if /I "%_day%"=="THU" ( set "_label=Thu" & set "_ps=Thursday" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="THUR" ( set "_label=Thu" & set "_ps=Thursday" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="THURS" ( set "_label=Thu" & set "_ps=Thursday" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="THURSDAY" ( set "_label=Thu" & set "_ps=Thursday" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="QUI" ( set "_label=Thu" & set "_ps=Thursday" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="QUINTA" ( set "_label=Thu" & set "_ps=Thursday" & set "_schtasks=THU" & set "_num=4" )
if "%_day%"=="4" ( set "_label=Thu" & set "_ps=Thursday" & set "_schtasks=THU" & set "_num=4" )
if /I "%_day%"=="FRI" ( set "_label=Fri" & set "_ps=Friday" & set "_schtasks=FRI" & set "_num=5" )
if /I "%_day%"=="FRIDAY" ( set "_label=Fri" & set "_ps=Friday" & set "_schtasks=FRI" & set "_num=5" )
if /I "%_day%"=="SEX" ( set "_label=Fri" & set "_ps=Friday" & set "_schtasks=FRI" & set "_num=5" )
if /I "%_day%"=="SEXTA" ( set "_label=Fri" & set "_ps=Friday" & set "_schtasks=FRI" & set "_num=5" )
if "%_day%"=="5" ( set "_label=Fri" & set "_ps=Friday" & set "_schtasks=FRI" & set "_num=5" )
if /I "%_day%"=="SAT" ( set "_label=Sat" & set "_ps=Saturday" & set "_schtasks=SAT" & set "_num=6" )
if /I "%_day%"=="SATURDAY" ( set "_label=Sat" & set "_ps=Saturday" & set "_schtasks=SAT" & set "_num=6" )
if /I "%_day%"=="SAB" ( set "_label=Sat" & set "_ps=Saturday" & set "_schtasks=SAT" & set "_num=6" )
if /I "%_day%"=="SABADO" ( set "_label=Sat" & set "_ps=Saturday" & set "_schtasks=SAT" & set "_num=6" )
if /I "%_day%"=="SÁBADO" ( set "_label=Sat" & set "_ps=Saturday" & set "_schtasks=SAT" & set "_num=6" )
if "%_day%"=="6" ( set "_label=Sat" & set "_ps=Saturday" & set "_schtasks=SAT" & set "_num=6" )
if /I "%_day%"=="SUN" ( set "_label=Sun" & set "_ps=Sunday" & set "_schtasks=SUN" & set "_num=0" )
if /I "%_day%"=="SUNDAY" ( set "_label=Sun" & set "_ps=Sunday" & set "_schtasks=SUN" & set "_num=0" )
if /I "%_day%"=="DOM" ( set "_label=Sun" & set "_ps=Sunday" & set "_schtasks=SUN" & set "_num=0" )
if /I "%_day%"=="DOMINGO" ( set "_label=Sun" & set "_ps=Sunday" & set "_schtasks=SUN" & set "_num=0" )
if "%_day%"=="0" ( set "_label=Sun" & set "_ps=Sunday" & set "_schtasks=SUN" & set "_num=0" )
if "%_day%"=="7" ( set "_label=Sun" & set "_ps=Sunday" & set "_schtasks=SUN" & set "_num=0" )
if not defined _num (
  echo Invalid day in --days: %_day% 1>&2
  exit /b 1
)
if not "!RUN_DAYS_NUMS:,%_num%,=!"=="!RUN_DAYS_NUMS!" exit /b 0
if defined DAYS_LABEL ( set "DAYS_LABEL=!DAYS_LABEL!,!_label!" ) else ( set "DAYS_LABEL=!_label!" )
if defined PS_DAYS ( set "PS_DAYS=!PS_DAYS!,!_ps!" ) else ( set "PS_DAYS=!_ps!" )
if defined SCHTASKS_DAYS ( set "SCHTASKS_DAYS=!SCHTASKS_DAYS!,!_schtasks!" ) else ( set "SCHTASKS_DAYS=!_schtasks!" )
set "RUN_DAYS_NUMS=!RUN_DAYS_NUMS!!_num!,"
exit /b 0

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
for /f %%D in ('powershell -NoProfile -Command "(Get-Date).DayOfWeek.value__"') do set "DOW=%%D"
if "!RUN_DAYS_NUMS:,%DOW%,=!"=="!RUN_DAYS_NUMS!" (
  echo [Scheduler] Today is not scheduled ^(DOW=%DOW%; scheduled=%DAYS_LABEL%^). Skipping.
  exit /b 0
)

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
REM Create/replace a Windows Scheduled Task at %RUN_TIME%.
set "TASK_NAME=sonar-weekdays"

REM First, try PowerShell-based task for better settings (StartWhenAvailable, logon trigger)
for /f "tokens=1,2 delims=:" %%H in ("%RUN_TIME%") do ( set "_HH=%%H" & set "_MM=%%I" )
set "_TMPPS=%TEMP%\sonar_weekdays_install.ps1"
(
  echo $ErrorActionPreference = 'Stop'
  echo $taskName = '%TASK_NAME%'
  echo $scriptDir = '%SCRIPT_DIR%'
  echo $variant = '%VARIANT%'
  echo $runDays = '%RUN_DAYS%'
  echo $days = '%PS_DAYS%'.Split(',')
  echo $hh = %_HH%
  echo $mm = %_MM%
  echo $cmd = "cmd.exe"
  echo $args = "/c cd /d `"`"$scriptDir`"`" ^&^& `"`"$scriptDir`"`"run-weekdays.bat`" --$variant --days `"`"$runDays`"`""
  echo $action = New-ScheduledTaskAction -Execute $cmd -Argument $args
  echo $t1 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $days -At (Get-Date -Hour $hh -Minute $mm -Second 0)
  echo $t2 = New-ScheduledTaskTrigger -AtLogOn
  echo $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable
  echo Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($t1, $t2) -Settings $settings -Description 'Run Sonar scripts on scheduled days' -Force ^| Out-Null
) > "%_TMPPS%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%_TMPPS%" >nul 2>nul
if not errorlevel 1 (
  del /q "%_TMPPS%" >nul 2>nul
  echo [Install] Scheduled task '%TASK_NAME%' created with PowerShell (%DAYS_LABEL% %RUN_TIME%, StartWhenAvailable, +AtLogOn).
  exit /b 0
)
del /q "%_TMPPS%" >nul 2>nul

REM Fallback: SCHTASKS basic weekly schedule
REM Build the task action; fully-quoted paths and script
set "TASK_ACTION=cmd /c \"cd /d \"\"%SCRIPT_DIR%\"\" ^&^& \"\"%SCRIPT_DIR%run-weekdays.bat\"\" --%VARIANT% --days \"\"%RUN_DAYS%\"\"\""

echo [Install] Creating scheduled task '%TASK_NAME%' with schtasks (%DAYS_LABEL% %RUN_TIME%)
schtasks /Create /F /TN "%TASK_NAME%" /TR "%TASK_ACTION%" /SC WEEKLY /D %SCHTASKS_DAYS% /ST "%RUN_TIME%" >nul 2>nul
if errorlevel 1 (
  echo [Error] Failed to create the scheduled task. Try running as Administrator or create it manually.
  exit /b 1
)
echo [Install] Task created. It runs whether a console is open or not.
echo           Adjust credentials in Task Scheduler if you want it to run when logged off.
exit /b 0

:eof
endlocal
