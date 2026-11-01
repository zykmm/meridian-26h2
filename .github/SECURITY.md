# Política de seguridad

Meridian 26H2 es un fork **no oficial** de AtlasOS. Si encuentras una vulnerabilidad causada por Meridian (scripts, configuración o binarios incluidos):

- **No abras un issue público.** Usa [«Report a vulnerability»](https://github.com/zykmm/meridian-26h2/security/advisories/new) en la pestaña *Security* de este repositorio.
- Indica la versión de Meridian, la build de Windows y los pasos para reproducirlo.

Los fallos que también ocurren en Windows sin modificar van a Microsoft (<https://msrc.microsoft.com>). Los de AME Wizard, a Ameliorated (<https://ameliorated.io>). Los del Atlas oficial, a su repositorio (<https://github.com/Atlas-OS/Atlas>).

## Binarios incluidos
El playbook contiene binarios compilados por el proyecto Atlas (código en <https://github.com/Atlas-OS/utilities>; hashes en `src/playbook/Executables/AtlasModules/README.md`). `Remove-Edge.exe` se descarga durante la instalación, fijado a la versión 2.3 y comprobado con su SHA256; si no coincide, no se ejecuta.
