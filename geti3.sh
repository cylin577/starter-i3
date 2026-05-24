#!/usr/bin/env bash
set -euo pipefail

### -------------------------
### Configuration / Defaults
### -------------------------
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
LOGFILE="${TARGET_HOME}/.starter-i3-$(date +%Y%m%d%H%M%S).log"
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
KEEP_SUDO_PID=""
NONINTERACTIVE=false
DO_APPEARANCE=true
DO_WALLPAPER=true

# Global variables
AVAILABLE_PMS=()

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
  polybar
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
  polybar
)

### -------------------------
### Helpers
### -------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"; }
err() { echo "ERROR: $*" >&2; log "ERROR: $*"; exit 1; }

detect_package_manager() {
  AVAILABLE_PMS=()
  declare -g AVAILABLE_PMS
  command -v apt >/dev/null 2>&1 && AVAILABLE_PMS+=("apt") || true
  command -v pacman >/dev/null 2>&1 && AVAILABLE_PMS+=("pacman") || true
}

check_source_exists() { [ -e "$1" ] || err "Required file/directory not found: $1"; }
backup_if_exists() { [ -e "$1" ] && mv -v "$1" "$1.backup.$BACKUP_SUFFIX" | tee -a "$LOGFILE"; }

start_sudo_keepalive() {
  log "Skipping sudo keepalive (background processes forbidden)"
}
stop_sudo_keepalive() {
  :
}

install_debian_pkgs() { sudo apt update | tee -a "$LOGFILE"; sudo apt install -y "${PKGS_DEBIAN[@]}" | tee -a "$LOGFILE"; }
install_arch_pkgs() { sudo pacman -Syu --noconfirm | tee -a "$LOGFILE"; sudo pacman -S --noconfirm "${PKGS_ARCH[@]}" | tee -a "$LOGFILE"; }

ensure_xsession() {
  [ ! -f "$TARGET_HOME/.xinitrc" ] && echo -e "exec i3" > "$TARGET_HOME/.xinitrc" && chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.xinitrc" && chmod 644 "$TARGET_HOME/.xinitrc" && log "Created ~/.xinitrc"
  [ ! -f "$TARGET_HOME/.xsession" ] && echo -e "#!/bin/sh\nexec i3" > "$TARGET_HOME/.xsession" && chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.xsession" && chmod +x "$TARGET_HOME/.xsession" && log "Created ~/.xsession"
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
log "Starting i3 installer for $TARGET_USER"
echo "starter-i3 installation Logfile: $LOGFILE"

start_sudo_keepalive
trap stop_sudo_keepalive EXIT

detect_package_manager
log "Available package managers: ${AVAILABLE_PMS[@]}"

if [ ${#AVAILABLE_PMS[@]} -eq 0 ]; then
  log "No supported package manager found. Skipping package installation."
elif [ ${#AVAILABLE_PMS[@]} -eq 1 ]; then
  CHOSEN_PM="${AVAILABLE_PMS[0]}"
else
  echo "Multiple package managers found. Please choose one:"
  select pm in "${AVAILABLE_PMS[@]}"; do
    if [[ -n "$pm" ]]; then
      CHOSEN_PM="$pm"
      break
    else
      echo "Invalid selection. Please try again."
    fi
  done
fi

if [ -n "${CHOSEN_PM:-}" ]; then
  log "Using package manager: $CHOSEN_PM"
  if [ "$CHOSEN_PM" = "apt" ]; then
    [ "$NONINTERACTIVE" = false ] && read -rp "Packages will be installed via apt. Press Enter to continue (Ctrl-C to cancel)."
    install_debian_pkgs
  elif [ "$CHOSEN_PM" = "pacman" ]; then
    [ "$NONINTERACTIVE" = false ] && read -rp "Packages will be installed via pacman. Press Enter to continue (Ctrl-C to cancel)."
    install_arch_pkgs
  fi
fi

mkdir -p "$TARGET_HOME/.config"

if [ -f "./configs.tar.gz" ]; then
  log "Extracting configuration archive..."
  # Backup existing configs before extracting
  for dir in i3 polybar; do
    backup_if_exists "$TARGET_HOME/.config/$dir"
  done
  backup_if_exists "$TARGET_HOME/.config/picom.conf"

  tar -xzf ./configs.tar.gz -C "$TARGET_HOME/.config/" | tee -a "$LOGFILE"
  chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/i3" "$TARGET_HOME/.config/polybar" "$TARGET_HOME/.config/picom.conf"
  chmod +x "$TARGET_HOME/.config/i3/autostart.sh" "$TARGET_HOME/.config/polybar/launch.sh"
  log "Configurations extracted and permissions set."
else
  err "configs.tar.gz not found. Please ensure the archive exists."
fi
[ "$DO_WALLPAPER" = true ] && [ -f "./wallpaper.jpg" ] && mkdir -p "$TARGET_HOME/Pictures" && cp -v ./wallpaper.jpg "$TARGET_HOME/Pictures/" | tee -a "$LOGFILE" && chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/Pictures/wallpaper.jpg"

ensure_xsession

if [ "$DO_APPEARANCE" = true ] && command -v xfce4-appearance-settings >/dev/null 2>&1 && [ "$NONINTERACTIVE" = false ]; then
  echo "Please select: Arc-Dark (theme), Breeze (cursor), JetBrains Mono 10pt font, then close the window."
  log "Launching xfce4-appearance-settings"
  xfce4-appearance-settings
fi

echo
log "Installation finished. Summary:"
echo "  - Logfile: $LOGFILE"
echo "  - i3 config: $TARGET_HOME/.config/i3"
echo "  - picom.conf: $TARGET_HOME/.config/picom.conf"
echo "  - polybar config: $TARGET_HOME/.config/polybar"
echo "  - Wallpaper: $TARGET_HOME/Pictures/wallpaper.jpg"
echo
echo "Start i3:"
echo "  - Use your display manager and select 'i3', or"
echo "  - Run: startx (uses ~/.xinitrc)"
log "Done."

exit 0