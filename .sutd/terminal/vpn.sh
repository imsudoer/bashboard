#!/bin/bash

# :helpme:
# title: OpenVPN Manager
# desc: Manage clients, view stats, kick users, watch traffic
# category: network
# usage:
#   vpn                       overview of all connections
#   vpn clients               detailed client list
#   vpn special               only special tagged clients
#   vpn watch                 live updating session view
#   vpn traffic <name>        traffic stats for specific client
#   vpn kick <name>           disconnect a client
#   vpn add <name>            create new client certificate
#   vpn rm <name>             revoke client certificate
#   vpn list                  list all configured clients
#   vpn logs                  tail openvpn log with highlighting
#   vpn restart               restart openvpn service
#   vpn status                systemctl status
#   vpn config <name>         export .ovpn file for client
#   vpn -h                    this help
# examples:
#   vpn
#   vpn watch
#   vpn add laptop-john
#   vpn config laptop-john > laptop.ovpn
#   vpn kick "OnlySq Promo"
# :endhelpme:

__VPN_STATUS_LOG="${OPENVPN_STATUS_LOG:-/var/log/openvpn/openvpn-status.log}"
__VPN_SERVER_LOG="${OPENVPN_SERVER_LOG:-/var/log/openvpn/openvpn.log}"
__VPN_DIR="${OPENVPN_DIR:-/etc/openvpn/server}"
__VPN_CLIENTS_DIR="${OPENVPN_CLIENTS_DIR:-/etc/openvpn/clients}"
__VPN_EASYRSA="${OPENVPN_EASYRSA_DIR:-/etc/openvpn/easy-rsa}"
__VPN_SERVICE="${OPENVPN_SERVICE:-openvpn-server@server}"
__VPN_SPECIAL="${OPENVPN_SPECIAL_CLIENTS:-OnlySq Promo|10.8.0.2,OnlySq Nash|10.8.0.3}"

vpn() {
    local cmd="$1"
    shift
    
    case "$cmd" in
        ""|overview|status-short)   __vpn_overview ;;
        clients|list-active)        __vpn_clients ;;
        special)                    __vpn_special ;;
        watch)                      __vpn_watch ;;
        traffic)                    __vpn_traffic "$@" ;;
        kick|disconnect)            __vpn_kick "$@" ;;
        add|create)                 __vpn_add "$@" ;;
        rm|revoke|remove)           __vpn_rm "$@" ;;
        list|all)                   __vpn_list ;;
        logs|log)                   __vpn_logs "$@" ;;
        restart)                    __vpn_restart ;;
        start)                      sudo systemctl start "$__VPN_SERVICE" ;;
        stop)                       sudo systemctl stop "$__VPN_SERVICE" ;;
        status)                     systemctl status "$__VPN_SERVICE" --no-pager ;;
        config|export|ovpn)         __vpn_config "$@" ;;
        ban|block)                  __vpn_ban "$@" ;;
        -h|--help)
            cat << 'EOF'
  vpn — OpenVPN management

  vpn                       quick overview
  vpn clients               list active connections (detailed)
  vpn special               only special tagged peers
  vpn watch                 live updating view (Ctrl+C to exit)
  vpn traffic <name>        traffic for specific client
  vpn kick <name>           disconnect client
  vpn add <name>            create new client cert
  vpn rm <name>             revoke client cert
  vpn list                  all configured clients (active + offline)
  vpn config <name>         export .ovpn config file
  vpn logs [-e]             tail log (-e for errors only)
  vpn restart               restart service
  vpn start|stop|status     service control
  vpn ban <ip|name>         block client by IP
EOF
            ;;
        *)
            echo "  unknown: $cmd"
            vpn -h
            ;;
    esac
}

__vpn_check_log() {
    if [ ! -r "$__VPN_STATUS_LOG" ]; then
        echo -e "  \033[31m✗\033[0m cannot read status log: $__VPN_STATUS_LOG"
        echo -e "  \033[90m  set OPENVPN_STATUS_LOG in info.conf or run as root\033[0m"
        return 1
    fi
    return 0
}

__vpn_parse_clients() {
    __vpn_check_log || return 1
    
    if grep -q "^CLIENT_LIST" "$__VPN_STATUS_LOG" 2>/dev/null; then
        grep "^CLIENT_LIST" "$__VPN_STATUS_LOG" | while IFS=',' read -r tag name realaddr vaddr v6 rxb txb since since_t username cid peerid cipher; do
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$vaddr" "$realaddr" "$rxb" "$txb" "$since"
        done
    else
        awk '
        /^OpenVPN CLIENT LIST/,/^ROUTING TABLE/ {
            if ($0 ~ /^[^,]+,[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+,[0-9]+,[0-9]+,/) {
                split($0, a, ",")
                cn=a[1]; raddr=a[2]; rxb=a[3]; txb=a[4]; since=a[5]
                clients[cn] = raddr "|" rxb "|" txb "|" since
            }
        }
        /^ROUTING TABLE/,/^GLOBAL STATS/ {
            if ($0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+,[^,]+,/) {
                split($0, a, ",")
                vaddr=a[1]; cn=a[2]
                if (cn in clients) {
                    split(clients[cn], parts, "|")
                    print cn "\t" vaddr "\t" parts[1] "\t" parts[2] "\t" parts[3] "\t" parts[4]
                }
            }
        }
        ' "$__VPN_STATUS_LOG"
    fi
}

__vpn_format_bytes() {
    awk -v b="$1" 'BEGIN{
        if (b>=1073741824) printf "%.2fGB", b/1073741824
        else if (b>=1048576) printf "%.1fMB", b/1048576
        else if (b>=1024) printf "%.0fKB", b/1024
        else printf "%dB", b
    }'
}

__vpn_format_duration() {
    local since="$1"
    local epoch
    
    if [[ "$since" =~ ^[0-9]+$ ]]; then
        epoch="$since"
    else
        epoch=$(date -d "$since" +%s 2>/dev/null)
    fi
    
    [ -z "$epoch" ] || [ "$epoch" -le 0 ] && { echo "?"; return; }
    
    local now=$(date +%s)
    local diff=$((now - epoch))
    
    local d=$((diff / 86400))
    local h=$(((diff % 86400) / 3600))
    local m=$(((diff % 3600) / 60))
    
    if [ "$d" -gt 0 ]; then echo "${d}d ${h}h"
    elif [ "$h" -gt 0 ]; then echo "${h}h ${m}m"
    else echo "${m}m"
    fi
}

__vpn_is_special() {
    local ip="$1"
    IFS=',' read -ra arr <<< "$__VPN_SPECIAL"
    for entry in "${arr[@]}"; do
        [ "${entry#*|}" = "$ip" ] && return 0
    done
    return 1
}

__vpn_special_name() {
    local ip="$1"
    IFS=',' read -ra arr <<< "$__VPN_SPECIAL"
    for entry in "${arr[@]}"; do
        if [ "${entry#*|}" = "$ip" ]; then
            echo "${entry%|*}"
            return
        fi
    done
    echo "?"
}

__vpn_overview() {
    local state=$(systemctl is-active "$__VPN_SERVICE" 2>/dev/null)
    
    case "$state" in
        active)   icon="\033[32m●\033[0m"; lbl="running" ;;
        inactive) icon="\033[31m●\033[0m"; lbl="stopped" ;;
        *)        icon="\033[33m●\033[0m"; lbl="$state" ;;
    esac
    
    echo -e "  \033[37mOpenVPN service:\033[0m ${icon} ${lbl}"
    
    [ "$state" != "active" ] && return
    
    __vpn_check_log || return
    
    local clients_data
    clients_data=$(__vpn_parse_clients)
    
    if [ -z "$clients_data" ]; then
        echo "  no clients connected"
        return
    fi
    
    local total=$(echo "$clients_data" | wc -l)
    
    echo -e "  \033[37mConnected:\033[0m $total"
    echo ""
    
    local total_rx=0 total_tx=0
    
    echo "$clients_data" | while IFS=$'\t' read -r name vaddr realaddr rxb txb since; do
        local realip="${realaddr%:*}"
        local rx_h=$(__vpn_format_bytes "$rxb")
        local tx_h=$(__vpn_format_bytes "$txb")
        local up=$(__vpn_format_duration "$since")
        
        if __vpn_is_special "$vaddr"; then
            local sname=$(__vpn_special_name "$vaddr")
            printf "  \033[38;5;208m★\033[0m %-22s \033[90m%-15s\033[0m %-18s \033[90m%s\033[0m \033[32m↓%s\033[0m \033[33m↑%s\033[0m\n" \
                "$sname" "$vaddr" "$realip" "$up" "$rx_h" "$tx_h"
        else
            printf "  \033[32m●\033[0m %-22s \033[90m%-15s\033[0m %-18s \033[90m%s\033[0m \033[32m↓%s\033[0m \033[33m↑%s\033[0m\n" \
                "${name:0:22}" "$vaddr" "$realip" "$up" "$rx_h" "$tx_h"
        fi
    done
}

__vpn_clients() {
    __vpn_check_log || return
    
    local clients_data
    clients_data=$(__vpn_parse_clients)
    
    if [ -z "$clients_data" ]; then
        echo "  no clients connected"
        return
    fi
    
    echo "$clients_data" | while IFS=$'\t' read -r name vaddr realaddr rxb txb since; do
        local realip="${realaddr%:*}"
        local realport="${realaddr#*:}"
        local rx_h=$(__vpn_format_bytes "$rxb")
        local tx_h=$(__vpn_format_bytes "$txb")
        local up=$(__vpn_format_duration "$since")
        
        local mark="\033[32m●\033[0m"
        local display_name="$name"
        
        if __vpn_is_special "$vaddr"; then
            mark="\033[38;5;208m★\033[0m"
            display_name=$(__vpn_special_name "$vaddr")
        fi
        
        echo ""
        echo -e "  ${mark} \033[1m${display_name}\033[0m"
        printf "    \033[90mvpn ip:\033[0m   %s\n" "$vaddr"
        printf "    \033[90mreal ip:\033[0m  %s:%s\n" "$realip" "$realport"
        printf "    \033[90muptime:\033[0m   %s\n" "$up"
        printf "    \033[90mrx:\033[0m       \033[32m%s\033[0m\n" "$rx_h"
        printf "    \033[90mtx:\033[0m       \033[33m%s\033[0m\n" "$tx_h"
        
        if [ "$name" != "$display_name" ]; then
            printf "    \033[90mcert cn:\033[0m  %s\n" "$name"
        fi
    done
}

__vpn_special() {
    __vpn_check_log || return
    
    echo -e "  \033[37mSpecial peers:\033[0m"
    echo ""
    
    local clients_data
    clients_data=$(__vpn_parse_clients)
    
    IFS=',' read -ra arr <<< "$__VPN_SPECIAL"
    for entry in "${arr[@]}"; do
        local sname="${entry%|*}"
        local sip="${entry#*|}"
        
        local line=$(echo "$clients_data" | awk -v ip="$sip" -F'\t' '$2==ip')
        
        if [ -n "$line" ]; then
            local name=$(echo "$line" | cut -f1)
            local realaddr=$(echo "$line" | cut -f3)
            local rxb=$(echo "$line" | cut -f4)
            local txb=$(echo "$line" | cut -f5)
            local since=$(echo "$line" | cut -f6)
            
            local realip="${realaddr%:*}"
            local rx_h=$(__vpn_format_bytes "$rxb")
            local tx_h=$(__vpn_format_bytes "$txb")
            local up=$(__vpn_format_duration "$since")
            
            echo -e "  \033[38;5;208m★\033[0m \033[1m${sname}\033[0m \033[32m(online)\033[0m"
            printf "    \033[90mip:\033[0m       %s\n" "$sip"
            printf "    \033[90mfrom:\033[0m     %s\n" "$realip"
            printf "    \033[90muptime:\033[0m   %s\n" "$up"
            printf "    \033[90mtraffic:\033[0m  \033[32m↓ %s\033[0m  \033[33m↑ %s\033[0m\n" "$rx_h" "$tx_h"
        else
            echo -e "  \033[31m○\033[0m \033[1m${sname}\033[0m \033[31m(offline)\033[0m"
            printf "    \033[90mip:\033[0m       %s\n" "$sip"
        fi
        echo ""
    done
}

__vpn_watch() {
    if [ ! -t 1 ]; then
        echo "  watch requires a terminal"
        return 1
    fi
    
    trap 'tput cnorm; echo ""; return 0' EXIT INT TERM
    tput civis
    
    while true; do
        clear
        echo -e "  \033[38;5;208m▸ OpenVPN live monitor\033[0m \033[90m(Ctrl+C to exit, refresh every 3s)\033[0m"
        echo ""
        __vpn_overview
        sleep 3
    done
}

__vpn_traffic() {
    local query="$1"
    [ -z "$query" ] && { echo "  usage: vpn traffic <name|ip>"; return 1; }
    
    __vpn_check_log || return
    
    local clients_data
    clients_data=$(__vpn_parse_clients)
    
    local match=$(echo "$clients_data" | awk -F'\t' -v q="$query" '$1==q || $2==q')
    
    if [ -z "$match" ]; then
        match=$(echo "$clients_data" | awk -F'\t' -v q="$query" 'tolower($1) ~ tolower(q)' | head -1)
    fi
    
    if [ -z "$match" ]; then
        IFS=',' read -ra arr <<< "$__VPN_SPECIAL"
        for entry in "${arr[@]}"; do
            local sname="${entry%|*}"
            local sip="${entry#*|}"
            if [ "$sname" = "$query" ]; then
                match=$(echo "$clients_data" | awk -F'\t' -v ip="$sip" '$2==ip')
                break
            fi
        done
    fi
    
    if [ -z "$match" ]; then
        echo "  no client matches: $query"
        return 1
    fi
    
    local name=$(echo "$match" | cut -f1)
    local vaddr=$(echo "$match" | cut -f2)
    local realaddr=$(echo "$match" | cut -f3)
    local rxb=$(echo "$match" | cut -f4)
    local txb=$(echo "$match" | cut -f5)
    local since=$(echo "$match" | cut -f6)
    
    local rx_h=$(__vpn_format_bytes "$rxb")
    local tx_h=$(__vpn_format_bytes "$txb")
    local up=$(__vpn_format_duration "$since")
    
    local total_b=$((rxb + txb))
    local total_h=$(__vpn_format_bytes "$total_b")
    
    local since_epoch
    if [[ "$since" =~ ^[0-9]+$ ]]; then
        since_epoch="$since"
    else
        since_epoch=$(date -d "$since" +%s 2>/dev/null)
    fi
    
    local avg_rate=""
    if [ -n "$since_epoch" ] && [ "$since_epoch" -gt 0 ]; then
        local now=$(date +%s)
        local sec=$((now - since_epoch))
        if [ "$sec" -gt 0 ]; then
            local rate=$((total_b / sec))
            avg_rate=$(__vpn_format_bytes "$rate")"/s"
        fi
    fi
    
    echo -e "  \033[38;5;208m▸ Traffic for ${name}\033[0m"
    printf "    \033[90mvpn ip:\033[0m   %s\n" "$vaddr"
    printf "    \033[90mreal:\033[0m     %s\n" "${realaddr%:*}"
    printf "    \033[90muptime:\033[0m   %s\n" "$up"
    echo ""
    printf "    \033[37mRX:\033[0m       \033[32m%s\033[0m\n" "$rx_h"
    printf "    \033[37mTX:\033[0m       \033[33m%s\033[0m\n" "$tx_h"
    printf "    \033[37mTotal:\033[0m    \033[38;5;208m%s\033[0m\n" "$total_h"
    [ -n "$avg_rate" ] && printf "    \033[37mAvg rate:\033[0m %s\n" "$avg_rate"
}

__vpn_kick() {
    local query="$1"
    [ -z "$query" ] && { echo "  usage: vpn kick <name>"; return 1; }
    
    local mgmt_port="${OPENVPN_MGMT_PORT:-7505}"
    local mgmt_host="${OPENVPN_MGMT_HOST:-127.0.0.1}"
    
    if ! timeout 1 bash -c "cat < /dev/null > /dev/tcp/$mgmt_host/$mgmt_port" 2>/dev/null; then
        echo -e "  \033[31m✗\033[0m management interface not reachable on $mgmt_host:$mgmt_port"
        echo -e "  \033[90m  enable in server.conf: management 127.0.0.1 7505\033[0m"
        return 1
    fi
    
    local real_name="$query"
    
    if __vpn_check_log; then
        IFS=',' read -ra arr <<< "$__VPN_SPECIAL"
        for entry in "${arr[@]}"; do
            local sname="${entry%|*}"
            local sip="${entry#*|}"
            if [ "$sname" = "$query" ]; then
                local clients_data=$(__vpn_parse_clients)
                local cn=$(echo "$clients_data" | awk -F'\t' -v ip="$sip" '$2==ip {print $1}')
                [ -n "$cn" ] && real_name="$cn"
                break
            fi
        done
    fi
    
    echo -e "  \033[31m⚠\033[0m About to kick: \033[1m${real_name}\033[0m"
    read -p "  Confirm? [y/N]: " ans
    [[ ! "$ans" =~ ^[yY]$ ]] && { echo "  cancelled"; return; }
    
    local result
    result=$(echo -e "kill ${real_name}\nquit" | timeout 3 nc "$mgmt_host" "$mgmt_port" 2>/dev/null)
    
    if echo "$result" | grep -q "SUCCESS"; then
        echo -e "  \033[32m✓\033[0m disconnected: $real_name"
    elif echo "$result" | grep -q "ERROR"; then
        echo -e "  \033[31m✗\033[0m failed: $(echo "$result" | grep ERROR | head -1)"
    else
        echo -e "  \033[33m⚠\033[0m unclear response: $result"
    fi
}

__vpn_add() {
    local name="$1"
    [ -z "$name" ] && { echo "  usage: vpn add <client-name>"; return 1; }
    
    if [ ! -d "$__VPN_EASYRSA" ]; then
        echo -e "  \033[31m✗\033[0m easy-rsa dir not found: $__VPN_EASYRSA"
        echo "  set OPENVPN_EASYRSA_DIR in info.conf"
        return 1
    fi
    
    if [ -f "$__VPN_EASYRSA/pki/issued/${name}.crt" ]; then
        echo -e "  \033[33m⚠\033[0m client '$name' already exists"
        return 1
    fi
    
    cd "$__VPN_EASYRSA" || return 1
    
    echo -e "  \033[90m→\033[0m generating cert for $name..."
    
    if ! sudo ./easyrsa --batch build-client-full "$name" nopass 2>&1 | tail -3; then
        echo -e "  \033[31m✗\033[0m generation failed"
        return 1
    fi
    
    echo -e "  \033[32m✓\033[0m client cert created: $name"
    echo -e "  \033[90m  files in: $__VPN_EASYRSA/pki/\033[0m"
    echo ""
    echo -e "  \033[90mNext: vpn config $name > ${name}.ovpn\033[0m"
}

__vpn_rm() {
    local name="$1"
    [ -z "$name" ] && { echo "  usage: vpn rm <client-name>"; return 1; }
    
    if [ ! -d "$__VPN_EASYRSA" ]; then
        echo -e "  \033[31m✗\033[0m easy-rsa dir not found"
        return 1
    fi
    
    if [ ! -f "$__VPN_EASYRSA/pki/issued/${name}.crt" ]; then
        echo -e "  \033[33m⚠\033[0m client '$name' not found"
        return 1
    fi
    
    echo -e "  \033[31m⚠\033[0m About to revoke client: \033[1m${name}\033[0m"
    read -p "  Type 'yes' to confirm: " ans
    [ "$ans" != "yes" ] && { echo "  cancelled"; return; }
    
    cd "$__VPN_EASYRSA" || return 1
    
    sudo ./easyrsa --batch revoke "$name" 2>&1 | tail -3
    sudo ./easyrsa --batch gen-crl 2>&1 | tail -2
    
    local crl_dst="$__VPN_DIR/crl.pem"
    if [ -f "$__VPN_EASYRSA/pki/crl.pem" ]; then
        sudo cp "$__VPN_EASYRSA/pki/crl.pem" "$crl_dst"
        sudo chown nobody:nogroup "$crl_dst" 2>/dev/null || sudo chmod 644 "$crl_dst"
    fi
    
    echo -e "  \033[32m✓\033[0m revoked: $name"
    echo -e "  \033[90m  restart openvpn for CRL to take effect: vpn restart\033[0m"
}

__vpn_list() {
    if [ ! -d "$__VPN_EASYRSA/pki/issued" ]; then
        echo "  no easy-rsa setup found"
        return 1
    fi
    
    echo -e "  \033[37mAll configured clients:\033[0m"
    echo ""
    
    local active_data=""
    if __vpn_check_log 2>/dev/null; then
        active_data=$(__vpn_parse_clients)
    fi
    
    local revoked_list=""
    [ -f "$__VPN_EASYRSA/pki/index.txt" ] && \
        revoked_list=$(awk '/^R/ {print $NF}' "$__VPN_EASYRSA/pki/index.txt" | sed 's|.*/CN=||')
    
    for cert in "$__VPN_EASYRSA"/pki/issued/*.crt; do
        [ -f "$cert" ] || continue
        local cname=$(basename "$cert" .crt)
        [ "$cname" = "server" ] && continue
        
        local revoked=0
        echo "$revoked_list" | grep -q "^${cname}$" && revoked=1
        
        local is_active=""
        if [ -n "$active_data" ]; then
            is_active=$(echo "$active_data" | awk -F'\t' -v n="$cname" '$1==n {print $2}')
        fi
        
        local icon color note=""
        if [ "$revoked" = "1" ]; then
            icon="✗"; color="\033[31m"; note=" (revoked)"
        elif [ -n "$is_active" ]; then
            icon="●"; color="\033[32m"; note=" — $is_active"
        else
            icon="○"; color="\033[90m"; note=" (offline)"
        fi
        
        printf "  ${color}${icon}\033[0m %-25s\033[90m%s\033[0m\n" "$cname" "$note"
    done
}

__vpn_logs() {
    local error_only=0
    [ "$1" = "-e" ] || [ "$1" = "--errors" ] && error_only=1
    
    local log="$__VPN_SERVER_LOG"
    [ -r "$log" ] || log="/var/log/syslog"
    
    if [ ! -r "$log" ]; then
        echo "  cannot read openvpn log"
        return 1
    fi
    
    echo -e "  \033[90m→\033[0m tail $log"
    echo -e "  \033[90m  Ctrl+C to stop\033[0m"
    
    if [ "$error_only" = "1" ]; then
        sudo tail -F "$log" 2>/dev/null | grep --line-buffered -iE "error|fail|warn|denied"
    else
        sudo tail -F "$log" 2>/dev/null | awk '
            /error|ERROR|fail|FAIL/  { print "\033[31m" $0 "\033[0m"; next }
            /warn|WARN/              { print "\033[33m" $0 "\033[0m"; next }
            /SUCCESS|established|Initialization Sequence Completed/ { print "\033[32m" $0 "\033[0m"; next }
            { print }
        '
    fi
}

__vpn_restart() {
    echo -e "  \033[90m→\033[0m restarting $__VPN_SERVICE"
    sudo systemctl restart "$__VPN_SERVICE"
    sleep 1
    local state=$(systemctl is-active "$__VPN_SERVICE")
    if [ "$state" = "active" ]; then
        echo -e "  \033[32m✓\033[0m restarted, service active"
    else
        echo -e "  \033[31m✗\033[0m service state: $state"
        echo -e "  \033[90m  check: vpn status\033[0m"
    fi
}

__vpn_config() {
    local name="$1"
    [ -z "$name" ] && { echo "  usage: vpn config <name>" >&2; return 1; }
    
    local ca="$__VPN_EASYRSA/pki/ca.crt"
    local cert="$__VPN_EASYRSA/pki/issued/${name}.crt"
    local key="$__VPN_EASYRSA/pki/private/${name}.key"
    local tls_auth="$__VPN_DIR/ta.key"
    
    [ ! -f "$ca" ]   && { echo "  ca.crt not found: $ca" >&2; return 1; }
    [ ! -f "$cert" ] && { echo "  cert not found: $cert" >&2; return 1; }
    [ ! -f "$key" ]  && { echo "  key not found: $key" >&2; return 1; }
    
    local pub_ip
    pub_ip=$(timeout 2 curl -s ifconfig.me 2>/dev/null)
    [ -z "$pub_ip" ] && pub_ip="YOUR_SERVER_IP"
    
    local proto="udp"
    local port="1194"
    
    if [ -f "$__VPN_DIR/server.conf" ]; then
        local conf_proto=$(awk '/^proto / {print $2}' "$__VPN_DIR/server.conf" | head -1)
        local conf_port=$(awk '/^port / {print $2}' "$__VPN_DIR/server.conf" | head -1)
        [ -n "$conf_proto" ] && proto="$conf_proto"
        [ -n "$conf_port" ] && port="$conf_port"
    fi
    
    cat << EOF
client
dev tun
proto ${proto}
remote ${pub_ip} ${port}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
verb 3

<ca>
$(sudo cat "$ca")
</ca>

<cert>
$(sudo cat "$cert" | awk '/^-----BEGIN/,/^-----END/')
</cert>

<key>
$(sudo cat "$key")
</key>
EOF
    
    if [ -f "$tls_auth" ]; then
        echo "key-direction 1"
        echo "<tls-auth>"
        sudo cat "$tls_auth"
        echo "</tls-auth>"
    fi
}

__vpn_ban() {
    local target="$1"
    [ -z "$target" ] && { echo "  usage: vpn ban <ip>"; return 1; }
    
    if ! command -v iptables &>/dev/null; then
        echo "  iptables not available"
        return 1
    fi
    
    if [[ ! "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if __vpn_check_log; then
            local clients_data=$(__vpn_parse_clients)
            local found_ip=$(echo "$clients_data" | awk -F'\t' -v q="$target" '$1==q {print $3}' | head -1)
            [ -n "$found_ip" ] && target="${found_ip%:*}"
        fi
    fi
    
    echo -e "  \033[31m⚠\033[0m About to ban IP: \033[1m${target}\033[0m"
    read -p "  Confirm? [y/N]: " ans
    [[ ! "$ans" =~ ^[yY]$ ]] && { echo "  cancelled"; return; }
    
    sudo iptables -I INPUT -s "$target" -j DROP
    echo -e "  \033[32m✓\033[0m banned: $target"
    echo -e "  \033[90m  unban: sudo iptables -D INPUT -s $target -j DROP\033[0m"
}

_vpn_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    case "$prev" in
        vpn)
            COMPREPLY=( $(compgen -W "clients special watch traffic kick add rm list logs restart start stop status config ban -h" -- "$cur") )
            ;;
        kick|traffic|config|rm)
            local names=""
            if [ -d "$__VPN_EASYRSA/pki/issued" ]; then
                names=$(ls "$__VPN_EASYRSA/pki/issued/" 2>/dev/null | grep '\.crt$' | sed 's/\.crt$//' | grep -v '^server$')
            fi
            COMPREPLY=( $(compgen -W "$names" -- "$cur") )
            ;;
    esac
}
complete -F _vpn_complete vpn