@echo off
setlocal EnableDelayedExpansion
set "settingName=ToggleWindowsUpdates"
set "scriptPath=%~f0"

set "___args="%~f0" %*"
fltmc > nul 2>&1 || (
    echo Administrator privileges are required.
    powershell -c "Start-Process -Verb RunAs -FilePath 'cmd' -ArgumentList """/c $env:___args"""" 2> nul || (
        echo You must run this script as admin.
        if "%*"=="" pause
        exit /b 1
    )
    exit /b
)

reg add "HKLM\SOFTWARE\AtlasOS\Services\%settingName%" /v path /t REG_SZ /d "%scriptPath%" /f > nul

for /f "tokens=3" %%a in ('sc qc wuauserv ^| findstr /i START_TYPE') do (
    set "WUState=%%a"
)

set "disableState="
set "enableState="
if /i "!WUState!"=="DISABLED" (
    set "disableState=(current)"
) else (
    set "enableState=(current)"
)

:menu
cls
echo Windows Update Toggle
echo 1. Disable Windows Updates !disableState!
echo 2. Enable Windows Updates !enableState!
echo 3. Exit
echo.
set /p choice=Select an option [1-3]: 

if "%choice%"=="1" goto disable
if "%choice%"=="2" goto enable
if "%choice%"=="3" exit
goto menu

:disable
echo Disabling the Windows Update service...
sc stop wuauserv >nul 2>&1
sc config wuauserv start= disabled >nul 2>&1

:: Atlas 26H2 (B5-3): the 'sih' and 'sihboot' tasks this used to change don't exist anymore

reg add "HKLM\SOFTWARE\AtlasOS\Services\%settingName%" /v state /t REG_DWORD /d 0 /f > nul

echo Windows Updates have been disabled.
call :askReboot
goto :eof

:enable
echo Enabling the Windows Update service...
sc config wuauserv start= demand >nul 2>&1
sc start wuauserv >nul 2>&1

:: Atlas 26H2 (B5-3): the 'sih' and 'sihboot' tasks this used to change don't exist anymore

reg add "HKLM\SOFTWARE\AtlasOS\Services\%settingName%" /v state /t REG_DWORD /d 1 /f > nul

echo Windows Updates have been enabled.
call :askReboot
goto :eof

:askReboot
echo.
set /p reboot=Would you like to reboot now to apply changes? (Y/N): 
if /i "%reboot%"=="Y" (
    shutdown /r /t 0
)
exit /b
