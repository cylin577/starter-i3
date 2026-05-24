#!/bin/bash
# ~/.config/i3/autostart.sh

# Source your shell config
source ~/.bashrc

# Start system tray apps
nm-applet &
blueman-applet &
pasystray &

# Wait a moment for them to initialize
sleep 2
