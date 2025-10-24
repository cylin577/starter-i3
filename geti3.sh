#!/usr/bin/env bash
set -euo pipefail

### -------------------------
### Configuration / Defaults
### -------------------------
LOGFILE="${HOME}/.i3-starter-$(date +%Y%m%d%H%M%S).log"
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
KEEP_SUDO_PID=""
NONINTERACTIVE=false
DO_APPEARANCE=true
DO_WALLPAPER=true

# Package lists
PKGS_DEBIAN=(
  i3
  xinit
  x11-xserver-utils
  xterm
  picom
  feh
  fonts-noto-color-emoji
  fonts-jetbrains-mono
  arc-theme
  papirus-icon-theme
  alacritty
  xfce4-settings
  breeze-cursor-theme
  rofi
)

PKGS_ARCH=(
  i3-wm
  xorg-xinit
  xorg-xprop
  xorg-xrandr
  xorg-xset
  xorg-xinput
  xterm
  picom
  feh
  noto-fonts-emoji
  ttf-jetbrains-mono
  arc-gtk-theme
  papirus-icon-theme
  alacritty
  xfce4-settings
  breeze-cursor-theme
  rofi
)

### -------------------------
### Helpers
### -------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"; }
err() { echo "ERROR: $*" >&2; log "ERROR: $*"; exit 1; }

detect_distro() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID,,}"
    DISTRO_NAME="$NAME"
  else
    DISTRO_ID="unknown"
    DISTRO_NAME="unknown"
  fi
}

check_source_exists() { [ -e "$1" ] || err "Required file/directory not found: $1"; }
backup_if_exists() { [ -e "$1" ] && mv -v "$1" "$1.backup.$BACKUP_SUFFIX" | tee -a "$LOGFILE"; }

start_sudo_keepalive() {
  sudo -v || err "sudo authentication failed"
  ( while true; do sudo -n true >/dev/null 2>&1 || exit 0; sleep 60; done ) &
  KEEP_SUDO_PID=$!
  log "Started sudo keepalive (pid=$KEEP_SUDO_PID)"
}
stop_sudo_keepalive() {
  [ -n "${KEEP_SUDO_PID:-}" ] && kill -0 "$KEEP_SUDO_PID" 2>/dev/null && kill "$KEEP_SUDO_PID" || true
  log "Stopped sudo keepalive"
}

install_debian_pkgs() { sudo apt update | tee -a "$LOGFILE"; sudo apt install -y "${PKGS_DEBIAN[@]}" | tee -a "$LOGFILE"; }
install_arch_pkgs() { sudo pacman -Syu --noconfirm | tee -a "$LOGFILE"; sudo pacman -S --noconfirm "${PKGS_ARCH[@]}" | tee -a "$LOGFILE"; }

ensure_xsession() {
  [ ! -f "$HOME/.xinitrc" ] && echo -e "exec i3" > "$HOME/.xinitrc" && chmod 644 "$HOME/.xinitrc" && log "Created ~/.xinitrc"
  [ ! -f "$HOME/.xsession" ] && echo -e "#!/bin/sh\nexec i3" > "$HOME/.xsession" && chmod +x "$HOME/.xsession" && log "Created ~/.xsession"
}

### -------------------------
### Parse args
### -------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --no-appearance) DO_APPEARANCE=false; shift ;;
    --no-wallpaper) DO_WALLPAPER=false; shift ;;
    --noninteractive) NONINTERACTIVE=true; shift ;;
    --help|-h) echo "Usage: $0 [--no-appearance] [--no-wallpaper] [--noninteractive]"; exit 0 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

### -------------------------
### Main
### -------------------------
log "Starting i3 starter installer"
detect_distro
log "Detected distro: $DISTRO_NAME (ID=$DISTRO_ID)"
echo "Welcome — starting i3 starter pack installation. Logfile: $LOGFILE"

start_sudo_keepalive
trap stop_sudo_keepalive EXIT

case "$DISTRO_ID" in
  debian|ubuntu|linuxmint)
    [ "$NONINTERACTIVE" = false ] && read -rp "Packages will be installed via apt. Press Enter to continue (Ctrl-C to cancel)."
    install_debian_pkgs ;;
  arch|manjaro)
    [ "$NONINTERACTIVE" = false ] && read -rp "Packages will be installed via pacman. Press Enter to continue (Ctrl-C to cancel)."
    install_arch_pkgs ;;
  *) log "Unsupported distro, skipping package installation" ;;
esac

mkdir -p "$HOME/.config"
[ -d "./i3" ] && check_source_exists "./i3" && backup_if_exists "$HOME/.config/i3" && cp -a ./i3 "$HOME/.config/" | tee -a "$LOGFILE"
[ -f "./picom.conf" ] && check_source_exists "./picom.conf" && backup_if_exists "$HOME/.config/picom.conf" && cp -v ./picom.conf "$HOME/.config/picom.conf" | tee -a "$LOGFILE"
[ -f "./i3/autostart.sh" ] && check_source_exists "./i3/autostart.sh" && mkdir -p "$HOME/.config/i3" && install -m 755 ./i3/autostart.sh "$HOME/.config/i3/autostart.sh" 2>/dev/null || { cp -v ./i3/autostart.sh "$HOME/.config/i3/autostart.sh"; chmod 755 "$HOME/.config/i3/autostart.sh"; }
[ "$DO_WALLPAPER" = true ] && [ -f "./wallpaper.jpg" ] && mkdir -p "$HOME/Pictures" && cp -v ./wallpaper.jpg "$HOME/Pictures/" | tee -a "$LOGFILE"

ensure_xsession

if [ "$DO_APPEARANCE" = true ] && command -v xfce4-appearance-settings >/dev/null 2>&1 && [ "$NONINTERACTIVE" = false ]; then
  echo "Please select: Arc-Dark (theme), Breeze (cursor), JetBrains Mono 10pt font, then close the window."
  log "Launching xfce4-appearance-settings"
  xfce4-appearance-settings
fi

echo
log "Installation finished. Summary:"
echo "  - Logfile: $LOGFILE"
echo "  - i3 config: ~/.config/i3"
echo "  - picom.conf: ~/.config/picom.conf"
echo "  - Wallpaper: ~/Pictures/wallpaper.jpg"
echo
echo "Start i3:"
echo "  - Use your display manager and select 'i3', or"
echo "  - Run: startx (uses ~/.xinitrc)"
log "Done."

exit 0
