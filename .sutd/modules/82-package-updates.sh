#!/bin/bash

CACHE_FILE="$HOME/.sutd/data/package_updates.cache"
CACHE_TTL=3600  # секунд (= 1 час)
LIMIT="${PACKAGE_UPDATES_LIMIT:-5}"

# определяем менеджер пакетов
PKG_MGR=""
command -v apt-get &>/dev/null && PKG_MGR="apt"
command -v dnf     &>/dev/null && PKG_MGR="dnf"
command -v yum     &>/dev/null && PKG_MGR="yum"
command -v pacman  &>/dev/null && PKG_MGR="pacman"

[ -z "$PKG_MGR" ] && exit 0

need_refresh=1
if [ -f "$CACHE_FILE" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    [ "$age" -lt "$CACHE_TTL" ] && need_refresh=0
fi

if [ "$need_refresh" = "1" ]; then
    {
        case "$PKG_MGR" in
            apt)
                apt list --upgradable 2>/dev/null | tail -n +2 > "$CACHE_FILE.tmp"
                ;;
            dnf|yum)
                $PKG_MGR check-update 2>/dev/null | awk 'NF==3 && $1 ~ /^[a-zA-Z]/' > "$CACHE_FILE.tmp"
                ;;
            pacman)
                checkupdates 2>/dev/null > "$CACHE_FILE.tmp"
                ;;
        esac
        mv "$CACHE_FILE.tmp" "$CACHE_FILE" 2>/dev/null
    } &
    disown 2>/dev/null
    
    [ ! -f "$CACHE_FILE" ] && exit 0
fi

TOTAL=$(wc -l < "$CACHE_FILE" 2>/dev/null || echo 0)

divider
section "Package updates: ${COLOR_GRAY}(${PKG_MGR})${COLOR_RESET}"

if [ "$TOTAL" -eq 0 ]; then
    echo -e "    ${COLOR_GREEN}●${COLOR_RESET} system is up to date"
    
    if [ -f /var/run/reboot-required ]; then
        echo -e "    ${COLOR_RED}⚠${COLOR_RESET} reboot required"
        [ -r /var/run/reboot-required.pkgs ] && \
            echo -e "    ${COLOR_GRAY}  for: $(tr '\n' ' ' < /var/run/reboot-required.pkgs)${COLOR_RESET}"
    fi
    exit 0
fi

SEC_COUNT=0
KERNEL_COUNT=0

case "$PKG_MGR" in
    apt)
        SEC_COUNT=$(grep -cE '(-security|security\.)' "$CACHE_FILE" 2>/dev/null)
        KERNEL_COUNT=$(grep -cE '^(linux-image|linux-headers|linux-generic)' "$CACHE_FILE" 2>/dev/null)
        ;;
    dnf|yum)
        SEC_COUNT=$($PKG_MGR updateinfo list security 2>/dev/null | grep -c '^[A-Z]')
        KERNEL_COUNT=$(grep -cE '^kernel' "$CACHE_FILE" 2>/dev/null)
        ;;
    pacman)
        KERNEL_COUNT=$(grep -cE '^linux ' "$CACHE_FILE" 2>/dev/null)
        ;;
esac

color="$COLOR_YELLOW"
[ "$SEC_COUNT" -gt 0 ] && color="$COLOR_RED"

printf "    ${color}●${COLOR_RESET} ${color}%d package(s)${COLOR_RESET} available\n" "$TOTAL"

[ "$SEC_COUNT" -gt 0 ]    && echo -e "    ${COLOR_RED}⚠ ${SEC_COUNT} security update(s)${COLOR_RESET}"
[ "$KERNEL_COUNT" -gt 0 ] && echo -e "    ${COLOR_YELLOW}⚠ kernel update available — reboot will be needed${COLOR_RESET}"

echo ""
echo -e "    ${COLOR_GRAY}Notable updates:${COLOR_RESET}"

PRIORITY='^(linux|kernel|openssl|libssl|systemd|sudo|openssh|nginx|apache|postgresql|mariadb|mysql|docker|containerd|certbot|fail2ban|ufw|iptables|wget|curl|bash|python|nodejs|php)'

shown=0
grep -iE "$PRIORITY" "$CACHE_FILE" 2>/dev/null | head -n "$LIMIT" | while read line && [ "$shown" -lt "$LIMIT" ]; do
    case "$PKG_MGR" in
        apt)
            pkg=$(echo "$line" | cut -d'/' -f1)
            ver=$(echo "$line" | awk '{print $2}')
            ;;
        dnf|yum|pacman)
            pkg=$(echo "$line" | awk '{print $1}')
            ver=$(echo "$line" | awk '{print $2}')
            ;;
    esac
    
    color="$COLOR_RED"
    case "$pkg" in
        linux*|kernel*|openssl*|systemd*|sudo*|openssh*) icon="🔒" ;;
        *) icon="📦"; color="$COLOR_YELLOW" ;;
    esac
    
    printf "    ${color}▸${COLOR_RESET} %-25s ${COLOR_GRAY}%s${COLOR_RESET}\n" \
        "${pkg:0:25}" "$ver"
    shown=$((shown + 1))
done

remaining=$((TOTAL - shown))
[ "$remaining" -gt 0 ] && echo -e "    ${COLOR_GRAY}... and $remaining more (run: apt list --upgradable)${COLOR_RESET}"

# reboot required
if [ -f /var/run/reboot-required ]; then
    echo ""
    echo -e "    ${COLOR_RED}⚠ reboot required${COLOR_RESET}"
fi