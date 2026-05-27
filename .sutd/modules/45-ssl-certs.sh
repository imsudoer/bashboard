#!/bin/bash

WARN_DAYS="${SSL_WARN_DAYS:-14}"

CANDIDATES=(
    "$SSL_CERTS_PATH"
    "/etc/letsencrypt/live"
    "/etc/ssl/letsencrypt/live"
    "/opt/letsencrypt/live"
    "/usr/local/etc/letsencrypt/live"
    "/etc/ssl/certs"
)

CERTS_PATH=""
for path in "${CANDIDATES[@]}"; do
    [ -z "$path" ] && continue
    if [ -d "$path" ] && [ -r "$path" ]; then
        CERTS_PATH="$path"; break
    fi
    if [ -d "$path" ] && sudo -n test -r "$path" 2>/dev/null; then
        CERTS_PATH="$path"; break
    fi
done

[ -z "$CERTS_PATH" ] && exit 0

if [ -r "$CERTS_PATH" ]; then
    SUDO=""
else
    if sudo -n true 2>/dev/null; then
        SUDO="sudo -n"
    else
        section "SSL Certificates:"
        echo -e "    ${COLOR_GRAY}cannot read $CERTS_PATH (no sudo)${COLOR_RESET}"
        exit 0
    fi
fi

CERTS=$($SUDO find "$CERTS_PATH" $ -name "cert.pem" -o -name "fullchain.pem" $ 2>/dev/null | sort -u)

if [ -z "$CERTS" ]; then
    CERTS=$($SUDO find "$CERTS_PATH" -maxdepth 3 -name "*.pem" 2>/dev/null | sort -u)
fi

[ -z "$CERTS" ] && exit 0

section "SSL Certificates: ${COLOR_GRAY}(${CERTS_PATH})${COLOR_RESET}"

NOW_EPOCH=$(date +%s)
declare -A SEEN

while IFS= read -r cert; do
    [ -z "$cert" ] && continue
    
    DOMAIN=$(basename "$(dirname "$cert")")
    [ "$DOMAIN" = "live" ] || [ "$DOMAIN" = "certs" ] && DOMAIN=$(basename "$cert" .pem)
    
    [ -n "${SEEN[$DOMAIN]}" ] && continue
    SEEN[$DOMAIN]=1
    
    END_DATE=$($SUDO openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
    [ -z "$END_DATE" ] && continue
    
    END_EPOCH=$(date -d "$END_DATE" +%s 2>/dev/null)
    [ -z "$END_EPOCH" ] && continue
    
    DAYS_LEFT=$(( (END_EPOCH - NOW_EPOCH) / 86400 ))
    
    if [ "$DAYS_LEFT" -lt 0 ]; then
        COLOR="$COLOR_RED"; ICON="✗"; STATUS="EXPIRED ${DAYS_LEFT#-}d ago"
    elif [ "$DAYS_LEFT" -lt "$WARN_DAYS" ]; then
        COLOR="$COLOR_YELLOW"; ICON="⚠"; STATUS="${DAYS_LEFT}d left"
    else
        COLOR="$COLOR_GREEN"; ICON="●"; STATUS="${DAYS_LEFT}d left"
    fi
    
    printf "    ${COLOR}${ICON}${COLOR_RESET} %-30s ${COLOR_GRAY}%s${COLOR_RESET}\n" "$DOMAIN" "$STATUS"
done <<< "$CERTS"