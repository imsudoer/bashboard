#!/bin/bash

STATUS_LOG="${OPENVPN_STATUS_LOG:-/var/log/openvpn/openvpn-status.log}"
SERVER_LOG="${OPENVPN_SERVER_LOG:-/var/log/openvpn/openvpn.log}"
SPECIAL_CLIENTS="${OPENVPN_SPECIAL_CLIENTS:-OnlySq Promo|10.8.0.2,OnlySq Nash|10.8.0.3}"

[ ! -r "$STATUS_LOG" ] && exit 0

divider
section "OpenVPN:"

svc_state=$(systemctl is-active openvpn-server@server 2>/dev/null)
[ "$svc_state" = "active" ] || svc_state=$(systemctl is-active openvpn@server 2>/dev/null)
[ "$svc_state" = "active" ] || svc_state=$(systemctl is-active openvpn 2>/dev/null)

case "$svc_state" in
    active)   icon="${COLOR_GREEN}●${COLOR_RESET}"; status_text="running" ;;
    inactive) icon="${COLOR_RED}●${COLOR_RESET}"; status_text="stopped" ;;
    failed)   icon="${COLOR_RED}✗${COLOR_RESET}"; status_text="failed" ;;
    *)        icon="${COLOR_GRAY}○${COLOR_RESET}"; status_text="unknown" ;;
esac

field "Service" "${icon} ${status_text}"

vpn_iface="${OPENVPN_IFACE:-tun0}"
if [ -d "/sys/class/net/$vpn_iface" ]; then
    field "Interface" "${vpn_iface} ${COLOR_GREEN}up${COLOR_RESET}"
    
    rx=$(cat /sys/class/net/$vpn_iface/statistics/rx_bytes 2>/dev/null)
    tx=$(cat /sys/class/net/$vpn_iface/statistics/tx_bytes 2>/dev/null)
    
    if [ -n "$rx" ] && [ -n "$tx" ]; then
        rx_h=$(awk -v b="$rx" 'BEGIN{
            if (b>1073741824) printf "%.2f GB", b/1073741824
            else if (b>1048576) printf "%.1f MB", b/1048576
            else printf "%.0f KB", b/1024
        }')
        tx_h=$(awk -v b="$tx" 'BEGIN{
            if (b>1073741824) printf "%.2f GB", b/1073741824
            else if (b>1048576) printf "%.1f MB", b/1048576
            else printf "%.0f KB", b/1024
        }')
        field "Total RX" "${rx_h}"
        field "Total TX" "${tx_h}"
    fi
else
    field "Interface" "${COLOR_RED}down${COLOR_RESET}"
fi

declare -A special_by_ip
declare -A special_name_by_ip
IFS=',' read -ra specials <<< "$SPECIAL_CLIENTS"
for entry in "${specials[@]}"; do
    name="${entry%|*}"
    ip="${entry#*|}"
    special_by_ip["$ip"]=1
    special_name_by_ip["$ip"]="$name"
done

if grep -q "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null; then
    format="v2"
elif grep -q "^OpenVPN CLIENT LIST" "$STATUS_LOG" 2>/dev/null; then
    format="v1"
else
    field "Clients" "${COLOR_GRAY}(cannot parse status log)${COLOR_RESET}"
    exit 0
fi

tmp_clients=$(mktemp)
trap "rm -f $tmp_clients" EXIT

if [ "$format" = "v2" ]; then
    grep "^CLIENT_LIST" "$STATUS_LOG" | while IFS=',' read -r tag name realaddr vaddr v6 rxb txb since since_t username cid peerid cipher; do
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$vaddr" "$realaddr" "$rxb" "$txb" "$since"
    done > "$tmp_clients"
else
    awk '
    /^OpenVPN CLIENT LIST/,/^ROUTING TABLE/ {
        if ($0 ~ /^[^,]+,[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+,[0-9]+,[0-9]+,/) {
            split($0, a, ",")
            print a[1] "\t-\t" a[2] "\t" a[3] "\t" a[4] "\t" a[5]
        }
    }
    /^ROUTING TABLE/,/^GLOBAL STATS/ {
        if ($0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+,[^,]+,/) {
            split($0, a, ",")
            print "ROUTE\t" a[1] "\t" a[2]
        }
    }
    ' "$STATUS_LOG" > "$tmp_clients"
fi

total_clients=$(grep -v "^ROUTE" "$tmp_clients" | wc -l)

if [ "$total_clients" -eq 0 ]; then
    field "Clients" "${COLOR_GRAY}none connected${COLOR_RESET}"
    exit 0
fi

field "Clients" "${total_clients} connected"

special_count=0
regular_count=0

while IFS=$'\t' read -r name vaddr realaddr rxb txb since; do
    [ "$name" = "ROUTE" ] && continue
    if [ -n "${special_by_ip[$vaddr]}" ]; then
        special_count=$((special_count + 1))
    else
        regular_count=$((regular_count + 1))
    fi
done < "$tmp_clients"

echo ""
echo -e "  ${COLOR_WHITE}Special clients:${COLOR_RESET}"

found_any_special=0
for ip in "${!special_by_ip[@]}"; do
    name="${special_name_by_ip[$ip]}"
    
    found_line=""
    while IFS=$'\t' read -r line_name line_vaddr line_realaddr line_rxb line_txb line_since; do
        [ "$line_name" = "ROUTE" ] && continue
        if [ "$line_vaddr" = "$ip" ]; then
            found_line="$line_name|$line_realaddr|$line_rxb|$line_txb|$line_since"
            break
        fi
    done < "$tmp_clients"
    
    if [ -n "$found_line" ]; then
        found_any_special=1
        IFS='|' read -r c_name c_realaddr c_rxb c_txb c_since <<< "$found_line"
        
        c_realip="${c_realaddr%:*}"
        
        rx_h=$(awk -v b="$c_rxb" 'BEGIN{
            if (b>1073741824) printf "%.2f GB", b/1073741824
            else if (b>1048576) printf "%.1f MB", b/1048576
            else printf "%.0f KB", b/1024
        }')
        tx_h=$(awk -v b="$c_txb" 'BEGIN{
            if (b>1073741824) printf "%.2f GB", b/1073741824
            else if (b>1048576) printf "%.1f MB", b/1048576
            else printf "%.0f KB", b/1024
        }')
        
        if [[ "$c_since" =~ ^[0-9]+$ ]]; then
            since_epoch="$c_since"
        else
            since_epoch=$(date -d "$c_since" +%s 2>/dev/null)
        fi
        
        if [ -n "$since_epoch" ] && [ "$since_epoch" -gt 0 ]; then
            now_epoch=$(date +%s)
            up_sec=$((now_epoch - since_epoch))
            d=$((up_sec/86400))
            h=$(((up_sec%86400)/3600))
            m=$(((up_sec%3600)/60))
            
            if [ "$d" -gt 0 ]; then up="${d}d ${h}h"
            elif [ "$h" -gt 0 ]; then up="${h}h ${m}m"
            else up="${m}m"; fi
        else
            up="?"
        fi
        
        printf "    ${COLOR_GREEN}●${COLOR_RESET} %-18s ${COLOR_GRAY}%-15s${COLOR_RESET}\n" "$name" "$ip"
        printf "      ${COLOR_GRAY}from:${COLOR_RESET} %-20s ${COLOR_GRAY}up:${COLOR_RESET} %s\n" "$c_realip" "$up"
        printf "      ${COLOR_GRAY}rx:${COLOR_RESET} ${COLOR_GREEN}↓ %-10s${COLOR_RESET} ${COLOR_GRAY}tx:${COLOR_RESET} ${COLOR_YELLOW}↑ %s${COLOR_RESET}\n" "$rx_h" "$tx_h"
    else
        printf "    ${COLOR_RED}○${COLOR_RESET} %-18s ${COLOR_GRAY}%-15s offline${COLOR_RESET}\n" "$name" "$ip"
    fi
done

if [ "$regular_count" -gt 0 ]; then
    echo ""
    echo -e "  ${COLOR_WHITE}Other clients: ${COLOR_GRAY}(${regular_count})${COLOR_RESET}"
    
    shown=0
    while IFS=$'\t' read -r name vaddr realaddr rxb txb since; do
        [ "$name" = "ROUTE" ] && continue
        [ -n "${special_by_ip[$vaddr]}" ] && continue
        [ "$shown" -ge 5 ] && break
        
        realip="${realaddr%:*}"
        
        rx_h=$(awk -v b="$rxb" 'BEGIN{
            if (b>1048576) printf "%.0fM", b/1048576
            else printf "%.0fK", b/1024
        }')
        tx_h=$(awk -v b="$txb" 'BEGIN{
            if (b>1048576) printf "%.0fM", b/1048576
            else printf "%.0fK", b/1024
        }')
        
        printf "    ${COLOR_BLUE}▸${COLOR_RESET} %-20s ${COLOR_GRAY}%-15s %-18s${COLOR_RESET} ${COLOR_GREEN}↓%s${COLOR_RESET} ${COLOR_YELLOW}↑%s${COLOR_RESET}\n" \
            "${name:0:20}" "$vaddr" "$realip" "$rx_h" "$tx_h"
        shown=$((shown + 1))
    done < "$tmp_clients"
    
    [ "$regular_count" -gt 5 ] && echo -e "    ${COLOR_GRAY}... and $((regular_count - 5)) more${COLOR_RESET}"
fi