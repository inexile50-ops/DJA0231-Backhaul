#!/bin/sh

ARCHIVE="/root/dja-backhaul/webui-graphs-backup.tgz"

sleep 20

while true; do
  if [ ! -s /www/cards/000_A_BackhaulDown.lp ] || \
     [ ! -s /www/cards/000_B_BackhaulUp.lp ] || \
     [ ! -s /www/docroot/ajax/backhaul-status.lua ]; then
    [ -s "$ARCHIVE" ] && tar xzf "$ARCHIVE" -C /
  fi

  sleep 10
done
