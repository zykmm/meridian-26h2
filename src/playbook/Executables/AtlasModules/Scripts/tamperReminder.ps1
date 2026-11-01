# Atlas 26H2 (F3-19): AME requires Tamper Protection to be turned off to install Atlas and Windows doesn't allow
# turning it back on from a script. With 'defender-enable', remind the user once (HKLM RunOnce) after the reboot.
try {
    if ((Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected) { exit 0 }
} catch {
    exit 0
}

Add-Type -AssemblyName PresentationFramework
$message = "Para instalar Atlas se desactivó la Protección contra alteraciones de Microsoft Defender.`n`n" +
    "Vuelve a activarla en: Seguridad de Windows > Protección antivirus y contra amenazas > " +
    "Administrar la configuración > Protección contra alteraciones.`n`n" +
    "Tamper Protection was turned off to install Atlas. Please turn it back on in Windows Security."
[void][System.Windows.MessageBox]::Show($message, 'Atlas', 'OK', 'Warning')
Start-Process 'windowsdefender://threatsettings'
