#!/bin/sh
set -eu
base=/root/dja-backhaul
run=/tmp/dja-backhaul
umask 077
mkdir -p "$run"
chmod 711 "$run"
mkdir -p "$run/web-control"
chmod 733 "$run/web-control"
wpa_pid= dhcp_pid= relay_pid=
cleanup() {
 trap - EXIT TERM INT
 for child in "$relay_pid" "$dhcp_pid" "$wpa_pid"; do [ -z "$child" ] || kill "$child" 2>/dev/null || true; done
 wait 2>/dev/null || true
 iptables -D FORWARD -i br-lan -o wl1_3 -j ACCEPT 2>/dev/null || true
 iptables -D FORWARD -i wl1_3 -o br-lan -j ACCEPT 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT
[ -s "$base/ssid" ] && [ -s "$base/password" ] || exit 0
n=0
until ip link show wl1 >/dev/null 2>&1 && ip link show br-lan >/dev/null 2>&1; do sleep 2; n=$((n+1)); [ "$n" -lt 90 ] || exit 1; done
sleep 10
lua "$base/generate.lua"
brctl delif br-lan wl1 2>/dev/null || true
if ! ip link show wl1_3 >/dev/null 2>&1; then
 wl -i wl1 ap 0
 wl -i wl1 infra 1
 wl -i wl1 interface_create sta
fi
brctl delif br-lan wl1_3 2>/dev/null || true
ip link set wl1_3 up
"$base/bin/wpa_supplicant" -Dbrcm_private -i wl1_3 -c "$run/client.conf" > "$run/wpa.log" 2>&1 &
wpa_pid=$!
n=0
until "$base/bin/wpa_cli" -p "$run/ctrl" -i wl1_3 status 2>/dev/null | grep -q wpa_state=COMPLETED; do kill -0 "$wpa_pid";sleep 2;n=$((n+1));[ "$n" -lt 90 ] || exit 1;done
rm -f "$run/lease.ip" "$run/gateway"
odhcpc -f -i wl1_3 -t 3 -T 3 -s "$base/dhcp.sh" -p "$run/dhcp.pid" > "$run/dhcp.log" 2>&1 &
dhcp_pid=$!
n=0
until [ -s "$run/gateway" ]; do kill -0 "$dhcp_pid";sleep 2;n=$((n+1));[ "$n" -lt 60 ] || exit 1;done
gateway=$(cat "$run/gateway")
if [ "$(uci -q get dhcp.lan.ignore || true)" != "1" ] || [ "$(uci -q get dhcp.lan.dhcpv4 || true)" != "disabled" ]; then
 uci set dhcp.lan.ignore=1
 uci set dhcp.lan.dhcpv4=disabled
 uci commit dhcp
 /etc/init.d/dnsmasq restart
fi
lan=$(ip -4 addr show br-lan | awk '/inet / {split($2,a,"/");print a[1];exit}')
iptables -I FORWARD 1 -i br-lan -o wl1_3 -j ACCEPT
iptables -I FORWARD 1 -i wl1_3 -o br-lan -j ACCEPT
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/conf/br-lan/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/wl1_3/send_redirects
set -- -I br-lan -I wl1_3 -B -G "$gateway" -L "$lan"
[ "$(cat "$base/client-addressing")" != relay-experimental ] || set -- "$@" -D
"$base/bin/relayd" "$@" > "$run/relay.log" 2>&1 &
relay_pid=$!
while kill -0 "$wpa_pid" && kill -0 "$dhcp_pid" && kill -0 "$relay_pid"; do
 sleep 10
 [ "$(cat "$run/gateway")" = "$gateway" ] || exit 1
 # Reinstall forwarding rules if a stock firewall reload removed them.
 iptables -C FORWARD -i br-lan -o wl1_3 -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -i br-lan -o wl1_3 -j ACCEPT
 iptables -C FORWARD -i wl1_3 -o br-lan -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -i wl1_3 -o br-lan -j ACCEPT
done
exit 1
