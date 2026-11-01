# Atlas 26H2 (F5-5): since Copilot 154 (October 2026) the 'Microsoft.Copilot' AppX is a host package for a
# Chromium-based app that Microsoft Edge Update installs in 'Program Files (x86)\Microsoft\Copilot' (about 1.1 GB).
# Removing the AppX (atlas/appx.yml) leaves that app, its elevation service, its 'Copilot' entry in Apps and its
# Edge Update registration, so this runs the app's own uninstaller and then removes whatever is left.

$installDir = Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Copilot'
$copilotGuid = '{C50565E9-CCCF-44B4-BA15-5AC5C6569197}'
$uninstallKeys = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Copilot',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Copilot'
)

function Write-Log([string]$Text) { Write-Output "[RemoveCopilotApp] $Text" }

if (!(Test-Path $installDir) -and !($uninstallKeys | Where-Object { Test-Path $_ })) {
    Write-Log 'Copilot app not installed, nothing to do.'
    exit 0
}

# Official uninstaller: the same Chromium installer as Edge, '--force-uninstall' skips its confirmation dialog
foreach ($key in $uninstallKeys) {
    $uninstallString = (Get-ItemProperty -Path $key -Name 'UninstallString' -ErrorAction SilentlyContinue).UninstallString
    if (!$uninstallString) { continue }
    if ($uninstallString -notmatch '^\s*"([^"]+)"\s*(.*)$') {
        Write-Log "Unexpected UninstallString: $uninstallString"
        continue
    }
    $exe = $Matches[1]
    $arguments = $Matches[2]
    if (!(Test-Path $exe)) {
        Write-Log "Uninstaller not found: $exe"
        continue
    }
    if ($arguments -notmatch '--force-uninstall') { $arguments += ' --force-uninstall' }
    Write-Log "Running `"$exe`" $arguments"
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $null = $process.Handle
    if ($process.WaitForExit(300000)) {
        Write-Log "Uninstaller exit code: $($process.ExitCode)"
    } else {
        Write-Log 'Uninstaller still running after 5 minutes, stopping it.'
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# The uninstaller can finish deleting its folder from a copy of itself, give it some time
for ($i = 0; $i -lt 30 -and (Test-Path "$installDir\Application"); $i++) { Start-Sleep -Seconds 2 }

# Leftovers, also when there was no uninstaller or it failed
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$installDir\*" } |
    Stop-Process -Force -ErrorAction SilentlyContinue

Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -like "*\Microsoft\Copilot\*" } |
    ForEach-Object {
        Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
        & sc.exe delete $_.Name | Out-Null
        Write-Log "Deleted service $($_.Name)"
    }

if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $installDir) { Write-Log "Couldn't fully delete $installDir" } else { Write-Log "Deleted $installDir" }
}

$leftoverKeys = $uninstallKeys + @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$copilotGuid",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState\$copilotGuid",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientStateMedium\$copilotGuid",
    'HKLM:\SOFTWARE\Microsoft\Copilot'
)
foreach ($key in $leftoverKeys) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Deleted $key"
    }
}

# Shortcuts that point to the removed app (Start menu, Quick Launch and taskbar pins, including the system profile)
$shell = New-Object -ComObject WScript.Shell
$profiles = @(Get-ChildItem -Path "$env:SystemDrive\Users" -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { !($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } | ForEach-Object { $_.FullName })
$profiles += "$env:windir\System32\config\systemprofile"
$shortcutFolders = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs")
foreach ($userProfile in $profiles) {
    $shortcutFolders += "$userProfile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
    $shortcutFolders += "$userProfile\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch"
}
# One folder at a time: an access denied error stops Get-ChildItem for the whole pipeline
foreach ($folder in ($shortcutFolders | Where-Object { Test-Path -LiteralPath $_ -ErrorAction SilentlyContinue })) {
    try {
        Get-ChildItem -LiteralPath $folder -Filter '*.lnk' -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $shell.CreateShortcut($_.FullName).TargetPath -like "$installDir\*" } |
            ForEach-Object {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Log "Deleted shortcut $($_.FullName)"
            }
    } catch {
        Write-Log "Couldn't search shortcuts in ${folder}: $($_.Exception.Message)"
    }
}

exit 0
