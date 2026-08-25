#!/bin/bash

ACH_FILE="$SUTD_DIR/data/achievements.dat"
mkdir -p "$SUTD_DIR/data"
touch "$ACH_FILE"

ACHIEVEMENTS=(
    "uptime_1d|Survivor|1 day uptime"
    "uptime_7d|Week Warrior|7 days uptime"
    "uptime_30d|Rock Solid|30 days uptime"
    "uptime_100d|Centurion|100 days uptime"
    "uptime_365d|Year of Pain|365 days uptime"
    "streak_3|Regular|3-day login streak"
    "streak_7|Dedicated|7-day login streak"
    "streak_30|Obsessed|30-day login streak"
    "streak_100|Addicted|100-day login streak"
    "age_30|Settled In|server is 30 days old"
    "age_365|Veteran|server is 1 year old"
)

UPTIME_SECONDS=$(awk '{print int($1)}' /proc/uptime 2>/dev/null | tr -dc '0-9')
[ -z "$UPTIME_SECONDS" ] && UPTIME_SECONDS=0
UPTIME_DAYS=$((UPTIME_SECONDS / 86400))

STREAK=$(awk -F= '/^streak=/ {print $2}' "$SUTD_DIR/data/streak.dat" 2>/dev/null | tr -dc '0-9')
[ -z "$STREAK" ] && STREAK=0
MAX_STREAK=$(awk -F= '/^max=/ {print $2}' "$SUTD_DIR/data/streak.dat" 2>/dev/null | tr -dc '0-9')
[ -z "$MAX_STREAK" ] && MAX_STREAK=0

INSTALL_EPOCH=$(cat "$SUTD_DIR/data/install_date.dat" 2>/dev/null | tr -dc '0-9')
NOW_EPOCH=$(date +%s)
[ -z "$INSTALL_EPOCH" ] && INSTALL_EPOCH=$NOW_EPOCH
AGE_DAYS=$(( (NOW_EPOCH - INSTALL_EPOCH) / 86400 ))
[ "$AGE_DAYS" -lt 0 ] && AGE_DAYS=0

check_unlock() {
    case "$1" in
        uptime_1d)   [ "$UPTIME_DAYS" -ge 1 ]   ;;
        uptime_7d)   [ "$UPTIME_DAYS" -ge 7 ]   ;;
        uptime_30d)  [ "$UPTIME_DAYS" -ge 30 ]  ;;
        uptime_100d) [ "$UPTIME_DAYS" -ge 100 ] ;;
        uptime_365d) [ "$UPTIME_DAYS" -ge 365 ] ;;
        streak_3)    [ "${MAX_STREAK:-0}" -ge 3 ]   ;;
        streak_7)    [ "${MAX_STREAK:-0}" -ge 7 ]   ;;
        streak_30)   [ "${MAX_STREAK:-0}" -ge 30 ]  ;;
        streak_100)  [ "${MAX_STREAK:-0}" -ge 100 ] ;;
        age_30)      [ "$AGE_DAYS" -ge 30 ]  ;;
        age_365)     [ "$AGE_DAYS" -ge 365 ] ;;
        *) return 1 ;;
    esac
}

progress() {
    case "$1" in
        uptime_1d)   echo "${UPTIME_DAYS}/1"   ;;
        uptime_7d)   echo "${UPTIME_DAYS}/7"   ;;
        uptime_30d)  echo "${UPTIME_DAYS}/30"  ;;
        uptime_100d) echo "${UPTIME_DAYS}/100" ;;
        uptime_365d) echo "${UPTIME_DAYS}/365" ;;
        streak_3)    echo "${MAX_STREAK:-0}/3"   ;;
        streak_7)    echo "${MAX_STREAK:-0}/7"   ;;
        streak_30)   echo "${MAX_STREAK:-0}/30"  ;;
        streak_100)  echo "${MAX_STREAK:-0}/100" ;;
        age_30)      echo "${AGE_DAYS}/30"  ;;
        age_365)     echo "${AGE_DAYS}/365" ;;
    esac
}

NEW_UNLOCKS=()
for entry in "${ACHIEVEMENTS[@]}"; do
    id="${entry%%|*}"
    if check_unlock "$id"; then
        if ! grep -q "^${id}$" "$ACH_FILE"; then
            echo "$id" >> "$ACH_FILE"
            NEW_UNLOCKS+=("$id")
        fi
    fi
done

divider
section "Achievements:"

UNLOCKED=0
for entry in "${ACHIEVEMENTS[@]}"; do
    IFS='|' read -r id title desc <<< "$entry"
    
    if check_unlock "$id"; then
        UNLOCKED=$((UNLOCKED + 1))
        if [[ " ${NEW_UNLOCKS[*]} " == *" $id "* ]]; then
            printf "    ${COLOR_YELLOW}🏅 NEW!${COLOR_RESET}  ${COLOR_WHITE}%-18s${COLOR_RESET} ${COLOR_GRAY}%s${COLOR_RESET}\n" "$title" "$desc"
        else
            printf "    ${COLOR_GREEN}✓${COLOR_RESET}       ${COLOR_WHITE}%-18s${COLOR_RESET} ${COLOR_GRAY}%s${COLOR_RESET}\n" "$title" "$desc"
        fi
    else
        printf "    ${COLOR_GRAY}○       %-18s %s (%s)${COLOR_RESET}\n" "$title" "$desc" "$(progress "$id")"
    fi
done

TOTAL=${#ACHIEVEMENTS[@]}
echo ""
echo -e "    ${COLOR_GRAY}Unlocked: ${COLOR_ACCENT}${UNLOCKED}${COLOR_GRAY} / ${TOTAL}${COLOR_RESET}"