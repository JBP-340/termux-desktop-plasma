# Prompt profesional — Editor final del README (Termux Distro Desktop v11)

> Este archivo es el **prompt/conversación listo para pegar** en tu IA (OpenCode, Claude, Codex, Gemini, ChatGPT...). Ya está todo escrito: tú solo respondes con tu usuario y nombre de repo cuando te lo pida.

---

## Cómo usarlo

1. Abre la IA **dentro de la carpeta del repo** (`termux-distro-desktop/`).
2. Pega el **MENSAJE 1** tal cual.
3. Si te pregunta por los datos, pega el **MENSAJE 2** con tus valores reales (o rellénalos antes en el MENSAJE 1).
4. Recibirás el `README.md` completo en un solo bloque + resumen de cambios + estado final.
5. Copia ese bloque sobre tu `README.md` y haz commit.

---

## MENSAJE 1 — Pegar como primer mensaje

````text
ROL
Eres un ingeniero de documentación técnica y mantenedor senior de proyectos Termux / proot-distro. Tu especialidad es dejar repositorios listos para publicar con documentación exacta, verificable y sin promesas inventadas. Trabajas en el repositorio LOCAL `termux-distro-desktop/`.

ARCHIVOS DEL REPO (respeta esta responsabilidad)
- `README.md`  -> ES EL ÚNICO ARCHIVO QUE VAS A EDITAR.
- `install-distro-desktop.sh` -> instalador v11 (828 líneas). SOLO LECTURA. No lo modifiques.
- `paste-block.sh` -> bloque autocontenido para pegar en Termux. SOLO LECTURA.
- `CHANGELOG.md`, `CONTRIBUTING.md`, `LICENSE`, `.gitignore` -> SOLO LECTURA.

DATOS (rellena tú estos dos valores antes de pegar, si no quieres responder después)
USUARIO_GITHUB = TU_USUARIO
REPO_GITHUB = TU_REPO
Si alguno sigue valiendo "TU_USUARIO" o "TU_REPO", haz UNA sola pregunta al inicio pidiéndomelos y espera mi respuesta antes de tocar nada. No adivines, no inventes URLs.

OBJETIVO
Dejar `README.md` 100 % final para GitHub: sin placeholders, sin errores tipográficos, sin descripciones que no coincidan con el script y con comandos copiables. No queremos una reescritura creativa: queremos precisión.

CONTEXTO TÉCNICO QUE DEBE REFLEJARSE (y nada más)
- v11: progreso real del gestor de paquetes en pantalla (`Dpkg::Progress=1`, `Dpkg::Progress-Fancy=1` en apt), salida en vivo de descarga/descompresión, barras con hora `[HH:MM:SS]` y elapsed `(+HH:MM:SS)`.
- CERO logs en `/tmp` (el error antiguo era `/tmp/instalar-desktop.log: Permission denied`). Los demonios van a `/dev/null`.
- Termux es solo motor: `proot-distro`, `termux-x11`, `pulseaudio`, `termux-api`, `curl`. El sistema vive en cada rootfs.
- Modos: `1 = INSTALAR` (directo, sin purga/reset/backup), `2 = REINSTALAR` (guarda TODOS los paquetes en `$HOME/proot-backups/<distro>/packages.txt`, borra y reconstruye rootfs, mueve config vieja a `/home/user/.proot-reset-<timestamp>/`, NO conserva datos), `3 = ACTUALIZAR` (dist-upgrade/Syu, conserva datos y config).
- Salvaguardas modo 2: «¿Reinstalar TODAS...?» por defecto **N**, se imprimen `DESTINOS DE LA REINSTALACION (N): ...` y se pide confirmación `[s/N]` antes de borrar.
- Lanzador `$PREFIX/bin/startdesktop`: opción `0` automática SOLO si hay una distro; con varias exige elegir. Argumentos: `startdesktop <distro> [user|root|custom] [usuario]`. Sin archivos temporales de señal.
- Usuario `user` UID 1000, sin password, `sudo NOPASSWD: ALL` en `/etc/sudoers.d/user`; root sin password.
- Verificación real: `dpkg -s`, `pacman -Qi`, `rpm -q`, `apk info -e`, `xbps-query`; 2 reintentos; línea final `Verificado: X instalados | Y ausentes de verdad` y avisos `Realmente ausente: <pkg>`.
- D-Bus: `/etc/dbus-1/proot-system.conf` + `/etc/polkit-1/rules.d/49-proot-nopasswd.rules`; comprobar con `dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId` CON el escritorio abierto.
- Audio: PulseAudio TCP `127.0.0.1` (auth-anonymous, acl loopback) + PipeWire con `libpipewire-module-pulse-tunnel` y `flags = [ ( ifexists ) ( nofail ) ]`.
- Renderizado software: `LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe`, `MESA_LOADER_DRIVER_OVERRIDE=llvmpipe`.
- Tienda: Flatpak + Flathub sistema y usuario, Discover/PackageKit y el atajo `flatpak-user install flathub <app>`.
- Arch: `menci/archlinuxarm --name archlinux` (nunca el oficial amd64 ni `danhunsaker/archlinuxarm`).
- Salida final del instalador: `Arranca con: startdesktop` y `Tienda sin bus del sistema: flatpak-user install flathub <app>`.

CHECKLIST DE EDICIÓN (en orden, sin saltarte ninguno)
1. Sustituye TODAS las apariciones de `TU_USUARIO` y `TU_REPO` por los valores reales (URL de `raw.githubusercontent.com` y comando `git clone`). Deben quedar CERO apariciones.
2. Corrige el typo exacto `Tras instalar,Arranca` -> `Tras instalar, arranca`.
3. Contrasta CADA afirmación del README con `install-distro-desktop.sh` (léelo con grep si hace falta). Si el README dice algo que el script no hace, CORRIGE EL README. Nunca alteres el script para que coincida con el README.
4. Verifica que el índice (TOC) coincida exactamente con los encabezados `##` presentes, y que las anclas sean válidas (tildes y ñ incluidas). Añade/quita entradas si hace falta.
5. Mantén la estructura actual: badges, tabla de modos, tabla de distros, uso del lanzador, verificación, audio/D-Bus, árbol de archivos, troubleshooting, seguridad, limitaciones, contribuir, licencia. No eliminues secciones salvo que sean falsas.
6. No añadas comandos, flags, paquetes ni funcionalidades que no estén en el script. No cambies el significado de los modos ni el valor por defecto de ningún prompt.
7. Añade (o afina) una sección corta «Comprobación antes de publicar» con este bloque exacto:

   ```bash
   bash -n install-distro-desktop.sh
   grep -n '/tmp/.*\.log' install-distro-desktop.sh || echo "OK: sin logs en /tmp"
   grep -n 'TU_USUARIO\|TU_REPO' README.md || echo "OK: sin placeholders"
   ```

8. Comprueba que la Opción A (curl desde tu repo) y la Opción B (`paste-block.sh`, sin curl) siguen siendo claras y distintas.
9. Deja el texto en español técnico, directo, sin marketing vacío, sin emojis, con tablas y bloques `bash` bien cerrados.
10. No modifiques ningún otro archivo. Si encuentras un fallo REAL en el script, repórtalo en el resumen como «HALLAZGO (no corregido)» y sigue adelante.

RESTRICCIONES
- No ejecutes el instalador, ni `pkg`, ni `proot-distro`, ni nada que modifique el dispositivo.
- No escribas archivos en `/tmp`.
- No hagas `git commit`, `git push` ni cambios de permisos.
- No resumas con «...» ni digas «el resto igual»: el README debe salir COMPLETO.

CRITERIOS DE ACEPTACIÓN
- 0 apariciones de `TU_USUARIO` / `TU_REPO`.
- 0 apariciones de `Tras instalar,Arranca`.
- TOC ↔ encabezados `##` perfectamente alineados.
- Todos los comandos se pueden copiar y pegar tal cual.
- `bash -n install-distro-desktop.sh` sigue pasando (no lo tocaste).
- El `diff` afecta EXCLUSIVAMENTE a `README.md`.

FORMATO DE SALIDA (respeta el orden)
1. Un único bloque cercado con ```markdown que contenga el `README.md` COMPLETO, desde `# Termux Distro Desktop — Instalador universal v11` hasta la última línea de la licencia. Sin comentarios dentro del bloque.
2. Debajo, una lista numerada (máximo 8 ítems) con los cambios exactos que hiciste.
3. Debajo, una línea final: `Estado: LISTO PARA COMMIT` o, si falta algo, `Estado: BLOQUEADO — <motivo concreto>`.
````

---

## MENSAJE 2 — Solo si la IA te pide los datos

````text
USUARIO_GITHUB = tu-usuario-real
REPO_GITHUB = termux-distro-desktop
````

*(Sustituye `tu-usuario-real` por tu usuario de GitHub. Si tu repo se llama de otra forma, cambia también la segunda línea.)*

---

## MENSAJE 3 — Opcional, cuando quieras una segunda pasada de revisión

````text
Haz una segunda pasada de auditoría sobre el README que acabas de entregar. Busca específicamente:
1) afirmaciones que el script no implemente;
2) anclas del TOC rotas;
3) comandos con rutas o nombres de archivo equivocados;
4) contradicciones entre la tabla de modos y el cuerpo;
5) cualquier aparición de "TU_USUARIO", "TU_REPO" o logs en /tmp.
Corrige lo que encuentres y vuelve a entregar el README completo con el mismo formato de salida que usé en la primera instrucción.
````

---

## Guion de conversación esperado

| Turno | Quién | Texto |
|---|---|---|
| 1 | **Tú** | MENSAJE 1 (pegado tal cual) |
| 2 | IA | «Necesito tu usuario de GitHub y el nombre del repo antes de editar» *(solo si dejaste los placeholders)* |
| 3 | **Tú** | MENSAJE 2 |
| 4 | IA | README.md completo + resumen de cambios + `Estado: LISTO PARA COMMIT` |
| 5 | **Tú** *(opcional)* | MENSAJE 3 |
| 6 | IA | README.md auditado y corregido |

Si la IA salta el turno 2 es porque rellenaste los datos en el MENSAJE 1: es normal, sigue directo al turno 4.
