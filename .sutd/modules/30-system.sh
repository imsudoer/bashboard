#!/bin/bash
field "Uptime" "$(uptime -p | sed 's/up //')"
field "Load"   "$(awk '{print $1", "$2", "$3}' /proc/loadavg)"
field "Users"  "$(who | wc -l) logged in"
field "Procs"  "$(ps -e --no-headers | wc -l) total"
