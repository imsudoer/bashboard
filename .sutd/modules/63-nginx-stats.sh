#!/bin/bash

LOG_FILES_DEFAULT="/var/log/nginx/access.log"
LOG_FILES="${NGINX_STATS_LOGS:-$LOG_FILES_DEFAULT}"
PERIOD_MIN="${NGINX_STATS_PERIOD_MIN:-60}"
TOP_URLS="${NGINX_STATS_TOP_URLS:-5}"
TOP_IPS="${NGINX_STATS_TOP_IPS:-3}"

found_log=""
for f in $LOG_FILES; do
    [ -r "$f" ] && { found_log="$f"; break; }
done

[ -z "$found_log" ] && exit 0

divider
section "Nginx stats: ${COLOR_GRAY}(last ${PERIOD_MIN}m)${COLOR_RESET}"

CUTOFF_EPOCH=$(date -d "${PERIOD_MIN} minutes ago" +%s 2>/dev/null)
[ -z "$CUTOFF_EPOCH" ] && exit 0

TMP=$(mktemp)
trap "rm -f $TMP" EXIT

awk -v cutoff="$CUTOFF_EPOCH" '
{
    # extract timestamp from [05/May/2026:14:23:45 +0000]
    match($0, /$$([0-9]{2})\/([A-Za-z]{3})\/([0-9]{4}):([0-9]{2}):([0-9]{2}):([0-9]{2})/, t)
    if (t[0] == "") next
    
    months["Jan"]="01"; months["Feb"]="02"; months["Mar"]="03"; months["Apr"]="04"
    months["May"]="05"; months["Jun"]="06"; months["Jul"]="07"; months["Aug"]="08"
    months["Sep"]="09"; months["Oct"]="10"; months["Nov"]="11"; months["Dec"]="12"
    
    ts_str = t[3]"-"months[t[2]]"-"t[1]" "t[4]":"t[5]":"t[6]
    
    # convert via gawk mktime
    ts_epoch = mktime(t[3]" "months[t[2]]" "t[1]" "t[4]" "t[5]" "t[6])
    if (ts_epoch < cutoff) next
    
    print $0
}
' "$found_log" > "$TMP"

TOTAL=$(wc -l < "$TMP")

if [ "$TOTAL" -eq 0 ]; then
    echo -e "    ${COLOR_GRAY}no requests in last ${PERIOD_MIN}m${COLOR_RESET}"
    exit 0
fi

printf "    ${COLOR_WHITE}Requests:${COLOR_RESET} %s ${COLOR_GRAY}(%.1f/min)${COLOR_RESET}\n" \
    "$TOTAL" "$(awk -v t="$TOTAL" -v m="$PERIOD_MIN" 'BEGIN{printf "%.1f", t/m}')"

echo ""
echo -e "    ${COLOR_GRAY}Status codes:${COLOR_RESET}"

awk '
{
    # standard combined log: ... "GET /path HTTP/1.1" 200 ...
    match($0, /"[A-Z]+ [^"]*" ([0-9]{3})/, m)
    if (m[1] != "") code[m[1]]++
}
END {
    for (c in code) print code[c], c
}
' "$TMP" | sort -rn | while read count code; do
    pct=$(awk -v c="$count" -v t="$TOTAL" 'BEGIN{printf "%.0f", c*100/t}')
    
    case "${code:0:1}" in
        2) color="$COLOR_GREEN" ;;
        3) color="$COLOR_BLUE" ;;
        4) color="$COLOR_YELLOW" ;;
        5) color="$COLOR_RED" ;;
        *) color="$COLOR_GRAY" ;;
    esac
    
    bar_w=20
    filled=$(( pct * bar_w / 100 ))
    [ "$filled" -gt "$bar_w" ] && filled=$bar_w
    empty=$(( bar_w - filled ))
    
    bar=""
    [ "$filled" -gt 0 ] && bar="$(printf '█%.0s' $(seq 1 $filled))"
    
    empty_bar=""
    [ "$empty" -gt 0 ] && empty_bar="$(printf '░%.0s' $(seq 1 $empty))"
    
    printf "    ${color}%s${COLOR_RESET} ${color}%s${COLOR_RESET}${COLOR_GRAY}%s${COLOR_RESET} %4d%% ${COLOR_GRAY}(%s)${COLOR_RESET}\n" \
        "$code" "$bar" "$empty_bar" "$pct" "$count"
done

ERRORS_5XX=$(awk 'match($0, /" 5[0-9]{2} /) {c++} END {print c+0}' "$TMP")
if [ "$ERRORS_5XX" -gt 0 ]; then
    err_pct=$(awk -v e="$ERRORS_5XX" -v t="$TOTAL" 'BEGIN{printf "%.1f", e*100/t}')
    echo ""
    echo -e "    ${COLOR_RED}⚠ ${ERRORS_5XX} server errors (5xx) — ${err_pct}%${COLOR_RESET}"
fi

echo ""
echo -e "    ${COLOR_GRAY}Top URLs:${COLOR_RESET}"

awk '
{
    match($0, /"[A-Z]+ ([^ ?"]*)/, m)
    if (m[1] != "") urls[m[1]]++
}
END {
    for (u in urls) print urls[u], u
}
' "$TMP" | sort -rn | head -n "$TOP_URLS" | while read count url; do
    url_short="${url:0:48}"
    [ "${#url}" -gt 48 ] && url_short="${url_short}..."
    printf "    ${COLOR_BLUE}▸${COLOR_RESET} %-51s ${COLOR_GRAY}%s${COLOR_RESET}\n" \
        "$url_short" "$count"
done

echo ""
echo -e "    ${COLOR_GRAY}Top IPs:${COLOR_RESET}"

awk '{print $1}' "$TMP" | sort | uniq -c | sort -rn | head -n "$TOP_IPS" | while read count ip; do
    printf "    ${COLOR_PURPLE}▸${COLOR_RESET} %-20s ${COLOR_GRAY}%s${COLOR_RESET}\n" \
        "$ip" "$count"
done

echo ""
methods_line=$(awk '
{
    match($0, /"([A-Z]+) /, m)
    if (m[1] != "") methods[m[1]]++
}
END {
    out = ""
    for (m in methods) out = out m ":" methods[m] " "
    print out
}
' "$TMP")

[ -n "$methods_line" ] && echo -e "    ${COLOR_GRAY}Methods: ${methods_line}${COLOR_RESET}"