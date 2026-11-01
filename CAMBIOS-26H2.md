# Meridian 26H2 — registro de cambios respecto a AtlasOS v0.5.0

Meridian 26H2 es un fork **no oficial** del playbook de AtlasOS v0.5.0 (commit `6c26aab` de
[Atlas-OS/Atlas](https://github.com/Atlas-OS/Atlas)), que se publicó para Windows 11 24H2 y 25H2.
Este documento recoge cada cambio hecho para Windows 11 26H2 (build 26300). Cada fila lleva el ID del
hallazgo de la auditoría propia (B…, F3-…, F5-…, D…) y el motivo. Durante el desarrollo el proyecto
se llamó «Atlas v0.5.1 (26H2)»; la sección 12 explica el cambio de nombre.
Decisiones de diseño: D1-D8 aceptadas; D9 (Zen Browser) descartada.

## 1. Compatibilidad 26H2 y versión
| ID | Archivo | Cambio |
|---|---|---|
| 26H2 | `playbook.conf` | `SupportedBuilds` añade `26300` (26H2); `Version` 0.5.1; `Title` "Atlas v0.5.1 (26H2)" |
| B4-14 | `tweaks/misc/config-oem-information.yml` | Vuelve el marcador `AtlasVersionUndefined` para que `local-build.ps1` ponga la versión de `playbook.conf` |

## 2. UCPD: Widgets, navegador predeterminado y usuarios nuevos
| ID | Archivo | Cambio |
|---|---|---|
| F3-1, F3-21 | `Executables/AtlasModules/Scripts/postReboot.ps1` (nuevo) | Tras el reinicio (UCPD ya descargado) escribe las directivas de Widgets y aplica las asociaciones del navegador elegido a los usuarios con sesión; verifica `http` → ProgId esperado, registra en `AtlasModules\Logs\postReboot.log`, reintenta en el siguiente inicio de sesión (máx. 5) y elimina su tarea |
| F3-1, F3-21 | `tweaks/scripts/script-file-associations.yml` | Ya no lanza `FILEASSOC.cmd` durante la instalación (UCPD lo bloqueaba); registra la tarea `AtlasPostReboot` (SYSTEM, al iniciar sesión, retraso 30 s) |
| F3-1 | `tweaks.yml` | Se comenta `disable-news-and-interests.yml` (fallaba siempre: "acceso denegado"); lo aplica `postReboot.ps1` |
| F3-21 | `AtlasModules/Scripts/ASSOC.ps1` (copia), `fileAssoc.cmd` | `ASSOC.ps1` copiado a `AtlasModules\Scripts`; `fileAssoc.cmd` hace `cd /d "%~dp0"` para encontrarlo |
| B2-2 | `tweaks/qol/taskbar/config-pins.yml:48` | `browser=""` solo con `!install-another-browser` (antes con `browser-librewolf`, pisaba "LibreWolf") |
| B2-11 | `AtlasModules/Scripts/newUsers.ps1` | Ya no se detiene si no se eligió navegador (`-ErrorAction SilentlyContinue`) |
| F3-21 | `newUsers.ps1` | Aplica las asociaciones del navegador al usuario nuevo (UCPD desactivado por Atlas) |
| F3-20 | `newUsers.ps1` | Re-aplica al final `SearchboxTaskbarMode=1`, `ContentDeliveryAllowed=0`, `GlobalUserDisabled=1`, `InfoWindow` (tooltips azules), `MailPin=0`, `CopilotPWAPin=0` |
| F3-19 | `tweaks/misc/tamper-protection-reminder.yml` (nuevo, `defender-enable`), `AtlasModules/Scripts/tamperReminder.ps1` (nuevo) | `RunOnce` que, si la protección contra alteraciones sigue apagada, avisa y abre la página de Seguridad de Windows |

## 3. Bloqueo de versión y valores por defecto de la carpeta Atlas
| ID | Archivo | Cambio |
|---|---|---|
| B2-3, F3-2 | `tweaks/qol/windows-update/disable-feature-updates.yml` | La versión se escribe en `TargetReleaseVersionInfo` (antes pisaba `TargetReleaseVersion`=1 con texto) |
| D1, F3-6, B3-1, B3-2, B3-6, D3 | `atlas/default.yml`, `Executables/DEFAULT.ps1` | `DEFAULT.ps1` se ejecuta también en instalación limpia (antes `onUpgrade: true`). `default.yml` guarda las opciones en `SetupOptions` (`AutoUpdates`, `Hibernation`, `Defender`) y `DEFAULT.ps1` las respeta: con actualizaciones automáticas ejecuta `Enable Automatic Updates.cmd`; sin la casilla de hibernación la deja como Windows (estado 1); con Defender activado ejecuta `Show App and Browser Control.cmd` |
| F3-14, P-1, B3-3 | `Remove/Add Idle Toggle in Desktop Context Menu*.cmd`, `DEFAULT.reg` | `settingName` propio `CpuIdleContextMenu` (0/1); `AutomaticUpdates` en `DEFAULT.reg` apunta a su script (estado 0) |
| F3-13 | `DEFAULT.reg` | Estados que faltaban: `MicrosoftStore`, `ModernDateTime`, `ModernVolumeFlyout`, `ModernBatteryFlyout`, `RunWithPriority`, `CpuIdleContextMenu`; `ContextMenuTerminals` 3 → 0 |
| F3-13 | `Add Terminals.cmd` (1), `Add Terminals (no Windows Terminal).cmd` (2) | Misma numeración que Toolbox: 0 quitado, 1 completo, 2 mínimo |
| B4-9 | `Scripts/Registry/Terminals/{enabled,disabled,minimal}.reg` | Quitadas las líneas que escribían el estado en claves equivocadas |
| B4-10 | `Show App and Browser Control.cmd` | Estado 1 al mostrar (antes 0, igual que "Hide") |
| B4-10 | `Modern Battery Flyout (default) copy.cmd` → `Modern Battery Flyout (default).cmd` | Era la única variante "moderna" y por el nombre nunca se ejecutaba |
| F3-11 | `Disable Shortcut Text (default).cmd` | `%%s.lnk` (cmd eliminaba el `%` y escribía `"s.lnk"`; comprobado con `echo`) |
| F3-15, P-4 | `Disable Recent Items (default).cmd` | `ShowOrHideMostUsedApps=2` (Ocultar); antes 1 (Mostrar) |
| B2-6 | `Show Lock Screen (default).cmd` | `reg delete` sin `/t` (sintaxis inválida) |
| B2-8 | `Disable/Enable Sleep Study*.cmd` | `wevtutil sl /e:false` / `/e:true` (antes `/q`, que es "quiet") |
| B2-13 | `Enable/Disable FSO and Game Bar Support*.cmd` | Ruta `HKCU\SOFTWARE\Microsoft\GameBar` (antes `HKCU\System\GameBar`, que Windows no usa) |

## 4. Uso compartido de archivos, Core Isolation y firewall
| ID | Archivo | Cambio |
|---|---|---|
| F3-5, B1-3 | `ScriptWrappers/DisableFileSharing.ps1` | Ejecuta `Disable Network Navigation Pane (default).cmd` y `Disable Give Access To Menu (default).cmd` con `/silent` en lugar de importar dos `.reg` que no existen ("Error al abrir el archivo" ×2 en la VM) |
| B4-8 | `ScriptWrappers/EnableFileSharing.ps1` | `NetbiosOptions=0` (predeterminado de Windows: lo decide el DHCP); antes ponía 2 (desactivado) al ACTIVAR. Las dos preguntas ejecutan `User Network Navigation Pane choice.cmd` y `Enable Give Access To Menu.cmd` en lugar de `.reg` inexistentes. Espera (`-Wait`) a que termine `Enable Network Discovery Services`. Comentario corregido ("Enable … firewall rules") |
| B4-8 | `Enable Give Access To Menu.cmd` | Admite `/silent` (antes se quedaba en `pause`) |
| B4-10 | `Disable Network Discovery Services.cmd` | Llama a `Disable Network Navigation Pane (default).cmd /silent` en lugar de importar un `.reg` inexistente |
| F3-3 | `ScriptWrappers/ConfigVBS.ps1` | Crea la clave `…\Scenarios\HypervisorEnforcedCodeIntegrity` si no existe (en la VM `New-ItemProperty` fallaba y la integridad de memoria no quedaba desactivada explícitamente); lo mismo en `-EnableMemoryIntegrity` |
| D5, B3-5 | `ConfigVBS.ps1` | "Disable Core Isolation" ya no pone `Lsa\RunAsPPL=0`: la protección LSA no es parte de Core Isolation y el asistente no lo decía |
| B4-4 | `7. Security/Core Isolation (VBS)/Enable VBS.cmd` | Estado 1 (antes 0, igual que "Disable"); borra también los `Enabled=0` de `KernelShadowStacks` y `CredentialGuard` que pone la opción del asistente (vuelven al valor de Windows) |
| — | `tweaks/scripts/script-core-isolation.yml` | Escribe el estado `VbsState`=0 → `Disable VBS.cmd` (no estaba en `DEFAULT.reg`) |
| F3-4 | `tweaks/security/disable-remote-assistance.yml` | Las reglas de Asistencia remota se desactivan por el grupo indirecto `@FirewallAPI.dll,-33002` (igual en todos los idiomas; comprobado en el host: 15 reglas). `netsh … group="Remote Assistance"` no encontraba nada en Windows en español |

## 5. Interacciones durante el despliegue, descargas y asistente
| ID | Archivo | Cambio |
|---|---|---|
| B1-1, F3-7 | `ScriptWrappers/RemoveEdge.ps1` | `Remove-Edge.exe` fijado a la release **2.3** (2025-12-11, la misma que "latest" usó en las pruebas de la VM) y comprobado con su SHA256 publicado por GitHub (`95BDAFFA…EE53D2`, 9 620 168 bytes); si no coincide, no se ejecuta. Sin `Read-Host`/`exit`: con `-NonInteractive` lanzaba una excepción, devolvía `False` y `-RemoveEdgeData` nunca se ejecutaba. Borra la carpeta temporal al terminar y avisa si `msedge.exe` sigue existiendo |
| B1-1 (nota) | — | El Defender del host detecta `Remove-Edge.exe` 2.3 como `Trojan:Win32/Yomal!rfn` (heurística por reputación `!rfn`, típica de ejecutables PyInstaller). Durante AME no afecta (requisito `DefenderToggled`); por eso el archivo ya no se deja en `%TEMP%`. Ejecutar "Remove Edge" después desde la carpeta Atlas con Defender activo puede fallar (el script lo indica) |
| B1-7 | `Executables/SOFTWARE.ps1` | Ya no muestra un `MessageBox` en mitad del despliegue si 7-Zip está instalado: se conserva 7-Zip |
| B2-1 | `custom.yml`, `Executables/APPLYDUHIVE.ps1` (eliminado) | El paso "Applying hives..." no copiaba nada (`-like 'HKCU'` sin comodín) e instalaba NuGet + `FXPSYaml` desde PSGallery. AME ya aplica las acciones HKCU a `AME_UserHive_Default` |
| D6 | `playbook.conf` | Aviso (`TopLine`) en la página de "Remove Microsoft Edge": marcar también "Install a Browser". *Esta suposición era falsa: AME rechazó el playbook. Corregido en la sección 10 (F5-4)* |
| B4-11 | `ScriptWrappers/UpdateDrivers.ps1` | Restaura la `InstallationPolicy` previa de PSGallery tras instalar `PSWindowsUpdate` (antes quedaba "Trusted" para siempre) |

## 6. AppX, servicios, entorno y ajustes que no hacían nada
| ID | Archivo | Cambio |
|---|---|---|
| F3-8 | `atlas/appx.yml` | La lista previa y la comparación usan `Get-AppxPackage -PackageTypeFilter Main` (sin frameworks) y solo se desaprovisiona lo que se quitó (`SideIndicator '<='`). Antes se desaprovisionaba `Microsoft.WindowsAppRuntime.1.5` y también se habría desaprovisionado cualquier paquete instalado entretanto (`'=>'`). Probado en seco en el host |
| D4 | `atlas/appx.yml` | Se quitan `MicrosoftCorporationII.QuickAssist` y `MicrosoftWindows.CrossDevice` (nuevas en 26H2, presentes en la captura de la VM). Se mantienen Reproductor multimedia, Widgets (desactivados por directiva) y ApplicationCompatibilityEnhancements |
| B1-5 | `atlas/appx.yml` | `Ink.Handwriting.Main.Store*` (antes fijo `…en-US1.0`) |
| F3-17 | `atlas/appx.yml` | `clearCache` de `*Microsoft.SecHealthUI*` (antes `*Microsoft.Windows.SecHealthUI*`, que no coincidía con nada) |
| B1-8 | `atlas/start.yml` | `ignoreErrors: true` en `Remove-Capability App.StepsRecorder` |
| B5-2 | `atlas/services.yml` | `diagnosticshub.standardcollector.service`, `GpuEnergyDrv` y `Telemetry` solo se cambian si existen (`!powerShell` con `Test-Path`). AME creaba claves de servicio que solo contenían `Start` (log de la VM: "Seting value 'Start' in key …\Services\GpuEnergyDrv") |
| B2-9 | `disable-dotnet-cli-telemetry.yml`, `config-powershell.yml` | `setx /M`: la variable va a la máquina (antes solo al perfil de TrustedInstaller/SYSTEM) |
| B2-4 | `tweaks/qol/disable-windows-spotlight.yml` | Ruta `HideDesktopIcons\NewStartPanel` (antes con la errata `NewStartPanelt`) |
| B5-4 | `tweaks/qol/disable-win11-settings-banner.yml` | `ValueBanner.IdealStateFeatureControlProvider` solo se cambia si existe (en 26H2 limpio no existe y se creaba una clave con solo `ActivationType`) |
| B2-10 | `tweaks/qol/shell/config-autorun.yml` | "No realizar ninguna acción" en el valor (Predeterminado) `REG_SZ` `MSTakeNoAction`; la cámara en `…\CameraAlternate\ShowPicturesOnArrival`. Antes eran valores `REG_NONE` vacíos llamados `MSTakeNoAction` |
| F3-16, D7 | `tweaks.yml`, `remove-context-menus/new-bitmap.yml` y `new-rtf.yml` (eliminados) | Borraban `HKCR\.bmp\ShellNew` y `HKCR\.rtf\ShellNew`, que no existen en 26H2. "Nuevo → Imagen de mapa de bits" (Paint) y "Documento de texto" se mantienen (D7) |
| B5-1 | `Executables/CLIENTCBS.ps1` | También lee los dos `SettingsExtensions.json` de `AccountExperiences` (Client.CBS): tarjetas de Inicio de Microsoft 365, almacenamiento de OneDrive, Xbox, Copilot, comprobación de cuenta e "inicia sesión con una cuenta Microsoft", más la nueva portada de Cuentas. Se excluye el 62437734 ("Dispositivos vinculados", `ms-settings:linkeddevices`), que es una página real. Probado en seco en el host: 3 JSON, 18 IDs |
| B5-3 | `Toggle Windows Updates.cmd` | Quitadas las tareas `WindowsUpdate\sih` y `sihboot`, que ya no existen |

Validación del grupo: los 190 YAML cargan con PyYAML (entorno virtual aislado) y no hay ninguna `!task` que apunte a un archivo inexistente.

## 7. Scripts de la carpeta Atlas y estados coherentes con Atlas Toolbox
Referencia de estados: código fuente de **Atlas Toolbox 0.1.13** (la release que instala `SOFTWARE.ps1 -Toolbox`), cruzado servicio por servicio con los `.cmd` y `DEFAULT.reg` (`tbx_cross.py`).

| ID | Archivo | Cambio |
|---|---|---|
| F3-12, B2-7 | `Disable Printing.cmd` | Con `/justcontext` (lo usa `printing.yml`) ya no guarda `Printing state=0`: solo quita "Imprimir" del menú contextual |
| B4-1 | `Disable FSO and Game Bar Support.cmd` | El comando `Get-AppxPackage … \| Remove-AppxPackage` estaba escrito directamente en el `.cmd` y nunca se ejecutaba; ahora va por `powershell` con `-AllUsers` (el script corre como TrustedInstaller) |
| B4-2 | `Enable Windows Spotlight.cmd`, `Set/Reset Windows Update Deferral.cmd` | Quitada la línea que escribía en `AtlasOS\ServicesWindowsSpotlight`; las de aplazamiento escriben en `AtlasOS\Services\<nombre>` (faltaba `\`) |
| B4-3 | `Enable/Disable Removable Drives in Sidebar*.cmd`, `removable-drives-only-this-pc.yml` | Revertir crea `(Predeterminado)` REG_SZ "Removable Drives" (como en 26H2 limpio, comprobado en la captura de la VM); antes `REG_DWORD` con texto fallaba. La ruta WOW6432Node tenía el GUID dos veces |
| B4-5 | `Enable All Mitigations.cmd`, Toolbox `Mitigations_1.cmd` | El fabricante de CPU se lee del registro (`VendorIdentifier`) en el propio cmd; `$env:CPU` en un PowerShell hijo nunca volvía y `FeatureSettingsOverride` no se escribía. Probado en el host (`GenuineIntel` → 0) |
| B4-7 | `Enable All Mitigations.cmd` (1), `Set Windows Default Mitigations.cmd` (2) | Numeración de Toolbox: 0 desactivadas, 1 todas, 2 predeterminadas (`DEFAULT.reg` ya tenía 2) |
| B4-6 | `9. Troubleshooting/Safe Mode/*.cmd` | `set "stateValue=N"` (tenían `==N` y `reg add /d =N` fallaba) |
| **Corrección del grupo 3** | `Add Terminals.cmd` (0), `Add Terminals (no Windows Terminal).cmd` (1), `Remove Terminals Context Menu (default).cmd` (2), `DEFAULT.reg` (2) | En el grupo 3 apliqué 0 = quitado / 1 = completo / 2 = mínimo, deducido de los `.reg` de la Toolbox incluidos en el playbook. El código de Toolbox 0.1.13 muestra `options[state]` con 0 "Add terminals", 1 "Add terminals (no Windows Terminal)", 2 "Remove terminals"; con mi numeración habría mostrado "Add terminals" estando quitados |
| B4-10 | `Disable Verbose Messages (default).cmd`, `DEFAULT.reg` | Usa `VerboseStatusMessage` (el nombre de `Enable Verbose Messages.cmd` y de Toolbox) con estado 0; antes `VerboseMessages` = 1 |
| — | `Disable/Enable Microsoft Copilot*.cmd`, `DEFAULT.reg` | Clave `MicrosoftCopilot` (la de Toolbox); antes `Copilot` |
| — | `Disable/Enable App Icons on Thumbnails*.cmd`, `DEFAULT.reg` | Clave `AppIconsThumbnail` (la de Toolbox); antes `AppIconThumbnail` |
| — | `Old Context Menu (default).cmd`, `DEFAULT.reg` | Estado 1 (Toolbox: 1 = menú antiguo activado); antes 0, igual que "New Context Menu" |
| — | `Hide Lock Screen.cmd` | Estado 0 al ocultar (antes 1, igual que "Show") |
| B4-10 | `New Boot Menu.cmd` | Estado `REG_DWORD` (Toolbox compara con DWORD 1); antes `REG_SZ` |
| B4-10 | `Disable Bluetooth.cmd` | `exit /b` con `/silent` (antes `exit` cerraba el cmd que lo llamaba) |
| B4-10 | `Run Update Drivers.cmd` | `pause > nul` (antes `> null` creaba un archivo `null`) |
| B4-10 | `Enable Mobile Device Settings.cmd` | Ya no reactiva las actualizaciones automáticas de la Store (`AutoDownload=4`): no tiene relación con Enlace Móvil y pisaba la elección hecha al desactivarlo |
| B2-5 | `Reset Network to Atlas Default.cmd`, Toolbox `AtlasDefaults.cmd` | Configura todos los adaptadores físicos (PCI y USB) con una subrutina; antes solo el último PCI, y los `rem` dentro de la lista del `for` se tomaban como elementos. Prueba en seco en el host: recorre los 2 adaptadores (`…\0000` y `…\0011`) |
| B2-14 | `Executables/SETTABST.ps1` (eliminado) | Script huérfano (nadie lo llamaba) |

**Fallos de Atlas Toolbox 0.1.13 (aplicación externa, no se corrigen en el playbook; anotados como F5-2):**
- Terminals y Mitigations: `ChangeStatus` busca `C:\Windows\AtlasModues\…` (errata) y archivos `.reg`. Solo cambia el número de estado, no aplica nada.
- `HightestMode` (errata, distinta de la `HighestMode` de los scripts) con `IsEnabled` = estado 0.
- `SearchIndexing` invertido y con otra clave (los scripts usan `Indexing`).
- FileSharing: "Enable" escribe 0.
- FSOGameBar: "Disable" no escribe estado.
- SystemRestore: "Enable" no escribe estado.
- Copilot: ruta `%windir%AtlasModules` sin `\`.

## 8. Claves recreadas vacías, anclajes, tipo de `Flags` y comentario obsoleto
| ID | Archivo | Cambio |
|---|---|---|
| F5-1 (nuevo) | `AtlasModules/Scripts/postReboot.ps1` (grupo 2), `Executables/DEFAULT.ps1` (grupo 3) | `New-Item -Force` sobre una clave de registro existente la **recrea vacía**, borrando valores y subclaves. Comprobado en el host con una clave temporal de HKCU, ya eliminada. En `postReboot.ps1` borraba el contador `Attempts` en cada ejecución, así que el límite de 5 intentos nunca se alcanzaba, y vaciaba `Policies\Microsoft\Dsh` y `Windows Feeds` antes de escribir su valor. Ahora solo se crea la clave si no existe (`Test-Path`) |
| F5-1 | `ScriptWrappers/EnableFileSharing.ps1` (upstream) | Lo mismo con `NcdAutoSetup\Private` |
| F3-10 | `postReboot.ps1` | Tras el reinicio pone `MailPin` y `CopilotPWAPin` a 0 en `Taskband\AuxilliaryPins` de los usuarios con sesión, porque Explorer los reescribe al arrancar después del playbook. Es estético y no cuenta para el reintento. *Comprobar en la VM que se mantiene tras otro reinicio* |
| B2-12 | `tweaks/qol/ease-of-access/disable-annoying-features-shortcuts.yml` | `Flags` como `REG_SZ` "0", el tipo que usa Windows. Con DWORD 0 funcionaba igual (prueba 2: Mayús ×5 no abre Teclas especiales); solo corrige la coherencia |
| B1-2 | `atlas/components.yml` | Comentario obsoleto sobre un "paquete misceláneo" que quitaría OneDriveSetup; la desinstalación la hace `ONED.cmd` |

`ASSOC.ps1` también usa `New-Item -Force`, pero siempre dentro de un `If (-NOT (Test-Path …))`, así que no le afecta.

## 9. Hallazgos revisados que no requieren cambio en el playbook
| ID | Motivo |
|---|---|
| B3-4 | Prueba 2 en 26H2: `Disable All Mitigations.cmd` escribe una máscara completa de 24 bytes; no se manifiesta |
| B3-7 | Cubierto por D6 (aviso en el asistente) y por `postReboot.ps1` (sin navegador y sin Edge no intenta asociaciones) |
| B3-8, P-2 | Superados por D1/D8: `DEFAULT.ps1` corre en instalación limpia respetando las opciones, y no se soporta actualizar desde 0.5.0 |
| P-3 | Es B2-6 (corregido en el grupo 3) |
| V-1 | Cerrado en la fase 3 (la tarea de OneDrive desaparece) |
| V-2 | Comprobación visual abierta (buscador clásico del Explorador); no es un fallo |
| B4-12 | Los CAB autofirmados se instalaron bien en 26H2 (prueba 1 y 2); cambiarlo exige volver a firmarlos |
| B4-13 | En este repositorio el playbook está en `src/playbook` y no contiene `Atlas-main`; se comprueba el contenido del `.apbx` al compilar |
| B5-5 | Los 18 patrones AppX sin coincidencia en 26H2 son inofensivos (no-op); las apps nuevas se decidieron en D4 |
| B5-6, F3-18 | Afectan a recetas de CAB ya compiladas (NoTelemetry); documentado en la auditoría |
| B1-6, B1-9 | Solo ARM64; fuera de alcance (PC x64) |
| F3-9 | Pendiente de la prueba T2 con usuario **estándar**: `newUsers.ps1` pide elevación. Rehacerlo sin elevación es un cambio de diseño y no se hace sin probarlo |
| F3-22 | Solo afecta a `defender-disable`. Ampliar la receta del CAB o desactivar `MsSecCore`/`MsSecFlt`/`MsSecWfp` (drivers de arranque) sin probarlo en la VM podría impedir el arranque; queda pendiente con una prueba específica |
| F5-2 (nuevo) | Fallos de Atlas Toolbox 0.1.13 (aplicación externa), ver la sección 7 |

## 10. Correcciones tras intentar la prueba 3
| ID | Archivo | Cambio |
|---|---|---|
| F5-4 (nuevo) | `playbook.conf` | AME Beta no cargaba el `.apbx`: «Error en el documento XML (129, 18): CheckboxPage with a TopLine and BottomLine must not have more than 2 options». La línea 129 del `playbook.conf` compilado (`local-build` quita 6 líneas) es el cierre de la página de Edge. El `TopLine` de D6 se sumó al `BottomLine` que ya tenía esa página de 3 opciones. Se quita el `BottomLine` «Learn more» de esa página; su enlace es el mismo que el de la página anterior. El aviso de Edge se mantiene arriba. AME admite hasta 3 opciones con solo `TopLine` o solo `BottomLine`, y hasta 4 sin ninguno |

Reglas de validación de AME sacadas de los textos UTF-16 de `AME Beta.exe`:
- `CheckboxPage` y `RadioPage`: hasta 2 opciones con `TopLine` y `BottomLine`, hasta 3 con uno de los dos y hasta 4 sin ninguno. No se pueden repetir opciones.
- `RadioPage` y `RadioImagePage`: `DefaultOption` debe existir.
- `RadioImagePage`: hasta 4 opciones; los colores van en formato `#RRGGBB`, distintos entre sí y ni negros ni blancos.
- `Name` no admite `\ / : * ? < > |`.
- `Version` y `UpgradableFrom` tienen formato fijo.
- Con `SupportsISO`, hacen falta exactamente 3 `BulletPoint` con iconos distintos.

Ahora se comprueban antes de compilar con `tools/ame_conf_check.py` (también en GitHub Actions).

## 11. Correcciones tras la prueba 3
| ID | Archivo | Cambio |
|---|---|---|
| F5-5 (nuevo) | `AtlasModules/Scripts/ScriptWrappers/RemoveCopilotApp.ps1` (nuevo), `atlas/appx.yml` | Desde octubre de 2026, el AppX `Microsoft.Copilot` (154.x) es un anfitrión de una app Chromium que Edge Update instala en `Program Files (x86)\Microsoft\Copilot` (~1,1 GB). Al quitar el AppX quedaban esa carpeta, el servicio `MicrosoftCopilotElevationService`, la entrada «Copilot» en Aplicaciones, el registro en Edge Update (`{C50565E9-CCCF-44B4-BA15-5AC5C6569197}`), `HKLM\SOFTWARE\Microsoft\Copilot` y un acceso directo. El script nuevo ejecuta el desinstalador oficial (`UninstallString` + `--force-uninstall`) y borra lo que quede. No toca Edge Update ni WebView2. *Pendiente de validar en la VM con `prueba-copilot.ps1`* |
| F5-6 (nuevo) | `AtlasDesktop/6. Advanced Configuration/Services/Printing/Enable Printing (default).cmd` | Ya no activa `Printing-XPSServices-Features`. Desde que `DEFAULT.ps1` corre en instalación limpia (D1), añadía «Microsoft XPS Document Writer», que 26H2 trae desactivada. Las otras tres características ya venían activadas | Ese script reproduce el error con el `.apbx` anterior y pasa con el 0.5.0 oficial y con el nuevo.

## 12. Publicación como Meridian 26H2 v1.0.0
| ID | Archivo | Cambio |
|---|---|---|
| F5-7, D10 | `playbook.conf` | AME Wizard etiquetaba el paquete como «Malicious» porque usaba el `Name` (AtlasOS), el `Username` (Atlas), el `UniqueId` y el `ProductCode` del Atlas oficial sin coincidir con ninguna versión publicada. Ahora: `Name` «Meridian 26H2», `Username` zykmm, `UniqueId` propio (`4afcc1f3-2e52-40b9-998f-6556a2ce47a4`), sin `ProductCode` ni `DonateLink`, y `Git`, `Website` e `InstallGuide` apuntan a este repositorio. La descripción dice que es un fork no oficial |
| Requisito | `playbook.conf` | `SupportedBuilds` solo `26300` (Windows 11 26H2). Quitados 26100 y 25H2: para esas versiones está el Atlas oficial. Se quita `UpgradableFrom` (no hay versiones anteriores de Meridian). `Version` 1.0.0 |
| Identidad | `tweaks/misc/config-oem-information.yml` | Entrada de arranque «Meridian 26H2 - Windows 11 v1.0.0»; `Model`, `RegisteredOrganization` y `Manufacturer` dicen «Meridian 26H2 … (unofficial AtlasOS fork)»; `SupportURL` y `SupportPhone`, los issues y el repositorio de Meridian |
| Soporte | `AtlasModules/Scripts/packageInstall.ps1`, `ScriptWrappers/TelemetryComponents.ps1` | Los mensajes de error piden reportar en los issues de Meridian, no al equipo de Atlas |
| — | Interno | Se mantienen los nombres internos (`AtlasModules`, carpeta «Atlas» del escritorio, `HKLM\SOFTWARE\AtlasOS`) porque Atlas Toolbox y los scripts dependen de ellos |
| — | `tools/` | `ame_conf_check.py`, `validate_yaml.py` (190 YAML, 179 `!task`) y `verificar-26h2.ps1` (solo lectura; ya no escribe el nombre del equipo ni del usuario). Los ejecuta GitHub Actions (`.github/workflows/build.yml`), que además compila el `.apbx` y lo publica con su SHA256 |
