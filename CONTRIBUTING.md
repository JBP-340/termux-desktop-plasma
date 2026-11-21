# Contribuir

¡Gracias por ayudar a mejorar el instalador!

## Flujo

1. Haz fork del repo y crea una rama: `git checkout -b fix/mi-cambio`.
2. Haz el cambio mínimo posible y documenta el porqué.
3. Valida la sintaxis **antes** de abrir el PR:

   ```bash
   bash -n install-distro-desktop.sh
   grep -n '/tmp/.*\.log' install-distro-desktop.sh   # debe devolver nada
   ```

4. Si tocaste los heredoc (`MANIFEST`, `EOS`, `LAUNCHER`, `INNER_EOF`), comprueba que cada marcador de cierre siga existiendo y sin indentación.
5. Prueba en **Termux real**, no solo con `bash -n`.
6. Actualiza `CHANGELOG.md` y abre el PR describiendo distro, modo y salida observada.

## Reglas de oro

- **Nunca** reintroducir logs en `/tmp`: Termux devuelve `Permission denied`.
- **Nunca** depender de repositorios de terceros ni de `bash <(curl ...)`.
- **Nunca** cambiar el valor por defecto de «¿Reinstalar TODAS...?» a `S`.
- Mantener la verificación real de paquetes (DB del gestor + 2 reintentos).
- Mantener el progreso visible en pantalla.

## Reportar un bug

Incluye:

- Distro y modo elegidos.
- Salida completa de las barras y líneas `Verificado: ... ausentes de verdad`.
- Si aplica, líneas `Realmente ausente: ...`.
- Resultado de `dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId` con el escritorio corriendo.
