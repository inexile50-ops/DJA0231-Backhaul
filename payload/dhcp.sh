#!/bin/sh
set -eu
case "$1" in bound|renew)
[ "$interface" = wl1_3 ] || exit 1
[ "$subnet" = 255.255.255.0 ] || { echo 'Only /24 upstream supported'; exit 1; }
case "$ip" in *[!0-9.]*|'') exit 1;; esac
set -- $router
gateway=${1:-}
case "$gateway" in *[!0-9.]*|'') exit 1;; esac
# Require LAN management and upstream to share a /24; never renumber LAN automatically.
lan=$(ip -4 addr show br-lan | awk '/inet / {split($2,a,"/");print a[1];exit}')
[ "${lan%.*}" = "${ip%.*}" ] || { echo 'LAN and upstream subnets differ'; exit 1; }
ip addr replace "$ip/24" dev wl1_3
printf '%s\n' "$ip" > /tmp/dja-backhaul/lease.ip
printf '%s\n' "$gateway" > /tmp/dja-backhaul/gateway
;; esac
