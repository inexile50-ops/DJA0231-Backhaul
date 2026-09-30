#!/bin/sh
set -eu

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

echo "DJA0231 Wi-Fi Backhaul 1.1.4"
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
    /www/cards/000_A_BackhaulDown.lp \
    /www/cards/000_B_BackhaulUp.lp \
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

uci -q get wireless.wl1 >/dev/null 2>&1 ||
    fail "Stock wireless section wireless.wl1 is missing."

uci -q get wireless.ap2 >/dev/null 2>&1 ||
    fail "Stock wireless section wireless.ap2 is missing."

uci -q get wireless.wl1_2 >/dev/null 2>&1 ||
    fail "Stock wireless section wireless.wl1_2 is missing."

uci -q get wireless.ap4 >/dev/null 2>&1 ||
    fail "Stock wireless section wireless.ap4 is missing."

echo "Compatibility checks passed."

base=/root/dja-backhaul
umask 077

mkdir -p "$base/backups"
cp /etc/config/dhcp "$base/backups/dhcp"
cp /etc/config/wireless "$base/backups/wireless"
cp /etc/config/web "$base/backups/web"

# Repurpose the stock 5 GHz backhaul BSS as a normal local fronthaul AP.
primary_5g_ssid="$(uci -q get wireless.wl1.ssid || true)"
primary_5g_key="$(uci -q get wireless.ap2.wpa_psk_key || true)"

[ -n "$primary_5g_ssid" ] ||
    fail "Primary 5 GHz SSID wireless.wl1.ssid is missing."

[ -n "$primary_5g_key" ] ||
    fail "Primary 5 GHz WPA2 key wireless.ap2.wpa_psk_key is missing."

uci delete wireless.wl1_2.backhaul 2>/dev/null || true
uci set wireless.wl1_2.device='radio_5G'
uci set wireless.wl1_2.mode='ap'
uci set wireless.wl1_2.network='lan'
uci set wireless.wl1_2.reliable_multicast='0'
uci set wireless.wl1_2.fronthaul='1'
uci set wireless.wl1_2.ssid="${primary_5g_ssid}-BH"
uci set wireless.wl1_2.state='1'

uci set wireless.ap4.iface='wl1_2'
uci set wireless.ap4.state='1'
uci set wireless.ap4.public='1'
uci set wireless.ap4.ap_isolation='0'
uci set wireless.ap4.station_history='1'
uci set wireless.ap4.max_assoc='0'
uci set wireless.ap4.security_mode='wpa2-psk'
uci set wireless.ap4.pmf='enabled'
uci set wireless.ap4.pmksa_cache='1'
uci set wireless.ap4.wps_w7pbc='1'
uci set wireless.ap4.wsc_state='configured'
uci set wireless.ap4.wps_credentialformat='passphrase'
uci set wireless.ap4.wps_ap_setup_locked='1'
uci set wireless.ap4.acl_mode='unlock'
uci set wireless.ap4.acl_registration_time='60'
uci set wireless.ap4.trace_modules=' '
uci set wireless.ap4.trace_level='some'
uci set wireless.ap4.wpa_psk_key="$primary_5g_key"
uci set wireless.ap4.bandsteer_id='off'
uci set wireless.ap4.supported_security_modes='none wpa2 wpa2-psk wpa-wpa2 wpa-wpa2-psk'
uci set wireless.ap4.wps_state='0'
uci commit wireless
/etc/init.d/hostapd reload

cp -R bin "$base/"
cp generate.lua configure.sh dhcp.sh run.sh control.sh restore.sh \
   restore-webui-graphs.sh backhaul-status-monitor.lua readme.txt "$base/"

chmod 700 "$base/"*.sh "$base/bin/"*
chmod 600 "$base/"*.lua

mkdir -p /www/cards /www/docroot/ajax /www/docroot/modals
cp www/cards/000_A_BackhaulDown.lp /www/cards/
cp www/cards/000_B_BackhaulUp.lp /www/cards/
cp www/cards/029_wifi_backhaul.lp /www/cards/
cp www/docroot/ajax/backhaul-scan.lua /www/docroot/ajax/
cp www/docroot/ajax/backhaul-status.lua /www/docroot/ajax/
cp www/docroot/modals/backhaul-modal.lp /www/docroot/modals/

chmod 644 \
    /www/cards/000_A_BackhaulDown.lp \
    /www/cards/000_B_BackhaulUp.lp \
    /www/cards/029_wifi_backhaul.lp \
    /www/docroot/ajax/backhaul-scan.lua \
    /www/docroot/ajax/backhaul-status.lua \
    /www/docroot/modals/backhaul-modal.lp


tar czf "$base/webui-graphs-backup.tgz" -C / \
    www/cards/000_A_BackhaulDown.lp \
    www/cards/000_B_BackhaulUp.lp \
    www/docroot/ajax/backhaul-status.lua

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

printf 'relay-experimental\n' > "$base/client-addressing"
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
echo "Until Wi-Fi credentials are configured, the WebUI status/control monitor and graph watchdog run."
echo "The 5 GHz backhaul will not be started until credentials have been saved."
