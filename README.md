# DJA0231 Backhaul

Wi-Fi backhaul for a rooted **Technicolor DJA0231 / VCNT-A** using the router's onboard Broadcom 5 GHz radio.

The package creates `wl1_3` as a station interface, connects it to a WPA2-Personal AES/CCMP access point, obtains an upstream IPv4 address, and relays IPv4 traffic between `wl1_3` and `br-lan`.

It also adds a **Wi-Fi Backhaul** card to the Technicolor WebUI with status, scanning, connection controls and Wi-Fi configuration.

> This is an IPv4 pseudo-bridge, not a transparent Ethernet bridge.

## Tested platform

Release **v1.1.3** has been tested on:

- Technicolor DJA0231
- Hardware: VCNT-A
- Firmware family: `20.3.c.0389-MR20-RA`
- OpenWrt target: `brcm6xxx-tch/VBNTJ_502L07p1`
- Architecture: `arm_cortex-a9`
- Kernel: `4.1.52 / ARMv7`

The installer checks the target and deliberately refuses unsupported boards or kernels.

**Root access is required.**

## Important network requirements

- The DJA0231 LAN management address and the upstream network must be in the same IPv4 `/24` subnet.
- The DJA0231 management address must be unique.
- The installer does not automatically renumber the router.
- Downstream devices should currently use unique static IPv4 addresses.
- Avoid addresses that collide with the upstream DHCP pool or other devices.
- The parent 5 GHz radio is repurposed for backhaul while this is running, so ordinary 5 GHz AP service from that radio should not be expected.

## Installation

Download the latest release from:

https://github.com/inexile50-ops/DJA0231-Backhaul/releases/latest

Copy the installer to the rooted router:

```sh
scp dja0231-backhaul-1.1.3.run root@ROUTER-IP:/tmp/
```

SSH into the DJA0231:

```sh
ssh root@ROUTER-IP
```

Run the installer:

```sh
sh /tmp/dja0231-backhaul-1.1.3.run
```

The installer:

- verifies the supported board, architecture, target and kernel
- verifies required router commands
- refuses to overwrite an existing installation
- backs up `/etc/config/dhcp`, `/etc/config/wireless` and `/etc/config/web`
- installs the backhaul runtime
- installs the Technicolor WebUI additions
- enables the supervised boot service
- starts only the status/control monitor while unconfigured

Installing the package alone does **not** disable LAN DHCP and does **not** activate the 5 GHz backhaul.

## Configuration

After installation, open the Technicolor WebUI and select the **Wi-Fi Backhaul** card.

Scan for a 5 GHz network or enter:

- SSID
- WPA2 password

Passwords accepted by the WebUI are currently 8-63 characters.

Configuration can also be performed over SSH:

```sh
/root/dja-backhaul/configure.sh
```

Credentials are stored in root-only files under `/root/dja-backhaul`.

After saving credentials, restart the service:

```sh
/etc/init.d/dja-backhaul restart
```

## Safe DHCP handover

LAN DHCP is not disabled simply because credentials were entered.

Before changing LAN DHCP, the runtime requires:

1. successful WPA association
2. successful upstream DHCP
3. confirmation that the upstream address and the DJA0231 LAN management address are in the same `/24`

Only after those checks succeed does the runtime disable LAN DHCP and restart `dnsmasq`.

A wrong password or failed upstream connection therefore does not intentionally disable the DJA0231 LAN DHCP server.

## Status and diagnostics

Useful SSH commands:

```sh
/root/dja-backhaul/bin/wpa_cli -p /tmp/dja-backhaul/ctrl -i wl1_3 status
wl -i wl1_3 sta_info <AP-BSSID>
cat /tmp/dja-backhaul/lease.ip
cat /tmp/dja-backhaul/gateway
```

Logs:

```text
/tmp/dja-backhaul/wpa.log
/tmp/dja-backhaul/dhcp.log
/tmp/dja-backhaul/relay.log
```

A `wpa_state=COMPLETED` result by itself is not proof of working end-to-end traffic.

## Optional DHCP relay

The supported/default downstream mode is static addressing.

An experimental DHCP relay mode is available:

```sh
printf 'relay-experimental\n' > /root/dja-backhaul/client-addressing
/etc/init.d/dja-backhaul restart
```

Return to the default static mode with:

```sh
printf 'static\n' > /root/dja-backhaul/client-addressing
/etc/init.d/dja-backhaul restart
```

DHCP relay behaviour has not been validated sufficiently for use as the default.

## Recovery / removal

A recovery helper is installed at:

```sh
/root/dja-backhaul/restore.sh
```

Run:

```sh
/root/dja-backhaul/restore.sh
```

It stops and disables the backhaul service, restores the backed-up DHCP configuration when available, restarts `dnsmasq`, removes the WebUI additions and removes the init script.

The `/root/dja-backhaul` directory is intentionally preserved because it contains configuration backups and may contain Wi-Fi credentials.

**Reboot after running `restore.sh`** to return the wireless runtime fully to its normal boot state.

Once recovery has been verified, `/root/dja-backhaul` can be removed manually if desired.

Backups are stored under:

```text
/root/dja-backhaul/backups/dhcp
/root/dja-backhaul/backups/wireless
/root/dja-backhaul/backups/web
```

These backups can contain private configuration data. Do not publish them.

## Limitations

This release does not provide:

- IPv6 bridging
- WPA3
- WPA/WPA2 Enterprise
- WDS, DWDS or WET
- arbitrary Ethernet protocol bridging

It does not flash firmware or modify firmware partitions.

This project has been developed and field-tested on a specific DJA0231 firmware build. Different Technicolor firmware revisions can contain different Broadcom drivers, WebUI components or system behaviour.

Upstream AP configuration, DFS/channel policy, Broadcom ABI differences and stock Wi-Fi reload behaviour can affect operation.

Keep a recovery method available when experimenting with rooted firmware.

## Release integrity

SHA-256 checksums are provided with the release for corruption/integrity checking. They are not a digital signature.

Current release:

**v1.1.3**  
https://github.com/inexile50-ops/DJA0231-Backhaul/releases/tag/v1.1.3

## Source and licences

The binary package includes `wpa_supplicant` and `relayd` components built from open-source software.

When redistributing the binary release, also make the corresponding source archive and applicable licence files available.
