#!/bin/sh
case "${1:-}" in
  disconnect)
    exec ubus call service delete '{"name":"dja-backhaul","instance":"backhaul"}'
    ;;
  connect)
    exec /etc/init.d/dja-backhaul start
    ;;
  *)
    echo "Usage: $0 {connect|disconnect}" >&2
    exit 2
    ;;
esac
