# termux-desktop-arch-plasma
Instala Arch Linux ARM con Plasma en Termux usando proot-distro y proporciona el lanzador startdesktop.

Listo. El repositorio trae esto en su módulo de distro (línea 58):

### Bloque único (prepara el parche y llama a tu comando)

```sh
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

### Un único detalle durante el asistente

Cuando llegues a la parte de distro y te pregunte:

> *"It looks like you already have a different distro-container setup script in your current directory. Do you want to change it with the latest installer (y/n)"*

Responde **`n`** → "mantener el archivo local". Ahí es donde entra el parche. Luego seleccionas **3. Arch** y sigues normal.

### Qué queda al final

- Contenedor **`archlinux`** instalado desde **`menci/archlinuxarm`** (nunca `danhunsaker`), reutilizando el que ya tienes.
- Todo lo del repo en ese apartado se mantiene: audio (`pulseaudio`), usuario, paquetes requeridos, repos, menú, instalador de apps, zsh, hw accel.
- Encima: pacman sin Landlock/`alpm`, `user` y `root` sin contraseña, `sudo NOPASSWD`, **Plasma + Discover + Flatpak/Flathub + PulseAudio**.

Listo. Cambié el orden por completo: **primero configura, después ejecuta**. Probado con 3 contenedores, con 1 solo y con usuario escrito a mano.

**Qué sigentes ahora**

```sh
mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/startdesktop" <<'OUTER'
#!/data/data/com.termux/files/usr/bin/bash
# FASE 1: configurar (solo variables, sin lanzar nada)
# FASE 2: ejecutar (X11 + audio + sesion), señal por argumentos/stdin.
# Uso: startdesktop [distro] [user|root|custom] [usuario]
set -u

BASE="$PREFIX/var/lib/proot-distro/containers"
DISTROS=()
for d in "$BASE"/*/rootfs/bin/sh; do
  [[ -e "$d" ]] || continue
  n=${d#"$BASE"/}
  n=${n%%/*}
  DISTROS+=("$n")
done

if (( ${#DISTROS[@]} == 0 )); then
  echo "No hay distros instaladas. Primero: proot-distro install <nombre>"
  exit 1
fi

# ===== FASE 1 - CONFIGURACION =====

# --- 1/3 Distro: 0 = automatico solo si hay UNA -----------------------------
if [[ -n "${1:-}" ]]; then
  SEL="$1"
  if [[ ! -e "$BASE/$SEL/rootfs/bin/sh" ]]; then
    echo "La distro '$SEL' no está instalada."
    exit 1
  fi
else
  while true; do
    echo
    echo "===== CONFIGURACION 1/3: DISTRO ====="
    echo
    echo "  0) Automatico"
    i=1
    for n in "${DISTROS[@]}"; do
      printf '  %s) %s\n' "$i" "$n"
      ((i++))
    done
    echo
    read -rp "Elige distro [0]: " opt
    opt=${opt:-0}

    if ! [[ "$opt" =~ ^[0-9]+$ ]]; then
      echo ">> Solo numeros. Intenta de nuevo."
      continue
    fi

    if (( opt == 0 )); then
      if (( ${#DISTROS[@]} == 1 )); then
        SEL=${DISTROS[0]}
        echo ">> Unica distro instalada: $SEL"
        break
      fi
      echo ">> Hay ${#DISTROS[@]} distros instaladas. Elige una de la lista (1-${#DISTROS[@]})."
      continue
    fi

    if (( opt >= 1 && opt <= ${#DISTROS[@]} )); then
      SEL=${DISTROS[$((opt-1))]}
      break
    fi
    echo ">> Opcion invalida."
  done
fi

# --- Detectar usuario leyendo el rootfs (sin ejecutar nada) -----------------
AUTOUSER=""
if grep -q '^user:' "$BASE/$SEL/rootfs/etc/passwd" 2>/dev/null; then
  AUTOUSER=user
else
  AUTOUSER=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' "$BASE/$SEL/rootfs/etc/passwd" 2>/dev/null)
fi
[[ -z "$AUTOUSER" ]] && AUTOUSER=root

# --- 2/3 Modo ---------------------------------------------------------------
if [[ -n "${2:-}" ]]; then
  MODE="$2"
  RUNAS="${3:-$AUTOUSER}"
  [[ "$MODE" == "root" ]] && RUNAS=root
else
  while true; do
    echo
    echo "===== CONFIGURACION 2/3: MODO DE INICIO ====="
    echo
    echo "  1) user   -> $AUTOUSER (recomendado, predeterminado)"
    echo "  2) root   -> mismo entorno que Termux"
    echo "  3) escribir usuario"
    echo
    read -rp "Elige modo [1]: " m
    m=${m:-1}
    case "$m" in
      1) MODE=user;   RUNAS="$AUTOUSER"; break ;;
      2) MODE=root;   RUNAS=root;        break ;;
      3) read -rp "Usuario a ejecutar: " RUNAS
         if [[ -z "$RUNAS" ]]; then echo ">> Usuario vacio."; continue; fi
         MODE=custom; break ;;
      *) echo ">> Opcion invalida." ;;
    esac
  done
fi

case "$MODE" in
  1|user)   MODE=user ;;
  2|root)   MODE=root; RUNAS=root ;;
  3|custom) MODE=custom ;;
  *) echo ">> Modo desconocido: $MODE"; exit 1 ;;
esac

# Todo guardado en memoria: SEL / MODE / RUNAS

# --- 3/3 Resumen + señal ----------------------------------------------------
echo
echo "===== CONFIGURACION 3/3: RESUMEN ====="
echo
echo "  Distro : $SEL"
echo "  Modo   : $MODE"
echo "  Usuario: $RUNAS"
echo "  X11    : :0     Audio: TCP 127.0.0.1"
echo
read -rp "¿Iniciar con esta configuracion? [S/n]: " go
go=${go:-s}
case "${go,,}" in
  s|si|y|yes) ;;
  *) echo "Cancelado. No se ha iniciado nada."; exit 0 ;;
esac

# ===== FASE 2 - EJECUCION =====
termux-wake-lock 2>/dev/null

pkill -f 'termux.x11' 2>/dev/null
sleep 1
unset PULSE_SERVER
pulseaudio --kill 2>/dev/null
sleep 1
pulseaudio --start --exit-idle-time=-1 \
  --load="module-native-protocol-tcp auth-anonymous=1 auth-ip-acl=127.0.0.1"

export XDG_RUNTIME_DIR="$TMPDIR"
termux-x11 :0 >/dev/null 2>&1 &
sleep 3
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
sleep 1

echo
echo ">> Senal enviada: $SEL / $MODE / $RUNAS"

proot-distro login "$SEL" --shared-tmp -- /bin/bash -s "$MODE" "$RUNAS" "$SEL" <<'INNER_EOF'
MODE="$1"
RUNAS="$2"
SEL="$3"

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# DNS
rm -f /etc/resolv.conf
printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf

if [[ "$MODE" == "root" ]]; then
  U=root
elif id "$RUNAS" >/dev/null 2>&1; then
  U="$RUNAS"
else
  echo ">> El usuario '$RUNAS' no existe en $SEL. Se usa root."
  U=root
fi

mkdir -p "/tmp/runtime-$U"
chown "$U": "/tmp/runtime-$U" 2>/dev/null
chmod 700 "/tmp/runtime-$U"

mkdir -p /run/dbus
dbus-daemon --system --fork 2>/dev/null
[ -x /usr/lib/polkit-1/polkitd ] && \
  /usr/lib/polkit-1/polkitd --no-debug >/tmp/polkitd.log 2>&1 &
for p in /usr/libexec/packagekitd /usr/lib/packagekit/packagekitd; do
  [ -x "$p" ] && "$p" >/tmp/packagekitd.log 2>&1 &
done
sleep 2

DE=""
for c in startplasma-x11 startxfce4 startlxqt startlxde mate-session gnome-session lxsession i3; do
  if command -v "$c" >/dev/null 2>&1; then DE="$c"; break; fi
done
if [[ -z "$DE" ]]; then
  echo "No encontré ningún escritorio instalado dentro de '$SEL'."
  exit 1
fi

RUN=""
command -v dbus-run-session >/dev/null 2>&1 && RUN="dbus-run-session --"

if [[ "$U" != "root" ]]; then
  echo ">> Iniciando $DE como '$U' en '$SEL'..."
  exec su "$U" -c "env DISPLAY=:0 PULSE_SERVER=tcp:127.0.0.1 XDG_RUNTIME_DIR=/tmp/runtime-$U LANG=C.UTF-8 LC_ALL=C.UTF-8 $RUN $DE"
else
  echo ">> Iniciando $DE como root (modo Termux) en '$SEL'..."
  exec env DISPLAY=:0 PULSE_SERVER=tcp:127.0.0.1 XDG_RUNTIME_DIR=/tmp/runtime-$U LANG=C.UTF-8 LC_ALL=C.UTF-8 $RUN "$DE"
fi
INNER_EOF
RC=$?
exit $RC
OUTER
chmod +x "$PREFIX/bin/startdesktop"
echo "Listo. Ejecuta: startdesktop"
```

### Uso

```sh
startdesktop                      # menú completo + confirmación
startdesktop archlinux            # distro fija, pregunta modo y confirma
startdesktop archlinux user
startdesktop archlinux custom luna
```

Si Cancelas en el resumen, verás `No se ha iniciado nada` y **termux-x11 ni pulseaudio habrán sido tocados**. Eso era justo lo que faltaba: nada se ejecuta hasta que la configuración está cerrada.
