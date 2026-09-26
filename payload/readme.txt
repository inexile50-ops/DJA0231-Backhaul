DJA0231 BROADCOM 5 GHz WI-FI BACKHAUL — 1.1.3
=================================================

OVERVIEW

This package adds a Wi-Fi backhaul client to a rooted Technicolor DJA0231 /
VCNT-A using the router's onboard Broadcom 5 GHz radio.

It creates wl1_3 as a station interface, authenticates to a WPA2-Personal
AES/CCMP access point using a custom wpa_supplicant Broadcom private-ioctl
backend, obtains an upstream IPv4 address, and relays IPv4 traffic between
wl1_3 and br-lan.

A Wi-Fi Backhaul card is added to the Technicolor WebUI. It provides status,
network scanning, connection controls and Wi-Fi configuration.

This is an IPv4 pseudo-bridge, NOT a transparent Ethernet bridge.

It does NOT provide:
- IPv6 bridging
- WPA3
- WPA/WPA2 Enterprise
- WDS, DWDS or WET
- arbitrary Ethernet protocol bridging

It does not flash firmware or modify firmware partitions.


TESTED PLATFORM

This release has been tested on:

  Technicolor DJA0231
  Hardware: VCNT-A
  Firmware family: 20.3.c.0389-MR20-RA
  OpenWrt target: brcm6xxx-tch/VBNTJ_502L07p1
  Architecture: arm_cortex-a9
  Kernel: 4.1.52 / ARMv7

The installer deliberately refuses unsupported targets and kernels.

Root access is required.


IMPORTANT NETWORK REQUIREMENTS

The DJA0231 LAN management address and the upstream network must be in the
same IPv4 /24 subnet.

The installer does NOT automatically renumber the DJA0231.

The DJA0231 management address must be unique.

ALL downstream devices connected through this DJA0231 must currently use UNIQUE STATIC IPv4 addresses. Automatic DHCP addressing for downstream clients is not supported in the default mode. Choose
addresses that will not collide with the upstream DHCP pool or other devices.

Do not assign the same address to multiple clients.

The parent 5 GHz radio is repurposed for the backhaul station. Do not expect
ordinary 5 GHz AP service from that radio while the backhaul is operating.


INSTALLATION

Copy the .run installer to /tmp on the rooted DJA0231 and execute it as root.

Example:

  scp dja0231-backhaul-1.1.3.run root@ROUTER-IP:/tmp/
  ssh root@ROUTER-IP
  sh /tmp/dja0231-backhaul-1.1.3.run

The installer:

- verifies the supported board, architecture, target and kernel
- verifies required router commands
- refuses to overwrite an existing installation
- backs up /etc/config/dhcp, /etc/config/wireless and /etc/config/web
- installs the backhaul runtime
- installs the Technicolor WebUI additions
- enables the supervised boot service
- starts only the status/control monitor while unconfigured

Installing the package alone does NOT disable LAN DHCP and does NOT activate
the 5 GHz backhaul.


CONFIGURATION

After installation, open the Technicolor WebUI and select the Wi-Fi Backhaul
card.

Scan for a 5 GHz network or enter:

  SSID
  WPA2 password

Passwords currently accepted by the WebUI are 8-63 characters.

Configuration can also be performed from SSH with:

  /root/dja-backhaul/configure.sh

Credentials are stored in root-only files under /root/dja-backhaul.

After credentials are saved, the service restarts and attempts the connection.


SAFE DHCP HANDOVER

LAN DHCP is NOT disabled merely because credentials were entered.

The runtime first requires:

1. successful WPA association
2. successful upstream DHCP
3. confirmation that the upstream address and LAN management address share
   the same /24 subnet

Only after those checks succeed does the runtime set:

  dhcp.lan.ignore=1
  dhcp.lan.dhcpv4=disabled

and restart dnsmasq.

A wrong password or failed upstream connection therefore does not intentionally
disable the DJA0231 LAN DHCP server.


STATUS AND DIAGNOSTICS

WebUI status displays connection state, SSID, BSSID, RSSI, link rate, channel,
channel width and connection uptime.

Useful SSH commands:

  /root/dja-backhaul/bin/wpa_cli -p /tmp/dja-backhaul/ctrl -i wl1_3 status
  wl -i wl1_3 sta_info <AP-BSSID>
  cat /tmp/dja-backhaul/lease.ip
  cat /tmp/dja-backhaul/gateway

Logs:

  /tmp/dja-backhaul/wpa.log
  /tmp/dja-backhaul/dhcp.log
  /tmp/dja-backhaul/relay.log

wpa_state=COMPLETED by itself should not be treated as proof of working
end-to-end traffic.


OPTIONAL DHCP RELAY — EXPERIMENTAL

The supported/default downstream mode is static addressing.

An experimental DHCP relay mode can be selected with:

  printf 'relay-experimental\n' > /root/dja-backhaul/client-addressing
  /etc/init.d/dja-backhaul restart

Return to the default with:

  printf 'static\n' > /root/dja-backhaul/client-addressing
  /etc/init.d/dja-backhaul restart

DHCP relay behaviour has not been validated sufficiently for use as the default mode.


RECOVERY / REMOVE

A recovery helper is installed at:

  /root/dja-backhaul/restore.sh

Run:

  /root/dja-backhaul/restore.sh

It:

- stops and disables the backhaul service
- restores the original backed-up DHCP configuration when available
- restarts dnsmasq
- removes the installed WebUI files and their access-control rules
- removes the dja-backhaul init script
- preserves /root/dja-backhaul

The directory is deliberately preserved because it contains configuration
backups and may contain Wi-Fi credentials.

Reboot after running restore.sh to return the wireless runtime fully to its
normal boot state.

After recovery has been verified, /root/dja-backhaul may be manually removed
if desired.

Backups are stored in:

  /root/dja-backhaul/backups/dhcp
  /root/dja-backhaul/backups/wireless
  /root/dja-backhaul/backups/web

These backups can contain private configuration data. Do not publish them.


LIMITATIONS

Same-subnet IPv4 /24 operation only.

The package has been developed and field-tested on a specific DJA0231 firmware
build. Different Technicolor firmware revisions may contain different Broadcom
drivers, WebUI components or system behaviour.

Upstream AP configuration, DFS/channel policy, Broadcom ABI differences and
stock Wi-Fi reload behaviour can affect operation.

Keep a recovery method available when experimenting with rooted firmware.


SOURCES / LICENSES

The binary package includes wpa_supplicant and relayd components built from
open-source software.

When redistributing the binary release, also make the corresponding source
archive and applicable licence files available.

SHA256 checksums are provided for corruption/integrity checking. They are not
a digital signature.
