# Atlas 26H2 - post-reboot actions
# Some settings can't be applied while the playbook runs because the User Choice Protection Driver (UCPD)
# is still loaded and blocks them (Widgets policies and the default browser/file associations).
# The playbook sets UCPD to disabled; after the reboot it is no longer loaded, so this script applies them.
# Runs as SYSTEM at logon (scheduled task 'AtlasPostReboot'), retries on the next logon if something fails,
# and removes its own task when everything is applied (or after 5 attempts).

$ErrorActionPreference = 'Continue'
$windir = [Environment]::GetFolderPath('Windows')
$scripts = "$windir\AtlasModules\Scripts"
$logFile = "$windir\AtlasModules\Logs\postReboot.log"
$stateKey = 'HKLM:\SOFTWARE\AtlasOS\PostReboot'
$taskName = 'AtlasPostReboot'
$maxAttempts = 5

New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null
function Write-Log([string]$Message) {
    "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message | Add-Content -Path $logFile -Encoding UTF8
}
function Complete-Task([string]$Message) {
    Write-Log $Message
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    exit 0
}

# 'New-Item -Force' on a registry key that already exists recreates it empty (values and subkeys are lost),
# so keys are only created when they don't exist
if (!(Test-Path $stateKey)) { New-Item -Path $stateKey -Force | Out-Null }
$attempt = [int](Get-ItemProperty -Path $stateKey -Name 'Attempts' -ErrorAction SilentlyContinue).Attempts + 1
Set-ItemProperty -Path $stateKey -Name 'Attempts' -Value $attempt -Type DWord
Write-Log "Attempt $attempt of $maxAttempts"

# Give the user profile time to finish loading (Volatile Environment is needed to detect logged on users)
Start-Sleep -Seconds 20

# 1. UCPD must not be loaded
$ucpdRunning = (Get-CimInstance -ClassName Win32_SystemDriver -Filter "Name='UCPD'" -ErrorAction SilentlyContinue).State -eq 'Running'
if ($ucpdRunning) {
    Write-Log 'UCPD is still loaded. Keeping it disabled and retrying on the next logon.'
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\UCPD' -Name 'Start' -Value 4 -Type DWord -ErrorAction SilentlyContinue
    Disable-ScheduledTask -TaskPath '\Microsoft\Windows\AppxDeploymentClient\' -TaskName 'UCPD velocity' -ErrorAction SilentlyContinue | Out-Null
    if ($attempt -ge $maxAttempts) { Complete-Task 'Giving up: UCPD is still loaded after the maximum number of attempts.' }
    exit 1
}

$success = $true

# 2. Widgets (News and Interests) policies
foreach ($policy in @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests' },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'; Name = 'EnableFeeds' }
    )) {
    if (!(Test-Path $policy.Path)) { New-Item -Path $policy.Path -Force -ErrorAction SilentlyContinue | Out-Null }
    New-ItemProperty -Path $policy.Path -Name $policy.Name -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    if ((Get-ItemProperty -Path $policy.Path -Name $policy.Name -ErrorAction SilentlyContinue).($policy.Name) -eq 0) {
        Write-Log "OK: $($policy.Path)\$($policy.Name) = 0"
    } else {
        Write-Log "FAILED: $($policy.Path)\$($policy.Name)"
        $success = $false
    }
}

# 3. Default browser and file associations for the logged on users
$browser = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\AtlasOS\SetupOptions' -Name 'browser' -ErrorAction SilentlyContinue).browser
$edgeInstalled = Test-Path "$([Environment]::GetFolderPath('ProgramFilesX86'))\Microsoft\Edge\Application\msedge.exe"
$expectedProgId = @{
    'Brave'         = 'BraveHTML'
    'LibreWolf'     = 'LibreWolfHTM'
    'Firefox'       = 'FirefoxURL-308046B0AF4A39CB'
    'Google Chrome' = 'ChromeHTML'
}

if (![string]::IsNullOrEmpty($browser)) {
    Write-Log "Setting associations for '$browser'"
    & cmd.exe /c "`"$scripts\fileAssoc.cmd`" `"$browser`"" | ForEach-Object { Write-Log "  $_" }
} elseif ($edgeInstalled) {
    Write-Log 'No browser selected, Edge kept: setting base associations'
    & cmd.exe /c "`"$scripts\fileAssoc.cmd`"" | ForEach-Object { Write-Log "  $_" }
} else {
    Write-Log 'No browser selected and Edge removed: no browser associations to set'
}

if ($expectedProgId.ContainsKey("$browser")) {
    $users = Get-ChildItem 'Registry::HKEY_USERS' | Where-Object {
        $_.PSChildName -match '^S-1-5-21-[\d-]+$' -and (Test-Path "Registry::$($_.Name)\Volatile Environment")
    }
    foreach ($user in $users) {
        $progId = (Get-ItemProperty -Path "Registry::$($user.Name)\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" -Name 'ProgId' -ErrorAction SilentlyContinue).ProgId
        if ($progId -eq $expectedProgId[$browser]) {
            Write-Log "OK: http -> $progId for $($user.PSChildName)"
        } else {
            Write-Log "FAILED: http -> '$progId' for $($user.PSChildName) (expected $($expectedProgId[$browser]))"
            $success = $false
        }
    }
}

# 4. Taskbar pins that Explorer writes again when it starts after the playbook (F3-10). Cosmetic, so it doesn't
#    count for the success check
$loggedOnUsers = Get-ChildItem 'Registry::HKEY_USERS' | Where-Object {
    $_.PSChildName -match '^S-1-5-21-[\d-]+$' -and (Test-Path "Registry::$($_.Name)\Volatile Environment")
}
foreach ($user in $loggedOnUsers) {
    $pins = "Registry::$($user.Name)\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins"
    if (!(Test-Path $pins)) { New-Item -Path $pins -Force -ErrorAction SilentlyContinue | Out-Null }
    foreach ($pin in 'MailPin', 'CopilotPWAPin') {
        New-ItemProperty -Path $pins -Name $pin -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Log "Taskbar pins (MailPin, CopilotPWAPin) = 0 for $($user.PSChildName)"
}

if ($success) {
    Complete-Task 'All post-reboot actions applied.'
} elseif ($attempt -ge $maxAttempts) {
    Complete-Task 'Giving up after the maximum number of attempts.'
} else {
    Write-Log 'Some actions failed, retrying on the next logon.'
    exit 1
}
