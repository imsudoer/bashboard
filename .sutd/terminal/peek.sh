#!/bin/bash

# :helpme:
# title: JSON Peek
# desc: Pretty-print JSON with syntax coloring, no jq required
# category: utility
# usage:
#   peek <file.json>              view file
#   cat file | peek               from stdin
#   curl ... | peek               pipe API output
# examples:
#   peek config.json
#   curl -s api.github.com/users/torvalds | peek
#   echo '{"a":1,"b":[1,2,3]}' | peek
#   docker inspect nginx | peek
# :endhelpme:

peek() {
    local input
    
    if [ $# -eq 0 ]; then
        if [ -t 0 ]; then
            echo "  usage: peek <file.json>  or  cat file | peek"
            return 1
        fi
        input=$(cat)
    elif [ -f "$1" ]; then
        input=$(cat "$1")
    else
        echo "  no such file: $1"
        return 1
    fi
    
    if command -v python3 &>/dev/null; then
        echo "$input" | python3 -c '
import json, sys, re

def color(text, c):
    colors = {
        "key":     "\033[38;5;208m",
        "string":  "\033[32m",
        "number":  "\033[38;5;75m",
        "bool":    "\033[38;5;141m",
        "null":    "\033[90m",
        "punct":   "\033[37m",
        "reset":   "\033[0m"
    }
    return colors[c] + text + colors["reset"]

try:
    data = json.loads(sys.stdin.read())
except Exception as e:
    print("invalid JSON:", e)
    sys.exit(1)

output = json.dumps(data, indent=2, ensure_ascii=False)

def colorize_line(line):
    m = re.match(r"^(\s*)(\".*?\")(\s*:\s*)(.*?)(,?)$", line)
    if m:
        indent, key, sep, val, comma = m.groups()
        key_c = color(key, "key")
        if val.startswith("\""):
            val_c = color(val.rstrip(","), "string")
        elif val in ("true", "false"):
            val_c = color(val.rstrip(","), "bool")
        elif val == "null":
            val_c = color(val.rstrip(","), "null")
        elif re.match(r"^-?[\d.]+", val):
            val_c = color(val.rstrip(","), "number")
        else:
            val_c = color(val.rstrip(","), "punct")
        return f"{indent}{key_c}{color(sep, \"punct\")}{val_c}{color(comma, \"punct\")}"
    return color(line, "punct")

for line in output.split("\n"):
    print(colorize_line(line))
'
    else
        echo "$input" | sed -e 's/{/\n{/g' -e 's/}/}\n/g' -e 's/,/,\n/g'
    fi
}