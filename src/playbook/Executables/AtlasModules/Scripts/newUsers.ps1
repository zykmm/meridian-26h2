if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
  Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit 
}

$windir = [Environment]::GetFolderPath('Windows')
& "$windir\AtlasModules\initPowerShell.ps1"
$atlasDesktop = "$windir\AtlasDesktop"
$atlasModules = "$windir\AtlasModules"

$title = 'Preparing Atlas user settings...'

if (!(Test-Path $atlasDesktop) -or !(Test-Path $atlasModules)) {
    Write-Host "Atlas was about to configure user settings, but its files weren't found. :(" -ForegroundColor Red
    Read-Pause
    exit 1
}

$Host.UI.RawUI.WindowTitle = $title
Write-Host $title -ForegroundColor Yellow
Write-Host $('-' * ($title.length + 3)) -ForegroundColor Yellow
Write-Host "You'll be logged out in 10 to 20 seconds, and once you login again, your new account will be ready for use."

# Disable Windows 11 context menu & 'Gallery' in File Explorer
if ([System.Environment]::OSVersion.Version.Build -ge 22000) {
    & "$atlasDesktop\4. Interface Tweaks\Context Menus\Windows 11\Old Context Menu (default).cmd" /silent
    & "$atlasDesktop\4. Interface Tweaks\File Explorer Customization\Gallery\Disable Gallery (default).cmd" /silent

    # Set ThemeMRU (recent themes)
    Set-Theme -Path "$([Environment]::GetFolderPath('Windows'))\Resources\Themes\atlas-v0.5.x-dark.theme"
    Set-ThemeMRU | Out-Null
}

# Set lockscreen wallpaper
Set-LockscreenImage

# Disable 'Network' in navigation pane
& "$atlasDesktop\3. General Configuration\File Sharing\Network Navigation Pane\Disable Network Navigation Pane (default).cmd" /silent

# Disable Automatic Folder Discovery
& "$atlasDesktop\4. Interface Tweaks\File Explorer Customization\Automatic Folder Discovery\Disable Automatic Folder Discovery (default).cmd" /silent

# Set visual effects
& "$atlasDesktop\4. Interface Tweaks\Visual Effects (Animations)\Atlas Visual Effects (default).cmd" /silent

# Set taskbar pins
# Atlas 26H2: the value doesn't exist when no browser was selected, don't stop the script (B2-11)
$valueName = "Browser"
$value = Get-ItemProperty -Path "HKLM:\SOFTWARE\AtlasOS\SetupOptions" -Name $valueName -ErrorAction SilentlyContinue
$Browser = $value.$valueName
$Browser

& "$atlasModules\Scripts\taskbarPins.ps1" $Browser

# Atlas 26H2: set the default browser and file associations for this new user (F3-21)
# UCPD is disabled by Atlas, so the UserChoice keys can be written here
if (![string]::IsNullOrEmpty($Browser)) {
    & cmd.exe /c "`"$atlasModules\Scripts\fileAssoc.cmd`" `"$Browser`""
} elseif (Test-Path "$([Environment]::GetFolderPath('ProgramFilesX86'))\Microsoft\Edge\Application\msedge.exe") {
    & cmd.exe /c "`"$atlasModules\Scripts\fileAssoc.cmd`""
}

# Atlas 26H2: Windows (first logon) and Set-Theme overwrite these values that Atlas sets in the Default profile (F3-20)
$userSettings = @(
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Value = 1; Type = 'DWord' },
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'ContentDeliveryAllowed'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Name = 'GlobalUserDisabled'; Value = 1; Type = 'DWord' },
    @{ Path = 'HKCU:\Control Panel\Colors'; Name = 'InfoWindow'; Value = '246 253 255'; Type = 'String' },
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins'; Name = 'MailPin'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins'; Name = 'CopilotPWAPin'; Value = 0; Type = 'DWord' }
)
foreach ($setting in $userSettings) {
    if (!(Test-Path $setting.Path)) { New-Item -Path $setting.Path -Force | Out-Null }
    Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -Force
}

# Leave
Start-Sleep 5 
logoff