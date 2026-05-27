#!/bin/bash
if [ -n "$SHOW_WEATHER_CITY" ]; then
    WEATHER=$(timeout 2 curl -s "wttr.in/${SHOW_WEATHER_CITY}?format=%l:+%C+%t+%w" 2>/dev/null)
    [ -n "$WEATHER" ] && echo -e "  ${COLOR_BLUE}☁ ${WEATHER}${COLOR_RESET}"
fi
