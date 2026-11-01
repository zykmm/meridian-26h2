if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
}

$windir = [Environment]::GetFolderPath('Windows')
$atlasDesktop = "$windir\AtlasDesktop"
$folderItems = Get-ChildItem -Path "$atlasDesktop\*" -File -Recurse
$pattern = "\(default\)\.cmd"

# Atlas 26H2 (D1/F3-6): this now runs on clean installs too (it used to be 'onUpgrade: true' only), so the
# '(default)' scripts must respect the options chosen in the wizard. default.yml writes them to SetupOptions.
$options = Get-ItemProperty -Path 'HKLM:\SOFTWARE\AtlasOS\SetupOptions' -ErrorAction SilentlyContinue
$replacements = @{}
if ($options.AutoUpdates -ne 'disable') {
  # 'auto-updates-default': don't disable automatic updates, run the opposite script instead (B3-1)
  $replacements['Disable Automatic Updates (default).cmd'] = "$atlasDesktop\3. General Configuration\Automatic Updates\Enable Automatic Updates.cmd"
}
if ($options.Hibernation -ne 'disable') {
  # 'disable-hibernation' not selected: keep the Windows default (B3-2)
  $replacements['Disable Hibernation (default).cmd'] = $null
}
if ($options.Defender -eq 'enable') {
  # Defender kept: don't hide 'App & browser control' in Windows Security (D3/B3-6)
  $replacements['Hide App and Browser Control (default).cmd'] = "$atlasDesktop\7. Security\Defender\Hide App and Browser Control\Show App and Browser Control.cmd"
}

foreach ($script in $folderItems)
{
  if ($script.PSChildName -match $pattern) {
    if ($replacements.ContainsKey($script.PSChildName)) {
      $replacement = $replacements[$script.PSChildName]
      if ($replacement) {
        Write-Host "$($script.PSChildName) -> $(Split-Path $replacement -Leaf)"
        Start-Process -FilePath $replacement -ArgumentList "/silent /noAction" -Wait
      } else {
        Write-Host "$($script.PSChildName) -> skipped"
      }
      continue
    }
    Write-Host $script.PSChildName
    Start-Process -FilePath $script.FullName -ArgumentList "/silent /noAction" -Wait
  }
}

# Keep the Atlas folder state of hibernation in line with reality when it isn't disabled
if ($options.Hibernation -ne 'disable') {
  $key = 'HKLM:\SOFTWARE\AtlasOS\Services\Hibernation'
  if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
  Set-ItemProperty -Path $key -Name 'state' -Value 1 -Type DWord
  Set-ItemProperty -Path $key -Name 'path' -Value "$atlasDesktop\3. General Configuration\Hibernation\Enable Hibernation.cmd" -Type String
}
exit 0
