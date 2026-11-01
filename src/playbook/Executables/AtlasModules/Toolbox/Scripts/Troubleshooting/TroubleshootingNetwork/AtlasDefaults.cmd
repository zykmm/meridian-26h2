@echo off

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

echo Setting network settings to Atlas defaults...

:: Atlas 26H2 (B2-5): every physical adapter (PCI and USB) is configured. It used to be only the last PCI one ('netKey' was
:: overwritten in the loop) and the 'rem' lines inside the 'for' list were taken as items of the list
for /f "usebackq" %%a in (`powershell -NonI -NoP -C "(Get-CimInstance Win32_NetworkAdapter).PNPDeviceID | sls 'PCI\\VEN_|USB\\VID_'"`) do (
	for /f "tokens=3" %%b in ('reg query "HKLM\SYSTEM\CurrentControlSet\Enum\%%a" /v "Driver" 2^>nul ^| findstr /i "REG_SZ"') do (
		call :configAdapter "HKLM\SYSTEM\CurrentControlSet\Control\Class\%%b"
	)
)

if "%~1"=="/silent" exit /b

echo Finished, please reboot your device for changes to apply.
pause
exit /b

:configAdapter
set "netKey=%~1"

:: Configure network adapter settings

rem --------------------------
rem Unknown benefit
rem --------------------------
rem "LargeSendOffload"
rem "LargeSendOffloadJumboCombo"
rem "LsoV1IPv4"
rem "LsoV2IPv4"
rem "LsoV2IPv6"
rem "LogLevelWarn"
rem "AlternateSemaphoreDelay"
rem "DeviceSleepOnDisconnect"
rem "EnableModernStandby"
rem "PriorityVLANTag"
rem "Node"
rem "MPC"
rem "PowerDownPll"
rem "PMWiFiRekeyOffload"
rem "ARPOffloadEnable"
rem "bAdvancedLPs"
rem "NSOffloadEnable"
rem "GTKOffloadEnable"
rem "Enable9KJFTpt"
rem "EnableEDT"
rem "GPPSW"
rem "MasterSlave"
rem "PacketCoalescing"
rem Could cause dropped network frames
rem "FlowControl"
rem "FlowControlCap"

rem AutoDisableGigabit: don't disable gigabit
rem ApCompatMode: Access Point Compatibility Mode, zero is 'High Performance'
rem SipsEnabled, ReduceSpeedOnPowerDown: about reducing link speed
rem DMACoalescing: 'may increase latency'
rem https://www.intel.com/content/www/us/en/support/articles/000007456/ethernet-products.html
for %%a in (
    "AutoDisableGigabit"
    "ApCompatMode"
    "SipsEnabled"
    "ReduceSpeedOnPowerDown"
    "DMACoalescing"
) do (
    rem Check without '*'
    for /f %%b in ('reg query "%netKey%" /v "%%~a" ^| findstr "HKEY"') do (
        reg add "%netKey%" /v "%%~a" /t REG_SZ /d "0" /f > nul
    )
    rem Check with '*'
    for /f %%b in ('reg query "%netKey%" /v "*%%~a" ^| findstr "HKEY"') do (
        reg add "%netKey%" /v "*%%~a" /t REG_SZ /d "0" /f > nul
    )
) > nul 2>&1
exit /b