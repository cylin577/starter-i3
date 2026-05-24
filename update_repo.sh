#!/usr/bin/env bash
set -euo pipefail

# Configuration
TARGET_HOME="${HOME}"
PROJECT_DIR="$(pwd)"
CONFIG_DIR="${TARGET_HOME}/.config"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

sync_item() {
    local src="$1"
    local dest="$2"
    if [ -e "$src" ]; then
        log "Syncing $src -> $dest"
        cp -a "$src" "$dest"
    else
        log "WARNING: Source $src not found, skipping."
    fi
}

# Sync back configurations
sync_item "${CONFIG_DIR}/i3" "${PROJECT_DIR}/"
sync_item "${CONFIG_DIR}/polybar" "${PROJECT_DIR}/"
sync_item "${CONFIG_DIR}/picom.conf" "${PROJECT_DIR}/picom.conf"
sync_item "${TARGET_HOME}/Pictures/wallpaper.jpg" "${PROJECT_DIR}/wallpaper.jpg"

# Recreate the archive
log "Recreating configs.tar.gz..."
tar -czf configs.tar.gz i3 polybar picom.conf

log "Project updated from local configurations."
