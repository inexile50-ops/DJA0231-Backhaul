#!/bin/sh
set -eu

base=/root/dja-backhaul

[ "$(id -u)" = 0 ] || {
    echo "ERROR: Run as root." >&2
    exit 1
}

[ -d "$base" ] || {
    echo "ERROR: $base not found." >&2
    exit 1
}

echo "Stopping and disabling DJA0231 Wi-Fi Backhaul..."

if [ -x /etc/init.d/dja-backhaul ]; then
    /etc/init.d/dja-backhaul stop || true
    /etc/init.d/dja-backhaul disable || true
fi

if [ -f "$base/backups/dhcp" ]; then
    cp "$base/backups/dhcp" /etc/config/dhcp
    /etc/init.d/dnsmasq restart
    echo "Original LAN DHCP configuration restored."
else
    echo "WARNING: DHCP backup not found; DHCP configuration was not changed."
fi

if [ -f "$base/backups/wireless" ]; then
    cp "$base/backups/wireless" /etc/config/wireless
    /etc/init.d/hostapd reload || true
    echo "Original wireless configuration restored."
else
    echo "WARNING: Wireless backup not found; wireless configuration was not restored."
fi

uci del_list web.ruleset_main.rules="backhaulmodal" 2>/dev/null || true
uci del_list web.ruleset_main.rules="backhaulstatusajax" 2>/dev/null || true
uci del_list web.ruleset_main.rules="backhaulscanajax" 2>/dev/null || true
uci delete web.backhaulmodal 2>/dev/null || true
uci delete web.backhaulstatusajax 2>/dev/null || true
uci delete web.backhaulscanajax 2>/dev/null || true
uci commit web
/etc/init.d/nginx restart

rm -f \
    /www/cards/000_A_BackhaulDown.lp \
    /www/cards/000_B_BackhaulUp.lp \
    /www/cards/029_wifi_backhaul.lp \
    /www/docroot/ajax/backhaul-scan.lua \
    /www/docroot/ajax/backhaul-status.lua \
    /www/docroot/modals/backhaul-modal.lp \
    /etc/init.d/dja-backhaul

rm -rf /tmp/dja-backhaul

echo
echo "Backhaul service and WebUI additions removed."
echo "The directory $base has been PRESERVED because it contains backups and credentials."
echo "Reboot the DJA0231 to restore the stock wireless runtime completely."
echo "After confirming recovery, you may manually remove $base if desired."
