#!/bin/sh
set -eu
base=/root/dja-backhaul
umask 077
work="$base/config-new.$$"
mkdir "$work"
trap 'rm -rf "$work"' EXIT
printf '5 GHz WPA2 SSID: '; IFS= read -r ssid
printf "WPA2 password (VISIBLE while typing): ";
IFS= read -r password
printf '\nOptional AP BSSID (Enter for SSID selection): '; IFS= read -r bssid
printf '%s' "$ssid" > "$work/ssid"
printf '%s' "$password" > "$work/password"
printf '%s' "$bssid" > "$work/bssid"
unset password
lua "$base/generate.lua" "$work" check
for name in ssid password bssid; do mv "$work/$name" "$base/$name"; done
printf 'Saved. Run /etc/init.d/dja-backhaul restart to apply.\n'
