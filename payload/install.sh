#!/bin/sh
set -eu

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

echo "DJA0231 Wi-Fi Backhaul 1.1.3"
echo "Pre-flight compatibility checks..."

[ "$(id -u)" = 0 ] ||
    fail "Run this installer as root on the DJA0231."

case "$(uname -m)" in
    armv7*) ;;
    *) fail "Requires ARMv7; found $(uname -m)." ;;
esac

[ "$(uname -r)" = "4.1.52" ] ||
    fail "Unsupported kernel $(uname -r); this release was tested on 4.1.52."

[ -d /etc/boards/VCNT-A ] ||
    fail "VCNT-A board files not found."

[ -r /etc/openwrt_release ] ||
    fail "/etc/openwrt_release is missing."

. /etc/openwrt_release

[ "${DISTRIB_TARGET:-}" = "brcm6xxx-tch/VBNTJ_502L07p1" ] ||
    fail "Unsupported OpenWrt target: ${DISTRIB_TARGET:-unknown}."

[ "${DISTRIB_ARCH:-}" = "arm_cortex-a9" ] ||
    fail "Unsupported OpenWrt architecture: ${DISTRIB_ARCH:-unknown}."

for tool in wl odhcpc lua uci ip iptables brctl sha256sum; do
    command -v "$tool" >/dev/null 2>&1 ||
        fail "Required command '$tool' is missing."
done

wl -i wl1 ver >/dev/null 2>&1 ||
    fail "Broadcom 5 GHz interface wl1 is unavailable."

[ ! -e /root/dja-backhaul ] ||
    fail "/root/dja-backhaul already exists; refusing to overwrite an existing installation."

[ ! -e /etc/init.d/dja-backhaul ] ||
    fail "/etc/init.d/dja-backhaul already exists; refusing to overwrite it."

[ ! -e /etc/init.d/hallway-backhaul ] ||
    fail "Legacy hallway-backhaul service exists; migrate/remove it before installing."

for path in \
    /www/cards/029_wifi_backhaul.lp \
    /www/docroot/ajax/backhaul-scan.lua \
    /www/docroot/ajax/backhaul-status.lua \
    /www/docroot/modals/backhaul-modal.lp
do
    [ ! -e "$path" ] ||
        fail "$path already exists; refusing to overwrite WebUI content."
done

for section in backhaulmodal backhaulstatusajax backhaulscanajax; do
    ! uci -q get "web.$section" >/dev/null 2>&1 ||
        fail "WebUI UCI section web.$section already exists; refusing to overwrite it."
done

echo "Compatibility checks passed."

base=/root/dja-backhaul
umask 077

mkdir -p "$base/backups"
cp /etc/config/dhcp "$base/backups/dhcp"
cp /etc/config/wireless "$base/backups/wireless"
cp /etc/config/web "$base/backups/web"

cp -R bin "$base/"
cp generate.lua configure.sh dhcp.sh run.sh control.sh restore.sh \
   backhaul-status-monitor.lua readme.txt "$base/"

chmod 700 "$base/"*.sh "$base/bin/"*
chmod 600 "$base/"*.lua

mkdir -p /www/cards /www/docroot/ajax /www/docroot/modals
cp www/cards/029_wifi_backhaul.lp /www/cards/
cp www/docroot/ajax/backhaul-scan.lua /www/docroot/ajax/
cp www/docroot/ajax/backhaul-status.lua /www/docroot/ajax/
cp www/docroot/modals/backhaul-modal.lp /www/docroot/modals/

chmod 644 \
    /www/cards/029_wifi_backhaul.lp \
    /www/docroot/ajax/backhaul-scan.lua \
    /www/docroot/ajax/backhaul-status.lua \
    /www/docroot/modals/backhaul-modal.lp

uci set web.backhaulmodal=rule
uci set web.backhaulmodal.target="/modals/backhaul-modal.lp"
uci add_list web.backhaulmodal.roles="admin"
uci set web.backhaulstatusajax=rule
uci set web.backhaulstatusajax.target="/ajax/backhaul-status.lua"
uci set web.backhaulstatusajax.normally_hidden="1"
uci add_list web.backhaulstatusajax.roles="admin"
uci set web.backhaulscanajax=rule
uci set web.backhaulscanajax.target="/ajax/backhaul-scan.lua"
uci set web.backhaulscanajax.normally_hidden="1"
uci add_list web.backhaulscanajax.roles="admin"
uci add_list web.ruleset_main.rules="backhaulmodal"
uci add_list web.ruleset_main.rules="backhaulstatusajax"
uci add_list web.ruleset_main.rules="backhaulscanajax"
uci commit web
/etc/init.d/nginx restart

cp dja-backhaul.init /etc/init.d/dja-backhaul
chmod 755 /etc/init.d/dja-backhaul

printf 'static\n' > "$base/client-addressing"
mkdir -p /tmp/dja-backhaul/web-control
chmod 711 /tmp/dja-backhaul
chmod 733 /tmp/dja-backhaul/web-control
/etc/init.d/dja-backhaul enable
/etc/init.d/dja-backhaul start

echo
echo "Base installation complete."
echo "Configure the upstream Wi-Fi from the Wi-Fi Backhaul card in the WebUI,"
echo "or run /root/dja-backhaul/configure.sh from SSH."
echo
echo "LAN DHCP has NOT been disabled."
echo "The backhaul service is enabled for boot."
echo "Until Wi-Fi credentials are configured, only the WebUI status/control monitor runs."
echo "The 5 GHz backhaul will not be started until credentials have been saved."
