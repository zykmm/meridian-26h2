# Contribuir a Meridian 26H2

1. Abre primero un issue para hablar del cambio.
2. Haz los cambios en `src/playbook`. Los `.cmd` van en CRLF; los `.ps1`, con sangría de 4 espacios.
3. Valida antes de enviar:
   ```powershell
   python tools/ame_conf_check.py src/playbook/playbook.conf
   ```
4. Compila y prueba en una **máquina virtual** con Windows 11 26H2 (ver «Compilar desde el código» en el README).
5. Apunta cada cambio en `CAMBIOS-26H2.md` con su motivo.

La guía de desarrollo original de AtlasOS sigue siendo útil para entender el playbook: <https://docs.atlasos.net/contributing/playbook/>.
