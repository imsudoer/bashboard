#!/bin/bash
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -n "$LOCAL_IP" ] && field "Local IP" "$LOCAL_IP"

IFACE=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
[ -n "$IFACE" ] && field "Iface" "$IFACE"

if [ "$SHOW_EXTERNAL_IP" = "1" ]; then
    EXT_IP=$(timeout 2 curl -s ifconfig.me 2>/dev/null || timeout 2 curl -s ipinfo.io/ip 2>/dev/null)
    [ -n "$EXT_IP" ] && field "Public IP" "$EXT_IP"
fi

if command -v ss &>/dev/null; then
    CONN=$(ss -tun state established 2>/dev/null | tail -n +2 | wc -l)
    field "Conn" "${CONN} active"
fi
