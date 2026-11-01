**Meridian 26H2: fork no oficial de AtlasOS 0.5.0 para Windows 11 26H2 (build 26300).** No pertenece al equipo de Atlas ni está respaldado por él. Los errores se reportan en [issues](https://github.com/zykmm/meridian-26h2/issues), nunca a Atlas.

### Descarga
- `Meridian-26H2-v*.apbx`: el playbook para [AME Wizard](https://ameliorated.io) (ZIP con la contraseña `malte`).
- `*.apbx.sha256`: compruébalo con `(Get-FileHash .\Meridian-26H2-v1.0.0.apbx).Hash`.

Este paquete lo compiló GitHub Actions a partir del código de esta etiqueta.

### Requisitos
Windows 11 26H2 (build 26300) actualizado, la última versión de AME Wizard, Internet, sin antivirus de terceros y **una copia de seguridad**: no hay desinstalador.

### Novedades respecto a AtlasOS 0.5.0
Adaptación a 26H2 con 79 cambios documentados: Widgets y navegador tras el reinicio (UCPD), un bloqueo de versión que funciona, Edge fijado y comprobado con SHA256, Copilot sin restos, reglas de firewall independientes del idioma, apps nuevas de 26H2, opciones del asistente respetadas y estados coherentes con Atlas Toolbox. Lista completa en [`CAMBIOS-26H2.md`](https://github.com/zykmm/meridian-26h2/blob/main/CAMBIOS-26H2.md).

### Problemas conocidos
Atlas Toolbox 0.1.13 tiene fallos propios al mostrar algunos estados, y Defender puede marcar `Remove-Edge.exe` por reputación. Detalles en el [README](https://github.com/zykmm/meridian-26h2#problemas-conocidos).
