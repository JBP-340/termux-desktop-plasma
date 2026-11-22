# Termux Distro Desktop — Instalador universal v11

[![Licencia: MIT](https://img.shields.io/badge/Licencia-MIT-yellow.svg)](LICENSE)
[![Plataforma: Termux](https://img.shields.io/badge/Plataforma-Termux-00C853)](https://termux.dev/)
[![Motor: proot-distro](https://img.shields.io/badge/Motor-proot--distro-blue)](https://github.com/termux/proot-distro)
[![Escritorio: KDE Plasma](https://img.shields.io/badge/Escritorio-KDE%20Plasma-3DAEE9)](https://kde.org/)
[![Versión](https://img.shields.io/badge/version-v11-brightgreen)](CHANGELOG.md)

> **Escritorio KDE Plasma completo, aislado y reproducible dentro de cualquier distro de proot-distro en Termux.**
> Termux es solamente el **motor** (`proot-distro` + `termux-x11` + `PulseAudio` + `termux-api`). El sistema real, las apps, la tienda, el audio y D-Bus/polkit viven **dentro del rootfs** de la distro elegida.

> Novedades de v11: **progreso real del gestor de paquetes en pantalla**, **cero archivos de log en `/tmp`**, **selección explícita de distro y modo** y tres flujos limpios y diferenciados: **instalar / reinstalar / actualizar**.

---

## Tabla de contenidos

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación rápida](#instalación-rápida)
- [Modos de operación](#modos-de-operación)
- [Distribuciones soportadas](#distribuciones-soportadas)
- [Lanzador `startdesktop`](#lanzador-startdesktop)
- [Qué se instala dentro del contenedor](#qué-se-instala-dentro-del-contenedor)
- [Verificación real de paquetes](#verificación-real-de-paquetes)
- [Audio, D-Bus y renderizado](#audio-d-bus-y-renderizado)
- [Estructura de archivos](#estructura-de-archivos)
- [Solución de problemas](#solución-de-problemas)
- [Seguridad](#seguridad)
- [Limitaciones conocidas](#limitaciones-conocidas)
- [Contribuir](#contribuir)
- [Licencia](#licencia)

---

## Características

- **Aislamiento total:** cada distro tiene su propio rootfs, su propio usuario `user` (UID `1000`), su propio bus del sistema y su propia configuración KDE. Varios contenedores pueden coexistir sin interferirse.
- **Sin dependencias externas:** no usa `bash <(curl ...)` de ningún repo de terceros. El instalador es autocontenido.
- **Progreso visible:** barras con hora, elapsed time y **la salida real de `apt`/`pacman`/`dnf`/`apk`/`zypper`/`xbps` en pantalla** (descarga, descompresión y despliegue). El gestor se invoca con `Dpkg::Progress=1` y `Dpkg::Progress-Fancy=1` en Debian/Ubuntu/Kali.
- **Cero logs en `/tmp`:** se eliminaron todas las redirecciones a `/tmp/*.log` que fallaban con `Permission denied` en Termux.
- **Tres modos explícitos:** `1 = INSTALAR`, `2 = REINSTALAR`, `3 = ACTUALIZAR`, con confirmaciones y destinos mostrados antes de cualquier borrado.
- **Selección segura:** la opción `0` (automática) del lanzador solo funciona si hay **una única distro**; si hay varias, exige elegir una.
- **Verificación honesta:** después de cada paquete se consulta la base de datos real del gestor (`dpkg -s`, `pacman -Qi`, `rpm -q`, `apk info -e`, `xbps-query`), con 2 reintentos. Al final: `Verificado: X instalados | Y ausentes de verdad`.
- **Escritorio completo:** Plasma + Window Manager + apps KDE (Dolphin, Konsole, Kate, Okular, Gwenview, Ark, KCalc, Kontact…), Firefox/Thunderbird, LibreOffice, VLC/mpv/ffmpeg, GIMP/Inkscape/Krita.
- **Tienda:** Flatpak + Flathub (sistema **y** usuario) + Discover + PackageKit. Incluye el atajo `flatpak-user install flathub <app>` para evitar el system-helper/fuse.
- **Audio:** PulseAudio en TCP `127.0.0.1` desde Termux + PipeWire con túnel `tcp:127.0.0.1` y `flags = [ ( ifexists ) ( nofail ) ]`.
- **D-Bus/polkit propios:** bus del sistema en `/run/dbus/system_bus_socket` + regla `49-proot-nopasswd.rules`; `user` con `sudo NOPASSWD` y root sin contraseña.
- **Renderizado por software:** `LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe`, `MESA_LOADER_DRIVER_OVERRIDE=llvmpipe` (funciona sin GPU).

---

## Requisitos

| Requisito | Detalle |
|---|---|
| Termux | Builds de F-Droid o GitHub (la versión de Play Store está abandonada) |
| Conexión a Internet | Para `pkg update` y las descargas de los rootfs/paquetes |
| Espacio | Varios GB libres (depende de la distro y del set de apps) |
| Paquetes base que instala el script | `proot-distro`, `pulseaudio`, `termux-x11`, `termux-api`, `curl` |
| Opcional | App **termux-x11** instalada para ver el escritorio |

---

## Instalación rápida

### Opción A — Descargar el script del repo (recomendado)

```bash
pkg update -y && pkg install -y curl
curl -Lf -o "$HOME/install-distro-desktop.sh" \
  https://raw.githubusercontent.com/JBP-340/termux-desktop-plasma/main/install-distro-desktop.sh
chmod +x "$HOME/install-distro-desktop.sh"
bash "$HOME/install-distro-desktop.sh"
```

### Opción B — Bloque único copiar/pegar (sin curl)

Pega todo el contenido de [`paste-block.sh`](paste-block.sh) en Termux. Ese bloque escribe el instalador completo en `$HOME/install-distro-desktop.sh`, le da permisos y lo ejecuta. Es totalmente autocontenido.

> Tras instalar,Arranca el escritorio con:
>
> ```bash
> startdesktop
> ```

---

## Modos de operación

El instalador pregunta por la distro y luego por el modo. **No hay modos ocultos ni efectos secundarios entre ellos.**

| Modo | Nombre | ¿Rootfs? | ¿Datos y config? | ¿Paquetes? | Cuándo usarlo |
|---|---|---|---|---|---|
| `1` | **INSTALAR** | Directo, desde cero. No purga, no resetea, no hace backup | No se tocan los existentes | Instala el perfil base verificado | Primera instalación o añadir una distro nueva |
| `2` | **REINSTALAR** | Se **borra y se reconstruye** con `proot-distro remove` | **NO se conservan**; la config vieja se mueve a `/home/user/.proot-reset-<timestamp>/` | Guarda `packages.txt` con **TODOS** los paquetes y los reinstala + Plasma nativo | Rootfs roto o quieres empezar limpio sin perder la lista de software |
| `3` | **ACTUALIZAR** | Se conserva | **Se conservan** datos y configuración | `dist-upgrade` / `pacman -Syu` / equivalentes, luego verificación | Mantenimiento periódico |

**Salvaguardas del modo 2:**

1. Muestra `>> Distro elegida: <distro>` y `>> Modo elegido: 2 = REINSTALAR`.
2. Pregunta `¿Reinstalar TODAS las distros instaladas? [s/N]:` — **el valor por defecto es `N`** (nunca borra todas por accidente).
3. Imprime `DESTINOS DE LA REINSTALACION (N): ...` y pide una confirmación explícita `[s/N]` antes de borrar nada.
4. Muestra y guarda la lista completa de paquetes en `$HOME/proot-backups/<distro>/packages.txt` y en `$HOME/installed-packages-<distro>.txt`.
5. Si la distro elegida no estaba instalada, hace una instalación limpia de **esa** distro (no de otra).

---

## Distribuciones soportadas

| Opción | Distro | Gestor | Notas |
|---|---|---|---|
| 1 | `archlinux` | pacman | Usa `menci/archlinuxarm --name archlinux`. **Nunca** el `archlinux` oficial amd64 ni `danhunsaker/archlinuxarm` |
| 2 | `debian` | apt | Perfiles corregidos para trixie (`plasma-workspace-data`, `polkitd`, `phonon4qt6`, `firefox-esr`, …) |
| 3 | `ubuntu` | apt | Perfil Debian/Ubuntu |
| 4 | `fedora` | dnf | Grupo `@kde-desktop` |
| 5 | `alpine` | apk | |
| 6 | `void` | xbps | |
| 7 | `opensuse` | zypper | |
| 8 | `kali` | apt | Perfil Debian |
| 9 | *otra* | autodetectado | Escribe el nombre exacto que usa `proot-distro` |

El gestor se detecta solo; la verificación se adapta a él.

---

## Lanzador `startdesktop`

El lanzador **primero configura y después ejecuta**. No usa archivos temporales de señal (todo por argumentos/stdin).

```bash
startdesktop                 # asistente interactivo
startdesktop debian          # elige distro, pregunta modo
startdesktop debian user     # distro + modo (user/root/custom)
startdesktop debian user user# sin preguntas: distro, modo y usuario
```

Flujo interactivo:

1. **1/3 DISTRO** — lista las rootfs instaladas. `0` = automático **solo si hay una**; con varias, te obliga a elegir.
2. **2/3 MODO** — `1` usuario detectado (por defecto), `2` root, `3` escribir usuario personalizado.
3. **3/3 RESUMEN** — muestra distro, modo y usuario y pide confirmación `[S/n]`.

Luego el lanzador:

-leva el wake lock, reinicia PulseAudio con TCP anónimo solo en `127.0.0.1`, arranca `termux-x11 :0`;
- regenera `/etc/resolv.conf`, configura el bus del sistema y la regla polkit;
- arranca `NetworkManager`, `kglobalacceld` y `pipewire` si están disponibles;
- ejecuta `startplasma-x11` (o el WM disponible) como `user` vía `su`/`dbus-run-session`.

> Para comprobar D-Bus, hazlo **mientras el escritorio está corriendo**:
>
> ```bash
> dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId
> pgrep -a polkitd
> ```
>
> Que el socket falte **después** de cerrar `startdesktop` es normal: `/run` se limpia al salir.

---

## Qué se instala dentro del contenedor

- **Base:** `sudo`, `dbus`, `dbus-x11`, `xdg-utils`, `xdg-user-dirs`, portales, `flatpak`, polkit, gestor de red.
- **KDE/Plasma:** `plasma-desktop`/`@kde-desktop`, `kwin`, `systemsettings`, `kglobalacceld`, `plasma-pa`, `plasma-nm`, `plasma-discover`, `breeze`, `kwin-addons`, `qqc2-desktop-style`.
- **Apps KDE:** Dolphin, Konsole, Ark, Gwenview, Okular, Kate, KCalc, Kontact, `kde-cli-tools`, `kio-extras`, thumbnails.
- **Multimedia:** phonon + Qt Multimedia + GStreamer (base/good/bad/libav) + PulseAudio, PipeWire, pavucontrol.
- **Productividad:** Firefox (o `firefox-esr`), Thunderbird, LibreOffice, VLC, mpv, ffmpeg, GIMP, Inkscape, Krita.
- **Tienda:** Discover + PackageKit + Flathub (sistema y usuario) + `flatpak-user`.

El usuario `user` se crea con **UID 1000**, sin contraseña y con `sudo NOPASSWD: ALL` en `/etc/sudoers.d/user`. Root también queda sin contraseña.

---

## Verificación real de paquetes

En proot, `apt`/`dnf` pueden devolver error por scripts de `systemd`/`postinst` **incluso cuando el paquete sí se instaló**. Por eso el instalador no se fía del código de salida:

```text
dpkg -s <pkg> | grep -q '^Status: install ok installed'   # Debian/Ubuntu/Kali
pacman -Qi <pkg>                                          # Arch
rpm -q <pkg>                                              # Fedora/openSUSE
apk info -e <pkg>                                         # Alpine
xbps-query -S <pkg>                                       # Void
```

Cada paquete se reintenta hasta 2 veces. La barra por paquete muestra `[HH:MM:SS] NN% [###...] 012/150 nombre` y termina en `OK` o `FALLO`. Al final se imprime:

```text
Verificado: 148 instalados | 2 ausentes de verdad
   (!) Realmente ausente: <paquete>  (revisa la salida del gestor justo arriba)
```

---

## Audio, D-Bus y renderizado

| Subsistema | Configuración |
|---|---|
| PulseAudio (Termux) | `pulseaudio --start --exit-idle-time=-1 --load="module-native-protocol-tcp auth-anonymous=1 auth-ip-acl=127.0.0.1"` |
| PipeWire (contenedor) | `~/.config/pipewire/pipewire.conf` con módulo `libpipewire-module-pulse-tunnel` hacia `tcp:127.0.0.1`, `flags = [ ( ifexists ) ( nofail ) ]` |
| D-Bus sistema | `/etc/dbus-1/proot-system.conf` escuchando en `/run/dbus/system_bus_socket`; se borra el socket huérfano antes de arrancar |
| polkit | `/etc/polkit-1/rules.d/49-proot-nopasswd.rules` → `polkit.Result.YES` para todo (ámbito local del proot) |
| Software GL | `LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe`, `MESA_LOADER_DRIVER_OVERRIDE=llvmpipe` |
| Plasma | `kwinrc` con `Compositing/Enabled=false` y `kdeglobals` con `GraphicEffectsLevel=0`; Baloo desactivado |

---

## Estructura de archivos

```text
termux-desktop-plasma/
├── README.md                       # esta documentación
├── install-distro-desktop.sh       # instalador v11 (ejecutable)
├── paste-block.sh                  # bloque único para copiar/pegar en Termux
├── CHANGELOG.md                    # historial de versiones
├── CONTRIBUTING.md                 # cómo contribuir
├── LICENSE                         # MIT
└── .gitignore

# En el dispositivo, después de ejecutarlo:
~/install-distro-desktop.sh
$PREFIX/bin/startdesktop
$PREFIX/var/lib/proot-distro/containers/<distro>/rootfs/
~/proot-backups/<distro>/packages.txt
~/installed-packages-<distro>.txt               # solo modo 2
/root/installed-packages.txt                    # dentro de cada contenedor
/home/user/.proot-reset-<timestamp>/            # config anterior (modo 2)
/etc/dbus-1/proot-system.conf                   # dentro de cada contenedor
/etc/polkit-1/rules.d/49-proot-nopasswd.rules   # dentro de cada contenedor
/etc/pipewire/client.conf                       # dentro de cada contenedor
/home/user/.config/pipewire/pipewire.conf       # dentro de cada contenedor
```

---

## Solución de problemas

| Síntoma | Explicación / acción |
|---|---|
| `/tmp/instalar-desktop.log: Permission denied` | Versión antigua (≤ v10). v11 **no escribe logs en `/tmp`**. Actualiza el script. |
| `Failed to connect to PipeWire` | v11 crea `/etc/pipewire/client.conf` y el túnel al PulseAudio de Termux. Asegúrate de que `startdesktop` haya arrancado PulseAudio TCP y deja pasar unos segundos. |
| `module "org.kde.plasma.private.volume" is not installed` | Falta `plasma-pa`; está en el perfil. Verifica con `Verificado: ... ausentes de verdad` y reinstala ese paquete. |
| `Couldn't start kglobalaccel from org.kde.kglobalaccel.service` | El lanzador arranca `kglobalacceld` si existe. Si el paquete falta, aparecerá en `Realmente ausente:`. |
| `polkit_agent_listener_register_with_options: assertion 'POLKIT_IS_SUBJECT (subject)' failed` | Con la regla 49 no hace falta agente en proot; es un aviso inofensivo. |
| `QNetworkInformation has no backend. Is NetworkManager.service running?` | `startdesktop` arranca NetworkManager; en proot no hay systemd real, así que el aviso puede aparecer igual. No afecta a la red. |
| Se reinstaló la distro equivocada | v11 muestra distro + modo, elige `N` por defecto para "todas" y muestra `DESTINOS DE LA REINSTALACION` antes de borrar. Confirma esas líneas. |
| `Bus caido` | Se regenera el bus en cada arranque. Comprueba con `dbus-send ... GetId` **con el escritorio abierto**. |
| Paquete marcado `FALLO` | Mira la salida del gestor justo encima; suele ser un nombre inexistente en esa distro. El resto continúa igual. |

---

## Seguridad

- `sudo NOPASSWD`, `passwd -d` y la regla de polkit **allow-all** están pensados **exclusivamente para el entorno aislado del proot** (no exponen servicios a la red; PulseAudio solo escucha en `127.0.0.1`).
- No reutilices esta configuración en una máquina real o en un contenedor con red expuesta.
- La contraseña de usuario no existe por diseño: es un escritorio local de Termux, no un sistema multiusuario.

---

## Limitaciones conocidas

- No hay `systemd` real dentro de proot: algunos servicios se arrancan manualmente desde `startdesktop`.
- El renderizado es por software (`llvmpipe`): consumos altos de CPU en efectos/3D.
- El túnel de audio usa TCP loopback; no está pensado para audio de baja latencia.
- En `apt` pueden aparecer errores de `postinst` por systemd; el instalador lo compensa verificando la DB y reintentando.
- Según la versión de la distro, algún paquete del perfil puede no existir; se omite y se reporta en `Realmente ausente:`.

---

# Contribuir

Repositorio: https://github.com/JBP-340/termux-desktop-plasma

Para subir un cambio desde Termux:

```bash
git clone https://github.com/JBP-340/termux-desktop-plasma.git
cd termux-desktop-plasma
bash -n install-distro-desktop.sh
git add .
git commit -m "Describe aquí lo que cambiaste"
git push
```

Si ya tienes el repo descargado:

```bash
cd ~/termux-desktop-plasma
git pull
# edita el archivo...
bash -n install-distro-desktop.sh
git add .
git commit -m "Describe aquí lo que cambiaste"
git push
```

alternativa a la instalaciones quizás automáticamente esto utiliza una distribución externa para poder terminar de instalar lo que es Arch linux pero tampoco se sabe de tantos errores debido a que tiene poco archivo o poca información sobre las instalaciones de su correspondencia de kde plasma todo eso quedaría en manos manuales el que el instalador que yo hice es que está arriba utiliza una base predefinida para instalarlo pero no posee todos los las aplicaciones correspondientes a kde plasma aquí le pasó el pequeño código que quiere que utiliza repositorio externo de `termux-desktop`

```bash
mkdir -p "$HOME/.termux-desktop-patch"
curl -sLf https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/distro-container-setup \
  -o "$HOME/.termux-desktop-patch/distro-container-setup.upstream"

cat > "$HOME/distro-container-setup" <<'PATCH'
#!/data/data/com.termux/files/usr/bin/bash
_UP="$HOME/.termux-desktop-patch/distro-container-setup.upstream"
[[ -f "$_UP" ]] && source "$_UP" || source <(curl -sLf https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/distro-container-setup)

# 1) Arch SIEMPRE con menci/archlinuxarm, reutilizando el contenedor ya creado
function setup_proot_distro() {
	print_msg "${BOLD}Setting up ${C}proot-distro"
	package_install_and_check "proot-distro"
	banner
	print_msg "${BOLD}Setting up Selected Linux Distro: ${C}${selected_distro}"
	echo
	print_to_config "selected_distro"
	if [[ "$selected_distro" == "archlinux" ]]; then
		local C="$TERMUX_PREFIX/var/lib/proot-distro/containers"
		if [[ -e "$C/archlinux/rootfs/bin/sh" ]]; then
			print_success "Reusing existing archlinux container (menci/archlinuxarm)"
		elif proot-distro list -q 2>/dev/null | grep -qx archlinux; then
			proot-distro remove archlinux
			proot-distro install menci/archlinuxarm --name archlinux
		elif proot-distro list -q 2>/dev/null | grep -qx archlinuxarm; then
			proot-distro rename archlinuxarm archlinux
		else
			proot-distro install menci/archlinuxarm --name archlinux
		fi
	else
		pd install "$selected_distro"
	fi
}

# 2) Arreglar pacman ANTES de que el repo corra 'pacman -Syu'
function pd_arch_pacman_fix() {
	[[ "$selected_distro" == "archlinux" && "$selected_distro_type" == "proot" ]] || return 0
	print_msg "${BOLD}Parchando pacman para proot (menci/archlinuxarm)..."
	proot-distro login "$selected_distro" -- /bin/bash -c '
		sed -i "s/^DownloadUser[[:space:]]*=.*/#DownloadUser disabled/" /etc/pacman.conf
		grep -q "^DisableSandbox" /etc/pacman.conf || sed -i "/^\[options\]/a DisableSandbox" /etc/pacman.conf
		sed -i "s/^ParallelDownloads[[:space:]]*=.*/ParallelDownloads = 2/" /etc/pacman.conf
		grep -q "^DisableDownloadTimeout" /etc/pacman.conf || sed -i "/^\[options\]/a DisableDownloadTimeout" /etc/pacman.conf
		pacman-key --init >/dev/null 2>&1
		pacman-key --populate archlinuxarm >/dev/null 2>&1
		pacman -Syyu --noconfirm
	'
}

# 3) Lo nuestro DESPUÉS del bloque del repo (así no se pierde nada de lo que él instala)
function pd_arch_final_patch() {
	[[ "$selected_distro" == "archlinux" && "$selected_distro_type" == "proot" ]] || return 0
	print_msg "${BOLD}Instalando Plasma + tienda + audio en archlinux..."
	proot-distro login "$selected_distro" -- /bin/bash -c '
		id user >/dev/null 2>&1 || useradd -m -s /bin/bash user
		usermod -aG wheel,audio,video,storage user
		passwd -d user
		passwd -d root
		mkdir -p /etc/sudoers.d
		echo "user ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/user
		chmod 440 /etc/sudoers.d/user
		pacman -S --noconfirm plasma-desktop plasma-workspace kwin discover flatpak pulseaudio pulseaudio-alsa xdg-user-dirs
		flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
	'
}

# 4) Secuencia original del repo + nuestros 2 puntos de inserción
function install_distro_container() {
	set_distro_paths
	setup_distro
	pd_arch_pacman_fix
	termux_home_link="--shared-home"
	distro_basic_task
	pd_arch_final_patch
	if [[ "$CALL_FROM_CHANGE_DISTRO" == false ]]; then
		if [[ "$enable_hw_acc" == "y" ]]; then hw_config; fi
	fi
	distro_zsh_setup
	distro_terminal_utility_setup
	distro_create_app_installer
	add_add_to_menu
	add_useful_repos
	if [[ "$LITE_MODE" != "1" && "$LITE_MODE" != "true" ]]; then
		install_some_required_pack
	fi
	distro_app_launch_setup
}
PATCH

cd "$HOME"
bash <(curl -Lf https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/setup-termux-desktop)
```

## Reglas

- Nunca reintroducir logs en `/tmp`.
- Nunca depender de repos de terceros.
- No cambiar el valor por defecto de «¿Reinstalar TODAS...?» a `S`.
- Mantener la verificación real de paquetes y el progreso visible.
- Actualizar `CHANGELOG.md` si cambia el comportamiento.

---

## Licencia

Distribuido bajo licencia [MIT](LICENSE). El código es libre para usar, modificar y redistribuir, manteniendo el aviso de copyright.
