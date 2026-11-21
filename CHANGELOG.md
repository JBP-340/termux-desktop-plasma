# Changelog

Todos los cambios relevantes de este proyecto se documentan aquí. El formato sigue loosely [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## [v11] — 2026-11-21

### Añadido
- Barra de progreso real del gestor de paquetes en pantalla (`Dpkg::Progress=1`, `Dpkg::Progress-Fancy=1` para apt).
- Salida en vivo de descarga/descompresión de `apt`, `pacman`, `dnf`, `apk`, `zypper` y `xbps`.
- Monitor con hora `[HH:MM:%S]` y tiempo transcurrido `(+HH:MM:SS)` en cada fase.

### Cambiado
- **Eliminados todos los archivos de log en `/tmp`** (causaban `Permission denied` en Termux). Los demonios redirigen a `/dev/null`.
- Selección explícita de distro y modo antes de cualquier acción.

### Corregido
- Reininstalación de la distro equivocada: el prompt «¿Reinstalar TODAS...?» ahora por defecto es `N`, se muestran los `DESTINOS DE LA REINSTALACION` y se pide confirmación antes de borrar.

## [v10] — 2026-11-20

### Corregido
- Protecciones para no operar sobre la distro equivocada al reinstalar.

## [v9] — 2026-11-20

### Cambiado
- Modos simplificados a `1 = INSTALAR`, `2 = REINSTALAR`, `3 = ACTUALIZAR`.

## [v8] — 2026-11-20

### Cambiado
- Modo `1` directo: sin purga, sin reset, sin backup, sin bucle de reinstalación.

## [v7] — 2026-11-20

### Añadido
- Contadores de pasos, barras por distro y fases `[fase 1/5]` / `[pkg i/N]`.

### Corregido
- Variable `$RST` → `$RESET`.

## [v6] — 2026-11-19

### Cambiado
- Modo `3`: reconstrucción completa del rootfs para una o todas las distros instaladas.

## [v5] — 2026-11-19

### Añadido
- Modo `2`: reinstalación desde la lista guardada de paquetes.

## [v4] — 2026-11-18

### Añadido
- Reset/backup de configuración KDE y correcciones de D-Bus, paquetes, PipeWire y lanzador.

## [v1–v3] — 2026-11-17

### Añadido
- Prototipo inicial del instalador universal para proot-distro en Termux.
