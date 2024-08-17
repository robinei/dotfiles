#!/usr/bin/env sh

systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK

wl-paste -t text --watch clipman store --no-persist &
mako --background-color=#171717e0 --text-color=#ffffffe0 --border-color=#ffffffe0 --default-timeout=10000 --markup=1 --actions=1 --icons=1 &
udiskie --notify --automount --tray --appindicator --file-manager pcmanfm &
blueman-applet &
wait