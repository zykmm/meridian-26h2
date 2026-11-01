#Requires -RunAsAdministrator
# Verificacion de Meridian 26H2 (fork no oficial de AtlasOS). Solo lee, no cambia nada.
# Uso (PowerShell como administrador):
#   powershell -NoProfile -ExecutionPolicy Bypass -File ".\verificar-26h2.ps1" -Nombre mipc
# Guarda verificacion-<Nombre>-<fecha>.txt junto al script (sin nombre de equipo ni de usuario).
param([string]$Nombre = 'mipc')

$ErrorActionPreference = 'SilentlyContinue'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $outDir "verificacion-$Nombre-$stamp.txt"
$lines = New-Object System.Collections.Generic.List[string]
$script:ok = 0; $script:bad = 0

function Add([string]$t) { $lines.Add($t) }
function Check([string]$id, [string]$what, [bool]$pass, [string]$detail) {
    if ($pass) { $script:ok++; $s = 'OK   ' } else { $script:bad++; $s = 'FALLO' }
    Add ("{0} [{1}] {2} -> {3}" -f $s, $id, $what, $detail)
}
function Info([string]$id, [string]$what, [string]$detail) { Add ("INFO  [{0}] {1} -> {2}" -f $id, $what, $detail) }
function RegVal([string]$path, [string]$name) { (Get-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue).$name }
function RegKind([string]$path, [string]$name) { try { (Get-Item -LiteralPath $path).GetValueKind($name) } catch { 'no existe' } }

# Usuario con sesion (HKCU de quien ejecuta)
$sid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
$hkcu = "Registry::HKEY_USERS\$sid"

Add "Verificacion Meridian 26H2 - $Nombre - $(Get-Date)"
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Add "Windows: $($cv.ProductName) $($cv.DisplayVersion) build $($cv.CurrentBuild).$($cv.UBR)"
Add ''

# ---------------------------------------------------------------- Opciones y version
$so = Get-ItemProperty 'HKLM:\SOFTWARE\AtlasOS\SetupOptions'
Info 'D1' 'SetupOptions' ("AutoUpdates={0} Hibernation={1} Defender={2} browser={3}" -f $so.AutoUpdates, $so.Hibernation, $so.Defender, $so.browser)
$oem = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
Check 'B4-14' 'Version OEM' ("$($oem.Model)" -match 'Meridian 26H2') "Model='$($oem.Model)'"

# ---------------------------------------------------------------- Post-reinicio (UCPD)
$log = "$env:windir\AtlasModules\Logs\postReboot.log"
$task = Get-ScheduledTask -TaskName 'AtlasPostReboot' -ErrorAction SilentlyContinue
Check 'F3-1/F3-21' 'Tarea AtlasPostReboot eliminada tras aplicarse' ($null -eq $task) $(if ($task) { "sigue: estado $($task.State)" } else { 'no existe' })
Info 'F5-1' 'Contador de intentos' ("Attempts=" + (RegVal 'HKLM:\SOFTWARE\AtlasOS\PostReboot' 'Attempts'))
$ucpd = Get-CimInstance Win32_SystemDriver -Filter "Name='UCPD'"
Check 'F3-1' 'UCPD no cargado' ($ucpd.State -ne 'Running') "estado=$($ucpd.State) Start=$(RegVal 'HKLM:\SYSTEM\CurrentControlSet\Services\UCPD' 'Start')"
Check 'F3-1' 'Directiva Dsh\AllowNewsAndInterests=0' ((RegVal 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests') -eq 0) "$(RegVal 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests')"
Check 'F3-1' 'Directiva Windows Feeds\EnableFeeds=0' ((RegVal 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds') -eq 0) "$(RegVal 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds')"
$http = RegVal "$hkcu\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" 'ProgId'
$https = RegVal "$hkcu\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" 'ProgId'
$html = RegVal "$hkcu\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.html\UserChoice" 'ProgId'
Check 'F3-21' 'Navegador predeterminado Brave (http/https/.html)' ($http -eq 'BraveHTML' -and $https -eq 'BraveHTML' -and $html -eq 'BraveHTML') "http=$http https=$https .html=$html"
$pins = "$hkcu\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins"
Check 'F3-10' 'Anclajes MailPin y CopilotPWAPin = 0' ((RegVal $pins 'MailPin') -eq 0 -and (RegVal $pins 'CopilotPWAPin') -eq 0) "MailPin=$(RegVal $pins 'MailPin') CopilotPWAPin=$(RegVal $pins 'CopilotPWAPin')"

# ---------------------------------------------------------------- Defender / Tamper
$mp = Get-MpComputerStatus
Info 'F3-19' 'Defender' ("RealTime={0} TamperProtected={1} AMService={2}" -f $mp.RealTimeProtectionEnabled, $mp.IsTamperProtected, $mp.AMServiceEnabled)
Check 'F3-19' 'RunOnce AtlasTamperProtection consumido' ($null -eq (RegVal 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' 'AtlasTamperProtection')) "valor=$(RegVal 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' 'AtlasTamperProtection')"
$abp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\App and Browser protection'
Check 'D3/B3-6' 'Control de aplicaciones y navegador visible' ($null -eq (RegVal $abp 'UILockdown')) "UILockdown=$(RegVal $abp 'UILockdown')"

# ---------------------------------------------------------------- Bloqueo de version
$wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
Check 'B2-3' 'Bloqueo de version' ((RegVal $wu 'TargetReleaseVersion') -eq 1 -and "$(RegVal $wu 'TargetReleaseVersionInfo')" -ne '' -and "$(RegVal $wu 'ProductVersion')" -ne '') ("TargetReleaseVersion={0} Info={1} ProductVersion={2}" -f (RegVal $wu 'TargetReleaseVersion'), (RegVal $wu 'TargetReleaseVersionInfo'), (RegVal $wu 'ProductVersion'))
Check 'B3-1' 'Actualizaciones automaticas desactivadas (opcion elegida: AUOptions=2, avisar antes de descargar)' ((RegVal "$wu\AU" 'AUOptions') -eq 2) "AUOptions=$(RegVal "$wu\AU" 'AUOptions') NoAutoUpdate=$(RegVal "$wu\AU" 'NoAutoUpdate')"

# ---------------------------------------------------------------- Scripts (default) en instalacion limpia (D1/F3-6)
Check 'F3-6' "Sin 'Dar acceso a' en el menu contextual" (!(Test-Path 'Registry::HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\Sharing')) ''
Check 'F3-11' 'Sin texto "- Acceso directo" (%s.lnk)' ((RegVal "$hkcu\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates" 'ShortcutNameTemplate') -eq '"%s.lnk"') "valor=$(RegVal "$hkcu\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates" 'ShortcutNameTemplate')"
Check 'F3-15' 'Inicio: apps mas usadas ocultas (2)' ((RegVal 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'ShowOrHideMostUsedApps') -eq 2) "valor=$(RegVal 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'ShowOrHideMostUsedApps')"
Check 'B3-2' 'Hibernacion desactivada (opcion elegida)' ((RegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled') -eq 0) "HibernateEnabled=$(RegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled')"
Check 'B4-3' 'Unidades extraibles solo en Este equipo' (!(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}')) ''

# ---------------------------------------------------------------- Estados de la carpeta Atlas (Toolbox 0.1.13)
$expected = [ordered]@{
    'ContextMenuTerminals' = 2; 'Mitigations' = 2; 'VerboseStatusMessage' = 0; 'MicrosoftCopilot' = 0; 'AppIconsThumbnail' = 1
    'OldContextMenu' = 1; 'VbsState' = 0; 'Hibernation' = 0; 'AutomaticUpdates' = 0; 'HideAppBrowserControl' = 1; 'Printing' = 1
    'CpuIdleContextMenu' = 0; 'FileSharing' = 0; 'NetworkNavigationPane' = 0; 'GiveAccessToMenu' = 0; 'PowerSaving' = 0
}
foreach ($k in $expected.Keys) {
    $v = RegVal "HKLM:\SOFTWARE\AtlasOS\Services\$k" 'state'
    Check 'F3-13/B4' "Estado $k = $($expected[$k])" ($v -eq $expected[$k]) "state=$v path=$(Split-Path -Leaf (RegVal "HKLM:\SOFTWARE\AtlasOS\Services\$k" 'path'))"
}
$junk = Get-ChildItem 'HKLM:\SOFTWARE\AtlasOS' | Where-Object { $_.PSChildName -like 'Services?*' -and $_.PSChildName -ne 'Services' } | ForEach-Object PSChildName
Check 'B4-2' 'Sin claves basura AtlasOS\Services<nombre>' (!$junk) "$junk"
foreach ($old in 'VerboseMessages', 'Copilot', 'AppIconThumbnail') {
    Check 'B4-10' "Sin estado antiguo $old" (!(Test-Path "HKLM:\SOFTWARE\AtlasOS\Services\$old")) ''
}

# ---------------------------------------------------------------- Core Isolation (opcion elegida)
$hvci = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
Check 'F3-3' 'HVCI Enabled=0 (clave creada)' ((RegVal $hvci 'Enabled') -eq 0) "Enabled=$(RegVal $hvci 'Enabled')"
Check 'F3-3' 'EnableVirtualizationBasedSecurity=0' ((RegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity') -eq 0) ''
Check 'D5' 'LSA (RunAsPPL) no puesta a 0 por Atlas' ((RegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL') -ne 0) "RunAsPPL=$(RegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL') (vacio = valor de Windows)"

# ---------------------------------------------------------------- Firewall / Asistencia remota
$ra = Get-NetFirewallRule -Group '@FirewallAPI.dll,-33002'
Check 'F3-4' 'Reglas de Asistencia remota desactivadas' ($ra.Count -gt 0 -and @($ra | Where-Object Enabled -eq 'True').Count -eq 0) ("{0} reglas, {1} activas" -f $ra.Count, @($ra | Where-Object Enabled -eq 'True').Count)

# ---------------------------------------------------------------- Uso compartido
Check 'F3-5' "Panel 'Red' quitado del Explorador" ((RegVal "$hkcu\SOFTWARE\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" 'System.IsPinnedToNameSpaceTree') -eq 0) ''
Info 'F3-5' 'NetBT Start' "$(RegVal 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT' 'Start')"

# ---------------------------------------------------------------- Entorno
Check 'B2-9' 'DOTNET_CLI_TELEMETRY_OPTOUT de maquina' ([Environment]::GetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', 'Machine') -eq '1') ''
Check 'B2-9' 'POWERSHELL_TELEMETRY_OPTOUT de maquina' ([Environment]::GetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'Machine') -eq '1') ''

# ---------------------------------------------------------------- AppX
foreach ($p in 'MicrosoftCorporationII.QuickAssist', 'MicrosoftWindows.CrossDevice', 'Microsoft.Copilot', 'Microsoft.ScreenSketch') {
    $inst = Get-AppxPackage -AllUsers -Name "$p*"
    $prov = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "$p*"
    Check 'D4' "AppX quitado: $p" (!$inst -and !$prov) ("instalado={0} aprovisionado={1}" -f [bool]$inst, [bool]$prov)
}
$dep = (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned').PSChildName
Check 'F3-8' 'Frameworks no desaprovisionados' (!($dep -match 'WindowsAppRuntime|VCLibs|UI\.Xaml|NET\.Native')) (($dep -match 'WindowsAppRuntime|VCLibs|UI\.Xaml|NET\.Native') -join ', ')
Info 'F3-8' 'Deprovisioned' ($dep -join ', ')
Check 'D3' 'Seguridad de Windows (SecHealthUI) presente' ([bool](Get-AppxPackage -AllUsers -Name 'Microsoft.SecHealthUI')) ''

# ---------------------------------------------------------------- Servicios / claves inexistentes
foreach ($s in 'diagnosticshub.standardcollector.service', 'GpuEnergyDrv', 'Telemetry') {
    Check 'B5-2' "Sin clave de servicio vacia: $s" (!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\$s")) ''
}
Check 'B5-4' 'Sin clave ValueBanner creada' (!(Test-Path 'HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\ValueBanner.IdealStateFeatureControlProvider')) ''
Check 'B2-1' 'Modulo FXPSYaml no instalado' (!(Get-Module -ListAvailable -Name FXPSYaml)) ''

# ---------------------------------------------------------------- AutoPlay / Spotlight / Accesibilidad
$ap = "$hkcu\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers"
foreach ($sub in 'EventHandlersDefaultSelection\CameraAlternate\ShowPicturesOnArrival', 'EventHandlersDefaultSelection\StorageOnArrival', 'UserChosenExecuteHandlers\CameraAlternate\ShowPicturesOnArrival', 'UserChosenExecuteHandlers\StorageOnArrival') {
    $v = (Get-ItemProperty -LiteralPath "$ap\$sub").'(default)'
    Check 'B2-10' "AutoPlay $sub" ($v -eq 'MSTakeNoAction') "(Predeterminado)='$v'"
}
Check 'B2-4' 'Spotlight NewStartPanel correcto, sin NewStartPanelt' ((RegVal "$hkcu\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" '{2cc5ca98-6485-489a-920e-b3e88a6ccce3}') -eq 1 -and !(Test-Path "$hkcu\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanelt")) ''
foreach ($a in 'HighContrast', 'Keyboard Response', 'MouseKeys', 'StickyKeys', 'ToggleKeys') {
    $p = "$hkcu\Control Panel\Accessibility\$a"
    Check 'B2-12' "Flags $a REG_SZ 0" ((RegKind $p 'Flags') -eq 'String' -and (RegVal $p 'Flags') -eq '0') ("tipo={0} valor={1}" -f (RegKind $p 'Flags'), (RegVal $p 'Flags'))
}

# ---------------------------------------------------------------- Edge
Check 'B1-1' 'Edge desinstalado' (!(Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe")) ''
$left = @(Get-ChildItem "$env:windir\Temp", $env:TEMP -Recurse -Filter 'RemoveEdge.exe' -ErrorAction SilentlyContinue)
Check 'B1-1' 'Sin Remove-Edge.exe en carpetas temporales' ($left.Count -eq 0) (($left.FullName) -join ', ')

# ---------------------------------------------------------------- Cuentas (CLIENTCBS)
Info 'B5-1' 'SettingsPageVisibility' "$(RegVal 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'SettingsPageVisibility')"

# ---------------------------------------------------------------- Logs
Add ''
Add "Resumen: $script:ok OK, $script:bad FALLO"
Add ''
Add '==================== postReboot.log'
if (Test-Path $log) { Get-Content $log | ForEach-Object { Add $_ } } else { Add '(no existe)' }

$lines | Set-Content -Path $out -Encoding UTF8
$ameLogs = Get-ChildItem "$env:ProgramData\AME\Logs" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($ameLogs) { Copy-Item $ameLogs.FullName -Destination (Join-Path $outDir "ame-log-$Nombre-$stamp") -Recurse -Force }
Write-Host "Resultado: $script:ok OK, $script:bad FALLO" -ForegroundColor Cyan
Write-Host "Guardado en $out" -ForegroundColor Green
