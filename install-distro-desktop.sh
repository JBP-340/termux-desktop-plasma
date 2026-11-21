#!/data/data/com.termux/files/usr/bin/bash
# Instalador universal v11 (sin logs en /tmp + progreso real del gestor en pantalla): cualquier distro + escritorio y apps completos dentro de proot-distro.
# Termux es solo el motor; el sistema real vive en el contenedor.
set -u

STEP=0; T0=$(date +%s)
now() { date '+%H:%M:%S'; }
age() { local s=$(( $(date +%s) - T0 )); printf '%02d:%02d:%02d' $((s/3600)) $((s%3600/60)) $((s%60)); }
say()  { STEP=$((STEP+1)); printf '\n\033[1;36m==> [%02d] [%s] (+%s) %s\033[0m\n' "$STEP" "$(now)" "$(age)" "$*"; }
note() { printf '    \033[0;36m[i] [%s] %s\033[0m\n' "$(now)" "$*"; }
ok()   { printf '    \033[0;32m[OK] [%s] %s\033[0m\n' "$(now)" "$*"; }
warn() { printf '    \033[0;33m[!] [%s] %s\033[0m\n' "$(now)" "$*"; }
fail() { printf '\n\033[1;31m[!] [%s] %s\033[0m\n' "$(now)" "$*"; exit 1; }
bar() { # actual total etiqueta [1=salto de linea]
  local cur="$1" tot="$2" label="${3:-}" w=24 p=0 f=0
  [ "${tot:-0}" -gt 0 ] 2>/dev/null && p=$(( cur * 100 / tot ))
  [ "$p" -gt 100 ] && p=100
  f=$(( p * w / 100 ))
  printf '\r[%s] %3d%% [' "$(now)" "$p"
  printf '%*s' "$f" '' | tr ' ' '#'
  printf '%*s' "$((w-f))" '' | tr ' ' '.'
  printf '] %-*.*s' "$w" "$w" "$label"
  [ "${4:-0}" = 1 ] && printf '\n' || true
}

C="$PREFIX/var/lib/proot-distro/containers"
echo ">> Monitor en pantalla: barras con hora + progreso real de descarga/instalacion del gestor (sin archivos de log)."

# ---------- 0) Base en Termux ----------
say "Base minima en Termux"
bar 1 2 "Actualizando indices de pkg" 1
pkg update -y || warn "pkg update con avisos"
bar 2 2 "Indices de pkg listos" 1
bar 1 2 "Instalando proot-distro, pulseaudio, termux-x11, termux-api, curl" 1
pkg install -y proot-distro pulseaudio termux-x11 termux-api curl || warn "pkg install con avisos"
bar 2 2 "Base Termux instalada" 1

# ---------- 1) Elegir distro ----------
say "Seleccion de distribucion"
echo
echo "  1) archlinux   (menci/archlinuxarm, recomendado en ARM)"
echo "  2) debian"
echo "  3) ubuntu"
echo "  4) fedora"
echo "  5) alpine"
echo "  6) void"
echo "  7) opensuse"
echo "  8) kali"
echo "  9) escribir otro nombre"
echo
read -rp "Elige distro [1]: " op
op=${op:-1}
case "$op" in
  1) NAME=archlinux ;;
  2) NAME=debian ;;
  3) NAME=ubuntu ;;
  4) NAME=fedora ;;
  5) NAME=alpine ;;
  6) NAME=void ;;
  7) NAME=opensuse ;;
  8) NAME=kali ;;
  9) read -rp "Nombre exacto para proot-distro: " NAME ;;
  *) NAME=archlinux ;;
esac
[[ -n "$NAME" ]] || fail "Nombre vacio."
echo ">> Distro elegida: $NAME"

echo
echo "Modo de operacion:"
echo "  1) INSTALAR desde cero (directo: sin purga, sin reset, sin backup)"
echo "  2) REINSTALAR guardando TODOS los paquetes (rootfs nuevo, Plasma nativo, SIN datos ni config)"
echo "  3) ACTUALIZAR paquetes y apps (sin purga, sin borrar, conserva datos y config)"
read -rp "Elige modo [1]: " mo
mo=${mo:-1}
case "$mo" in 2) FULL=2 ;; 3) FULL=3 ;; *) FULL=1 ;; esac
case "$FULL" in
  1) note ">> Modo elegido: 1 = INSTALAR" ;;
  2) note ">> Modo elegido: 2 = REINSTALAR" ;;
  3) note ">> Modo elegido: 3 = ACTUALIZAR" ;;
esac
ALL=0
if [ "$FULL" = 2 ]; then
  echo
  echo ">> Reinstalacion pedida para: $NAME"
  read -rp "¿Reinstalar TODAS las distros instaladas? [s/N]: " all
  all=${all:-n}
  case "${all,,}" in s|si|y|yes|t|todas|todo) ALL=1 ;; *) ALL=0 ;; esac
  note ">> Se reinstalara: $([ "$ALL" = 1 ] && echo "TODAS las distros instaladas" || echo "SOLO '$NAME'")"
fi

note "Plan: distro=$NAME | modo=$FULL | todas=${ALL:-0}"
BKBASE="$HOME/proot-backups"

# Guarda la lista COMPLETA de paquetes de una distro en Termux.
backup_manifest() {
  local n="$1"; mkdir -p "$BKBASE/$n"
  bar 1 2 "Leyendo TODOS los paquetes de '$n'" 1
  proot-distro login "$n" -- /bin/sh -s > "$BKBASE/$n/packages.txt" 2>/dev/null <<'MANIFEST'
PM=""
for c in pacman apt-get dnf apk zypper xbps-install; do
  command -v "$c" >/dev/null 2>&1 && { PM="$c"; break; }
done
case "$PM" in
  apt-get)      dpkg --get-selections 2>/dev/null | awk '$2=="install"{print $1}' ;;
  pacman)       pacman -Qqe 2>/dev/null ;;
  dnf|zypper)   rpm -qa --qf '%{NAME}\n' 2>/dev/null ;;
  apk)          apk info -q 2>/dev/null ;;
  xbps-install) xbps-query -m 2>/dev/null ;;
esac
MANIFEST
  bar 2 2 "packages.txt: $(wc -l < "$BKBASE/$n/packages.txt" 2>/dev/null) paquetes guardados" 1
}

# No se guardan datos de usuario: la reinstalacion es sin conservar datos ni configuracion.

wipe_container() {
  local n="$1"
  bar 1 3 "Borrando rootfs de '$n' con proot-distro" 1
  proot-distro remove "$n" --force >/dev/null 2>&1 \
    || printf 'y\n' | proot-distro remove "$n" >/dev/null 2>&1 \
    || true
  bar 2 3 "Limpiando restos de '$n'" 1
  [ -d "$C/$n" ] && rm -rf "$C/$n" 2>/dev/null || true
  bar 3 3 "Rootfs de '$n' eliminada" 1
}

apps_for() {
case "$1" in
  archlinux)
    GRP=wheel
    APPS="
      sudo dbus dbus-x11 xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-kde
      plasma-desktop plasma-workspace kwin systemsettings kglobalacceld
      plasma-pa plasma-nm plasma-discover breeze kde-gtk-config kwin-addons
      dolphin konsole kde-cli-tools kio-extras kio-admin ffmpegthumbs kdegraphics-thumbnailers
      ark gwenview okular kate kcalc kontact
      flatpak packagekit-qt6 polkit polkit-kde-agent
      pulseaudio pulseaudio-alsa pavucontrol pipewire libcanberra
      phonon-qt6-gstreamer qt6-multimedia gst-plugin-pulseaudio
      gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav
      networkmanager wpa_supplicant modemmanager
      mesa libglvnd qqc2-desktop-style
      firefox thunderbird libreoffice-fresh vlc mpv ffmpeg gimp inkscape krita
    " ;;
  debian|ubuntu|kali|linuxmint|parrot)
    GRP=sudo
    APPS="
      sudo dbus dbus-x11 xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-kde
      kde-plasma-desktop plasma-discover systemsettings kglobalacceld
      plasma-nm plasma-workspace-data plasma-desktop-data network-manager wpasupplicant modemmanager
      dolphin konsole kde-cli-tools kdegraphics-thumbnailers ffmpegthumbs
      ark gwenview okular kate kcalc kontact
      flatpak packagekit polkitd polkit-kde-agent-1
      pulseaudio pavucontrol pipewire
      libcanberra-pulse libcanberra-gtk3-module phonon4qt6 phonon4qt6-backend-vlc
      libqt6multimedia6 qml6-module-qtmultimedia gstreamer1.0-pulseaudio
      gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav
      firefox-esr thunderbird libreoffice libreoffice-writer libreoffice-calc libreoffice-impress
      vlc mpv ffmpeg gimp inkscape krita
      kwin-addons qml-module-org-kde-qqc2desktopstyle libkf6qqc2desktopstyle-data plasma-widgets-addons qml6-module-org-kde-kirigami libkirigamiplatform6
      mesa-vulkan-drivers libgl1-mesa-dri
    " ;;
  fedora)
    GRP=wheel
    APPS="
      sudo dbus dbus-x11 xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-kde
      @kde-desktop plasma-discover systemsettings kglobalacceld
      NetworkManager wpa_supplicant modemmanager kwin-addons
      dolphin konsole kde-cli-tools kdegraphics-thumbnailers ffmpegthumbs
      ark gwenview okular kate kcalc kontact
      flatpak packagekit polkit polkit-kde-agent
      pulseaudio pavucontrol pipewire libcanberra phonon-qt6-gstreamer qt6-qtmultimedia
      gstreamer1-plugins-base gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-libav
      firefox thunderbird libreoffice libreoffice-writer libreoffice-calc libreoffice-impress
      vlc mpv ffmpeg gimp inkscape krita
      qqc2-desktop-style mesa-dri-drivers
    " ;;
  alpine)
    GRP=wheel
    APPS="
      sudo dbus dbus-x11 xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-kde
      plasma systemsettings kglobalacceld
      network-manager wpa-supplicant modemmanager kwin-addons
      dolphin konsole ark gwenview okular kate kcalc kontact
      flatpak polkit polkit-kde-agent
      pulseaudio pavucontrol pipewire libcanberra phonon-qt6-gstreamer qt6-qtmultimedia
      gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav
      firefox thunderbird libreoffice vlc mpv ffmpeg gimp inkscape krita
      mesa-dri-gallium
    " ;;
  opensuse)
    GRP=wheel
    APPS="
      sudo dbus dbus-x11 xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-kde
      plasma-desktop kwin systemsettings kglobalacceld plasma-nm
      NetworkManager wpa_supplicant modemmanager kwin-addons
      dolphin konsole ark gwenview okular kate kcalc kontact
      plasma-discover flatpak packagekit polkit polkit-kde-agent
      pulseaudio pavucontrol pipewire libcanberra phonon-qt6-gstreamer qt6-qtmultimedia
      gstreamer-plugins-base gstreamer-plugins-good gstreamer-plugins-bad gstreamer-plugins-libav
      firefox thunderbird libreoffice vlc mpv ffmpeg gimp inkscape krita
      Mesa-dri-plugins qqc2-desktop-style
    " ;;
  void)
    GRP=wheel
    APPS="
      sudo dbus dbus-x11 xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-kde
      kde5 systemsettings kglobalacceld
      NetworkManager wpa_supplicant modemmanager kwin-addons
      dolphin konsole ark gwenview okular kate kcalc kontact
      discover flatpak polkit polkit-kde-agent
      pulseaudio pavucontrol pipewire libcanberra phonon-qt6-gstreamer qt6-qtmultimedia
      gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav
      firefox thunderbird libreoffice vlc mpv ffmpeg gimp inkscape krita
      mesa-dri-driver-llvmpipe
    " ;;
  *)
    GRP=wheel
    APPS="sudo dbus dbus-x11 xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-kde flatpak pulseaudio pavucontrol pipewire network-manager" ;;
esac
}


build_one() {
  local NAME="$1" FULL="$2" FROM_BACKUP="${3:-0}" RST="${4:-1}" IDX="${5:-1}" TOT="${6:-1}"
# ---------- 2) Contenedor ----------
note ">>> TRABAJANDO EN: '$NAME' (modo $FULL) <<<"
say "Contenedor '$NAME' [$IDX/$TOT]: preparando rootfs"
bar 1 6 "Preparando rootfs de '$NAME' [$IDX/$TOT]" 1
if [[ -e "$C/$NAME/rootfs/bin/sh" ]]; then
  echo "Contenedor existente y valido: se reutiliza."
else
  proot-distro list -q 2>/dev/null | grep -qx "$NAME" && proot-distro remove "$NAME"
  ok=0
  for i in 1 2 3; do
    if [[ "$NAME" == "archlinux" ]]; then
      echo "Descargando menci/archlinuxarm (intento $i/3)..."
      proot-distro install menci/archlinuxarm --name archlinux && { ok=1; break; }
    else
      echo "Descargando $NAME (intento $i/3)..."
      proot-distro install "$NAME" && { ok=1; break; }
    fi
    echo "Reintentando en 5s..."
    sleep 5
  done
  [[ "$ok" == 1 ]] || fail "No se pudo instalar '$NAME'. Revisa nombre/conexion."
fi
[[ -e "$C/$NAME/rootfs/bin/sh" ]] || fail "rootfs de '$NAME' no valido."
bar 2 6 "Rootfs de '$NAME' lista" 1

# En reinstalacion: devolver solo el manifiesto (sin datos ni configuracion).
if [ "${FROM_BACKUP:-0}" = 1 ]; then
  note "Devolviendo el manifiesto al rootfs nuevo..."
  mkdir -p "$C/$NAME/rootfs/root"
  cp "$BKBASE/$NAME/packages.txt" "$C/$NAME/rootfs/root/installed-packages.txt" 2>/dev/null || true
  bar 3 6 "Manifiesto devuelto al rootfs (sin datos de usuario)" 1
else
  bar 3 6 "Sin manifiesto previo: instalacion limpia" 1
fi

# ---------- 3) Apps completas por distro ----------
# Nota: se instalan una por una; si un paquete no existe en esa distro, se omite y se sigue.
apps_for "$NAME"
bar 4 6 "Perfil cargado: $(printf '%s\n' $APPS | wc -w) paquetes base" 1

# ---------- 4) Todo dentro del contenedor ----------
say "Instalando sistema completo en '$NAME'"
RESET=0
if [ "$FULL" = 2 ]; then
  RESET=1
  echo "   Reinstalacion: rootfs nuevo, config nativa, sin datos de usuario."
elif [ "$FULL" = 3 ]; then
  echo "   Actualizacion: se conservan datos y configuracion actuales."
else
  echo "   Instalacion directa desde cero: sin reset, sin purga, sin backup."
fi

bar 5 6 "Instalando y configurando dentro de '$NAME'" 1
proot-distro login "$NAME" -- /bin/sh -s "$NAME" "$GRP" "$APPS" "$RESET" "$FULL" <<'EOS'
NAME="$1"
GRP="$2"
APPS="$3"
RESET="${4:-0}"
FULL="${5:-0}"
case "$FULL" in 2) RESET=1 ;; esac

now() { date '+%H:%M:%S'; }
bar() { # actual total etiqueta [1=salto de linea]
  local cur="$1" tot="$2" label="${3:-}" w=24 p=0 f=0
  [ "${tot:-0}" -gt 0 ] 2>/dev/null && p=$(( cur * 100 / tot ))
  [ "$p" -gt 100 ] && p=100
  f=$(( p * w / 100 ))
  printf '\r[%s] %3d%% [' "$(now)" "$p"
  printf '%*s' "$f" '' | tr ' ' '#'
  printf '%*s' "$((w-f))" '' | tr ' ' '.'
  printf '] %-*.*s' "$w" "$w" "$label"
  [ "${4:-0}" = 1 ] && printf '\n' || true
}

# --- Detectar gestor de paquetes ---
PM=""
for c in pacman apt-get dnf apk zypper xbps-install; do
  command -v "$c" >/dev/null 2>&1 && { PM="$c"; break; }
done
echo "   Gestor detectado: $PM"
bar 1 5 "Fase 1/5 - actualizando indices del gestor" 1

# --- Actualizacion base ---
case "$PM" in
  pacman)
    sed -i "s/^DownloadUser[[:space:]]*=.*/#DownloadUser disabled/" /etc/pacman.conf
    grep -q "^DisableSandbox" /etc/pacman.conf || sed -i "/^\[options\]/a DisableSandbox" /etc/pacman.conf
    grep -q "^DisableDownloadTimeout" /etc/pacman.conf || sed -i "/^\[options\]/a DisableDownloadTimeout" /etc/pacman.conf
    sed -i "s/^ParallelDownloads[[:space:]]*=.*/ParallelDownloads = 2/" /etc/pacman.conf
    pacman-key --init >/dev/null 2>&1
    pacman-key --populate archlinuxarm >/dev/null 2>&1
    pacman -Syyu --noconfirm || echo "   (!) Fallo parcial en pacman -Syyu"
    ;;
  apt-get) apt-get update -y ;;
  dnf)     dnf -y update ;;
  apk)     apk update ;;
  zypper)  zypper --non-interactive refresh ;;
  xbps-install) xbps-install -Suy ;;
esac

if [ "$FULL" = 3 ]; then
  echo "   Modo ACTUALIZACION: actualizando todos los paquetes instalados..."
  case "$PM" in
    apt-get)      DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade || true ;;
    pacman)       pacman -Syu --noconfirm || true ;;
    dnf)          dnf -y upgrade || true ;;
    apk)          apk upgrade || true ;;
    zypper)       zypper --non-interactive update || true ;;
    xbps-install) xbps-install -Suy || true ;;
  esac
fi

bar 2 5 "Fase 2/5 - instalacion verificada de paquetes" 1

# --- Instalar y VERIFICAR de verdad (no confiar solo en el codigo de salida) ---
# En proot, apt/dnf pueden devolver error por scripts de systemd/postinst y aun asi instalar el paquete.
# Por eso se comprueba la base de datos del gestor despues de intentar.
verified() {
  case "$PM" in
    apt-get)      dpkg -s "$1" 2>/dev/null | grep -q '^Status: install ok installed' ;;
    pacman)       pacman -Qi "$1" >/dev/null 2>&1 ;;
    dnf|zypper)   rpm -q "$1" >/dev/null 2>&1 ;;
    apk)          apk info -e "$1" >/dev/null 2>&1 ;;
    xbps-install) xbps-query -S "$1" >/dev/null 2>&1 ;;
    *)            return 1 ;;
  esac
}
inst() {
  p="$1"; i=1
  while [ "$i" -le 2 ]; do
    case "$PM" in
      apt-get)      DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Progress=1 -o Dpkg::Progress-Fancy=1 install -y --no-install-recommends "$p" ;;
      pacman)       pacman -S --noconfirm --needed "$p" ;;
      dnf)          dnf -y install "$p" ;;
      apk)          apk add --no-cache "$p" ;;
      zypper)       zypper --non-interactive install "$p" ;;
      xbps-install) xbps-install -Sy "$p" ;;
    esac
    [ "$PM" = dnf ] && [ "${p#@}" != "$p" ] && return 0
    verified "$p" && return 0
    i=$((i+1))
  done
  return 1
}

bar 3 5 "Fase 3/5 - manifiesto, purga y reconstruccion" 1

# --- MODO 2: mostrar lista, purgar Plasma y reconstruir con esa misma lista ---
TOINSTALL="$APPS"
LIST=/root/installed-packages.txt
if [ "$FULL" = 2 ]; then
  echo
  echo "==================================================================="
  echo " PAQUETES INSTALADOS ANTES DE LA REINSTALACION: $(wc -l < "$LIST" 2>/dev/null)"
  echo "==================================================================="
  cat "$LIST" 2>/dev/null || true
  echo "=================== FIN DE LA LISTA ================================"
  echo

  echo "   Purgando Plasma/KDE completo..."
  case "$PM" in
    apt-get)
      PURGE=$(grep -E '^(plasma|kde|kwin|kf[0-9]|libkf[0-9]|qml6?-module-org-kde|kglobalacceld|kded|kio|kirigami|breeze|oxygen|qqc2|polkit-kde|xdg-desktop-portal-kde|packagekit|kbuildsycoca|baloo|akonadi|kontact|kmail|korganizer|konsole|dolphin|ark|gwenview|okular|kate|kcalc|kwrite|plasmashell)' "$LIST" 2>/dev/null | tr '\n' ' ')
      echo "   -> apt: $(printf '%s\n' $PURGE | wc -w) paquetes Plasma + perfil"
      DEBIAN_FRONTEND=noninteractive apt-get purge -y $PURGE $APPS || true
      apt-get autoremove --purge -y || true
      apt-get update -y || true
      ;;
    pacman)
      PURGE=$(grep -E '^(plasma|kde|kwin|kf[0-9]|libkf[0-9]|kirigami|breeze|oxygen|dolphin|konsole|ark|gwenview|okular|kate)' "$LIST" 2>/dev/null | tr '\n' ' ')
      echo "   -> pacman: $(printf '%s\n' $PURGE | wc -w) paquetes Plasma"
      pacman -Rsn --noconfirm $PURGE || true
      ;;
    dnf)     dnf remove -y $APPS || true ;;
    apk)     apk del $APPS || true ;;
    zypper)  zypper --non-interactive remove $APPS || true ;;
    xbps-install) xbps-remove -R $APPS || true ;;
  esac
  echo "   Purga terminada. Reconstruyendo desde la lista guardada..."
  TOINSTALL="$APPS $(tr '\n' ' ' < "$LIST" 2>/dev/null)"
  TOINSTALL=$(printf '%s\n' $TOINSTALL | sort -u | tr '\n' ' ')
fi

n_ok=0; n_bad=0
NP=$(printf '%s\n' $TOINSTALL | wc -w); ip=0
for p in $TOINSTALL; do
  ip=$((ip+1))
  bar "$ip" "$NP" "$(printf '%3d/%3d %-20.20s' "$ip" "$NP" "$p")"
  if inst "$p"; then
    n_ok=$((n_ok+1))
    bar "$ip" "$NP" "$(printf '%3d/%3d %-20.20s OK' "$ip" "$NP" "$p")"
  else
    n_bad=$((n_bad+1))
    bar "$ip" "$NP" "$(printf '%3d/%3d %-20.20s FALLO' "$ip" "$NP" "$p")" 1
    echo "   (!) Realmente ausente: $p  (revisa la salida del gestor justo arriba)"
  fi
done
printf '\n'
echo "   Verificado: $n_ok instalados | $n_bad ausentes de verdad"

bar 4 5 "Fase 4/5 - usuario, D-Bus, polkit y PipeWire" 1

# --- Usuario real del sistema ---
groupadd "$GRP" 2>/dev/null || true
if ! id user >/dev/null 2>&1; then
  if [ -x /bin/bash ]; then
    useradd -m -u 1000 -s /bin/bash user 2>/dev/null || useradd -m -s /bin/bash user
  else
    useradd -m -u 1000 -s /bin/sh user 2>/dev/null || useradd -m -s /bin/sh user
  fi
fi
usermod -aG "$GRP",audio,video,storage user 2>/dev/null || true
passwd -d user >/dev/null 2>&1 || true
passwd -d root >/dev/null 2>&1 || true
mkdir -p /etc/sudoers.d
echo "user ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/user
chmod 440 /etc/sudoers.d/user

# --- Reset de configuracion heredada (de otro instalador / otra distro) ---
if [ "$RESET" = 1 ]; then
  BK="/home/user/.proot-reset-$(date +%Y%m%d%H%M%S)"
  mkdir -p "$BK"
  for d in .config .cache .local/share; do
    if [ -e "/home/user/$d" ]; then mv "/home/user/$d" "$BK/$d" 2>/dev/null || true; fi
  done
  echo "   Configuracion anterior respaldada en: $BK"
fi

# --- Bus del sistema propio para proot (configura todo desde cero) ---
id messagebus >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin -d /nonexistent messagebus 2>/dev/null || true
mkdir -p /etc/dbus-1 /run/dbus /etc/polkit-1/rules.d
cat > /etc/dbus-1/proot-system.conf <<'DBCFG'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>system</type>
  <listen>unix:path=/run/dbus/system_bus_socket</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow user="*"/>
    <allow own="*"/>
    <allow send_type="method_call"/>
    <allow send_type="signal"/>
    <allow receive_sender="*"/>
    <allow receive_type="method_call"/>
    <allow receive_type="signal"/>
  </policy>
</busconfig>
DBCFG
cat > /etc/polkit-1/rules.d/49-proot-nopasswd.rules <<'POLKIT'
polkit.addRule(function(action, subject) {
    return polkit.Result.YES;
});
POLKIT
chown -R messagebus:messagebus /run/dbus 2>/dev/null || true
pkill -f "[d]bus-daemon" 2>/dev/null || true
rm -f /run/dbus/system_bus_socket
dbus-daemon --config-file=/etc/dbus-1/proot-system.conf --nofork >/dev/null 2>&1 &
sleep 1
dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId >/dev/null 2>&1 \
  || echo "(!) Bus caido"
if command -v polkitd >/dev/null 2>&1; then
  pkill -x polkitd 2>/dev/null || true
  polkitd --no-debug >/dev/null 2>&1 &
fi
mkdir -p /run/dbus /tmp/runtime-user /tmp/.ICE-unix
rm -rf /tmp/.ICE-unix; mkdir -p /tmp/.ICE-unix
chown root:root /tmp/.ICE-unix 2>/dev/null || true
chmod 1777 /tmp/.ICE-unix 2>/dev/null || true
chown user:user /tmp/runtime-user 2>/dev/null || true
chmod 700 /tmp/runtime-user 2>/dev/null || true

# --- Flathub: systema Y usuario (el modo usuario evita system-helper/fuse) ---
FLATHUB="https://dl.flathub.org/repo/flathub.flatpakrepo"
if command -v flatpak >/dev/null 2>&1; then
  flatpak remote-add --if-not-exists flathub "$FLATHUB" >/dev/null 2>&1 || true
  su user -c "XDG_RUNTIME_DIR=/tmp/runtime-user flatpak remote-add --user --if-not-exists flathub '$FLATHUB'" >/dev/null 2>&1 || true
  # Atajo para instalar tiendas sin depender del bus del sistema
  cat > /usr/local/bin/flatpak-user <<'FP'
#!/bin/sh
exec flatpak --user "$@"
FP
  chmod +x /usr/local/bin/flatpak-user 2>/dev/null || true
fi

# --- Silenciar solo lo que no sirve en proot (NO borrar servicios systemd/KAuth) ---
rm -f /usr/share/dbus-1/services/org.freedesktop.portal.Documents.service 2>/dev/null || true
rm -f /etc/xdg/autostart/pipewire*.desktop /etc/xdg/autostart/wireplumber*.desktop 2>/dev/null || true
# La ruta que realmente busca PipeWire es /etc/pipewire/client.conf o ~/.config/pipewire/client.conf.
# La copia anterior desde /usr/share/pipewire no sirve: ahi no la lee. La creamos directamente.
mkdir -p /etc/pipewire
cat > /etc/pipewire/client.conf <<'PWCLIENT'
context.properties = {
    log.level = 0
}
PWCLIENT

# --- Entorno software (evita Zink/EGL sin GPU) ---
cat > /etc/profile.d/zz-proot-env.sh <<'ENV'
export DISPLAY="${DISPLAY:-:0}"
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=KDE
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
ENV
chmod 644 /etc/profile.d/zz-proot-env.sh 2>/dev/null || true

bar 5 5 "Fase 5/5 - configuracion nativa de Plasma" 1

# --- Configuracion como user ---
chown -R user:user /home/user 2>/dev/null || true
mkdir -p /home/user/.config /home/user/.config/kdedefaults /home/user/.local/share /home/user/.config/pipewire
[ -f /home/user/.config/kdedefaults/package ] || printf '[General]\nPackage=kde\n' > /home/user/.config/kdedefaults/package

# PipeWire real: daemon con tunel a el PulseAudio de Termux. Asi kpipewire no insiste cada 5s.
cat > /home/user/.config/pipewire/client.conf <<'PWCLIENT'
context.properties = {
    log.level = 0
}
PWCLIENT
cat > /home/user/.config/pipewire/pipewire.conf <<'PWDAEMON'
context.modules = [
    { name = libpipewire-module-protocol-native args = { } }
    { name = libpipewire-module-pulse-tunnel
      flags = [ ( ifexists ) ( nofail ) ]
      args = {
        tunnel.mode = sink
        pulse.server.address = "tcp:127.0.0.1"
        pulse.latency = 200
      }
    }
]
PWDAEMON
chown -R user:user /home/user/.config/pipewire 2>/dev/null || true
[ -d /etc/skel ] && cp -r /etc/skel/. /home/user/ 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true
update-mime-database /usr/share/mime 2>/dev/null || true
fc-cache -f >/dev/null 2>&1 || true

if command -v startplasma-x11 >/dev/null 2>&1; then
  cat > /home/user/.config/kwinrc <<EOF
[Compositing]
Enabled=false
EOF
  cat > /home/user/.config/kdeglobals <<EOF
[General]
GraphicEffectsLevel=0
EOF
fi

for k in kbuildsycoca6 kbuildsycoca5 kbuildsycoca; do
  command -v "$k" >/dev/null 2>&1 && su user -c "XDG_CONFIG_HOME=/home/user/.config $k --noincremental" >/dev/null 2>&1 && break
done
for b in balooctl6 balooctl5 balooctl; do
  command -v "$b" >/dev/null 2>&1 && su user -c "$b disable" >/dev/null 2>&1 && break
done
chown -R user:user /home/user/.config /home/user/.local 2>/dev/null || true
rm -f /root/.config/kwinrc /root/.config/kdeglobals 2>/dev/null || true
echo "   UID user = $(id -u user) / grupo = $GRP"
EOS

if [[ "${FULL:-0}" == 2 ]]; then
  cp "$C/$NAME/rootfs/root/installed-packages.txt" "$HOME/installed-packages-$NAME.txt" 2>/dev/null || true
  echo "Lista completa guardada tambien en: $HOME/installed-packages-$NAME.txt"
fi
bar 6 6 "'$NAME' terminado" 1
}

# ---------- 4b) Ejecucion (una o todas las distros) ----------
if [ "$FULL" = 2 ]; then
  TARGETS=()
  if [ "$ALL" = 1 ]; then
    for d in "$C"/*/rootfs/bin/sh; do
      [[ -e "$d" ]] || continue
      n=${d#"$C"/}; n=${n%%/*}; TARGETS+=("$n")
    done
  else
    TARGETS+=("$NAME")
  fi
  (( ${#TARGETS[@]} )) || fail "No hay distros objetivo para reinstalar."
  echo
  echo "==================================================================="
  echo " DESTINOS DE LA REINSTALACION (${#TARGETS[@]}): ${TARGETS[*]}"
  echo "==================================================================="
  read -rp "¿Continuar con ESTOS destinos? [s/N]: " cf
  cf=${cf:-n}
  case "${cf,,}" in s|si|y|yes) ;; *) echo "Cancelado: no se borro nada."; exit 0 ;; esac
  ii=0
  for t in "${TARGETS[@]}"; do
    ii=$((ii+1))
    say "DISTRO $ii/${#TARGETS[@]} -> '$t'"
    if [[ -e "$C/$t/rootfs/bin/sh" ]]; then
      note "Respaldando TODOS los paquetes de '$t' (sin datos ni configuracion)"
      backup_manifest "$t"
      echo "   Manifest: $BKBASE/$t/packages.txt ($(wc -l < "$BKBASE/$t/packages.txt" 2>/dev/null) paquetes)"
      say "Borrando rootfs completo de '$t'"
      wipe_container "$t"
      say "Reinstalando '$t' con TODOS sus paquetes y Plasma nativo"
      build_one "$t" 2 1 1 "$ii" "${#TARGETS[@]}"
      ok "'$t' reinstalada con Plasma nativo"
    else
      note "'$t' no estaba instalada: instalacion limpia de '$t'"
      build_one "$t" 1 0 0 "$ii" "${#TARGETS[@]}"
      ok "'$t' instalada desde cero"
    fi
  done
else
  build_one "$NAME" "$FULL" 0 "$RESET" 1 1
fi


# ---------- 5) Lanzador ----------
say "Instalando el lanzador startdesktop"
mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/startdesktop" <<'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
# Configurar primero, ejecutar despues. Senal por argumentos/stdin, sin archivos temporales.
set -u
now() { date '+%H:%M:%S'; }
bar() { # actual total etiqueta [1=salto de linea]
  local cur="$1" tot="$2" label="${3:-}" w=24 p=0 f=0
  [ "${tot:-0}" -gt 0 ] 2>/dev/null && p=$(( cur * 100 / tot ))
  [ "$p" -gt 100 ] && p=100
  f=$(( p * w / 100 ))
  printf '\r[%s] %3d%% [' "$(now)" "$p"
  printf '%*s' "$f" '' | tr ' ' '#'
  printf '%*s' "$((w-f))" '' | tr ' ' '.'
  printf '] %-*.*s' "$w" "$w" "$label"
  [ "${4:-0}" = 1 ] && printf '\n' || true
}
BASE="$PREFIX/var/lib/proot-distro/containers"
DISTROS=()
for d in "$BASE"/*/rootfs/bin/sh; do
  [[ -e "$d" ]] || continue
  n=${d#"$BASE"/}; n=${n%%/*}; DISTROS+=("$n")
done
(( ${#DISTROS[@]} )) || { echo "No hay distros instaladas."; exit 1; }

if [[ -n "${1:-}" ]]; then
  SEL="$1"; [[ -e "$BASE/$SEL/rootfs/bin/sh" ]] || { echo "No existe '$SEL'."; exit 1; }
else
  while true; do
    echo; echo "===== 1/3 DISTRO ====="; echo; echo "  0) Automatico"
    i=1; for n in "${DISTROS[@]}"; do printf '  %s) %s\n' "$i" "$n"; ((i++)); done; echo
    read -rp "Elige distro [0]: " opt; opt=${opt:-0}
    [[ "$opt" =~ ^[0-9]+$ ]] || { echo ">> Solo numeros."; continue; }
    if (( opt == 0 )); then
      if (( ${#DISTROS[@]} == 1 )); then SEL=${DISTROS[0]}; echo ">> Unica distro: $SEL"; break; fi
      echo ">> Hay ${#DISTROS[@]} distros. Elige una."; continue
    fi
    (( opt >= 1 && opt <= ${#DISTROS[@]} )) && { SEL=${DISTROS[$((opt-1))]}; break; }
    echo ">> Invalido."
  done
fi

AUTOUSER=""
if grep -q '^user:' "$BASE/$SEL/rootfs/etc/passwd" 2>/dev/null; then AUTOUSER=user
else AUTOUSER=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' "$BASE/$SEL/rootfs/etc/passwd" 2>/dev/null); fi
[[ -z "$AUTOUSER" ]] && AUTOUSER=root

if [[ -n "${2:-}" ]]; then MODE="$2"; RUNAS="${3:-$AUTOUSER}"; [[ "$MODE" == root ]] && RUNAS=root
else
  while true; do
    echo; echo "===== 2/3 MODO ====="; echo
    echo "  1) user -> $AUTOUSER (predeterminado)"
    echo "  2) root -> mismo entorno que Termux"
    echo "  3) escribir usuario"; echo
    read -rp "Elige modo [1]: " m; m=${m:-1}
    case "$m" in
      1) MODE=user; RUNAS="$AUTOUSER"; break ;;
      2) MODE=root; RUNAS=root; break ;;
      3) read -rp "Usuario: " RUNAS; [[ -z "$RUNAS" ]] && { echo ">> Vacio."; continue; }; MODE=custom; break ;;
      *) echo ">> Invalido." ;;
    esac
  done
fi
case "$MODE" in 1|user) MODE=user;; 2|root) MODE=root; RUNAS=root;; 3|custom) MODE=custom;; *) exit 1;; esac

echo; echo "===== 3/3 RESUMEN ====="; echo
echo "  Distro : $SEL"; echo "  Modo   : $MODE"; echo "  Usuario: $RUNAS"; echo
read -rp "¿Iniciar? [S/n]: " go; go=${go:-s}
case "${go,,}" in s|si|y|yes) ;; *) echo "Cancelado."; exit 0;; esac

echo
bar 1 3 "PulseAudio TCP en 127.0.0.1" 1
termux-wake-lock 2>/dev/null
pkill -f 'termux.x11' 2>/dev/null; sleep 1
unset PULSE_SERVER
pulseaudio --kill 2>/dev/null; sleep 1
pulseaudio --start --exit-idle-time=-1 --load="module-native-protocol-tcp auth-anonymous=1 auth-ip-acl=127.0.0.1"
export XDG_RUNTIME_DIR="$TMPDIR"
bar 2 3 "termux-x11 :0" 1
termux-x11 :0 >/dev/null 2>&1 & sleep 3
command -v am >/dev/null 2>&1 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
sleep 1
bar 3 3 "Entrando en '$SEL'" 1
echo; echo ">> Senal: $SEL / $MODE / $RUNAS"
proot-distro login "$SEL" --shared-tmp -- /bin/sh -s "$MODE" "$RUNAS" "$SEL" <<'INNER_EOF'
MODE="$1"; RUNAS="$2"; SEL="$3"
export LANG=C.UTF-8; export LC_ALL=C.UTF-8
export DISPLAY=:0 XDG_SESSION_TYPE=x11 XDG_CURRENT_DESKTOP=KDE
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
now() { date '+%H:%M:%S'; }
bar() { # actual total etiqueta [1=salto de linea]
  local cur="$1" tot="$2" label="${3:-}" w=24 p=0 f=0
  [ "${tot:-0}" -gt 0 ] 2>/dev/null && p=$(( cur * 100 / tot ))
  [ "$p" -gt 100 ] && p=100
  f=$(( p * w / 100 ))
  printf '\r[%s] %3d%% [' "$(now)" "$p"
  printf '%*s' "$f" '' | tr ' ' '#'
  printf '%*s' "$((w-f))" '' | tr ' ' '.'
  printf '] %-*.*s' "$w" "$w" "$label"
  [ "${4:-0}" = 1 ] && printf '\n' || true
}
rm -f /etc/resolv.conf
printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf
if [ "$MODE" = root ]; then U=root
elif id "$RUNAS" >/dev/null 2>&1; then U="$RUNAS"
else echo ">> '$RUNAS' no existe en $SEL. Se usa root."; U=root; fi
mkdir -p "/tmp/runtime-$U"; chown "$U": "/tmp/runtime-$U" 2>/dev/null; chmod 700 "/tmp/runtime-$U"
rm -rf /tmp/.ICE-unix /run/dbus; mkdir -p /tmp/.ICE-unix /run/dbus
chown root:root /tmp/.ICE-unix 2>/dev/null; chmod 1777 /tmp/.ICE-unix 2>/dev/null

bar 1 5 "Bus del sistema" 1
# Config de bus propio (se regenera si el contenedor viene de otro instalador)
id messagebus >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin -d /nonexistent messagebus 2>/dev/null || true
mkdir -p /etc/dbus-1 /etc/polkit-1/rules.d
if [ ! -f /etc/dbus-1/proot-system.conf ]; then
  cat > /etc/dbus-1/proot-system.conf <<'DBCFGL'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>system</type>
  <listen>unix:path=/run/dbus/system_bus_socket</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow user="*"/>
    <allow own="*"/>
    <allow send_type="method_call"/>
    <allow send_type="signal"/>
    <allow receive_sender="*"/>
    <allow receive_type="method_call"/>
    <allow receive_type="signal"/>
  </policy>
</busconfig>
DBCFGL
fi
cat > /etc/polkit-1/rules.d/49-proot-nopasswd.rules <<'POLKITL'
polkit.addRule(function(action, subject) {
    return polkit.Result.YES;
});
POLKITL
chown -R messagebus:messagebus /run/dbus 2>/dev/null || true
pkill -f "[d]bus-daemon" 2>/dev/null || true
rm -f /run/dbus/system_bus_socket
dbus-daemon --config-file=/etc/dbus-1/proot-system.conf --nofork >/dev/null 2>&1 &
sleep 1
dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId >/dev/null 2>&1 \
  || echo "(!) Bus caido"
bar 2 5 "Polkit" 1
if command -v polkitd >/dev/null 2>&1; then
  pkill -x polkitd 2>/dev/null || true
  polkitd --no-debug >/dev/null 2>&1 &
fi
bar 3 5 "Red y atajos de teclado" 1
if command -v NetworkManager >/dev/null 2>&1; then
  if ! ps 2>/dev/null | grep -q '[N]etworkManager'; then NetworkManager >/dev/null 2>&1 & fi
fi
if command -v kglobalacceld >/dev/null 2>&1; then
  if ! ps 2>/dev/null | grep -q '[k]globalacceld'; then kglobalacceld >/dev/null 2>&1 & fi
fi
# Polkit: la regla 49 ya autoriza todo; no se necesita agente en proot.
bar 4 5 "PipeWire" 1
# PipeWire con tunel a PulseAudio: crea /tmp/runtime-<usuario>/pipewire-0 y calla el media monitor.
if command -v pipewire >/dev/null 2>&1; then
  if ! ps 2>/dev/null | grep -q '[p]ipewire'; then
    su "$U" -c "XDG_RUNTIME_DIR=/tmp/runtime-$U PULSE_SERVER=tcp:127.0.0.1 DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket pipewire" >/dev/null 2>&1 &
  fi
fi
sleep 3
DE=""
for c in startplasma-x11 startxfce4 startlxqt startlxde mate-session gnome-session lxsession i3 sway; do
  command -v "$c" >/dev/null 2>&1 && { DE="$c"; break; }
done
[ -z "$DE" ] && { echo "No hay escritorio en $SEL."; exit 1; }
bar 5 5 "$DE como '$U'" 1
RUN=""; command -v dbus-run-session >/dev/null 2>&1 && RUN="dbus-run-session --"
if [ "$U" != root ]; then
  echo ">> $DE como '$U' en '$SEL' (UID $(id -u "$U"))..."
  exec su "$U" -c "env DISPLAY=:0 PULSE_SERVER=tcp:127.0.0.1 XDG_RUNTIME_DIR=/tmp/runtime-$U DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket XDG_SESSION_TYPE=x11 XDG_CURRENT_DESKTOP=KDE LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe MESA_LOADER_DRIVER_OVERRIDE=llvmpipe LANG=C.UTF-8 LC_ALL=C.UTF-8 $RUN $DE"
else
  echo ">> $DE como root (modo Termux) en '$SEL'..."
  exec env DISPLAY=:0 PULSE_SERVER=tcp:127.0.0.1 XDG_RUNTIME_DIR=/tmp/runtime-$U DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket XDG_SESSION_TYPE=x11 XDG_CURRENT_DESKTOP=KDE LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe MESA_LOADER_DRIVER_OVERRIDE=llvmpipe LANG=C.UTF-8 LC_ALL=C.UTF-8 $RUN "$DE"
fi
INNER_EOF
exit $?
LAUNCHER
chmod +x "$PREFIX/bin/startdesktop"

say "TERMINADO"
echo "Distro instalada: $NAME"
echo "Arranca con: startdesktop"
echo "Tienda sin bus del sistema: flatpak-user install flathub <app>"
