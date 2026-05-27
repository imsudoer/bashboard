---
title: "Library API"
description: "Helper functions and color variables available in lib.sh"
order: 6
group: "Bashboard"
badge: "API"
---
# Library API (`lib.sh`)
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
`~/.sutd/lib.sh` provides shared helper functions used across modules
and terminal extensions. Many are pre-exported by `motd.sh`, but you
can also source `lib.sh` directly:

```bash
source "$SUTD_DIR/lib.sh"
```

## Available functions

### Output helpers (exported by motd.sh)

#### `field <label> <value>`

Print an aligned key-value row.

```bash
field "Hostname" "$(hostname)"
# →   Hostname  : onlysq
```

The label is padded to 10 characters. Value can contain ANSI codes.

#### `divider`

Print a horizontal separator.

```bash
divider
# →   --------------------------------------------------
```

#### `section <title>`

Print a section header in white.

```bash
section "Services:"
# →   Services:
```

### System helpers (from lib.sh)

#### `get_cpu_usage`

Return current CPU usage as an integer 0–100.

Uses two reads of `/proc/stat` with a 300ms gap to calculate accurate
deltas. Reliable on all Linux systems.

```bash
CPU=$(get_cpu_usage)
echo "CPU: ${CPU}%"
```

Returns `0` if unable to read `/proc/stat`.

**Performance note**: This call takes ~300ms due to the required sleep.
Don't call it more than once per module run.

#### `is_int <value>`

Return success if value is a valid integer (positive or negative).

```bash
if is_int "$x"; then
    echo "$x is a number"
fi

# Defensive default:
COUNT=$(some-command | wc -l)
is_int "$COUNT" || COUNT=0
```

#### `apply_theme`

Re-derive `COLOR_ACCENT` and panel background variables from
`THEME_*` settings in `info.conf`.

```bash
THEME_ACCENT="46"        # change to matrix green
apply_theme              # now $COLOR_ACCENT is green
```

Normally called once by `motd.sh` at startup. Useful in interactive
tools that want to switch themes mid-session.

## Pre-exported color variables

These are set by `motd.sh` and available in every module:

```bash
$COLOR_ACCENT    # theme accent (default orange)
$COLOR_WHITE
$COLOR_GRAY
$COLOR_GREEN
$COLOR_RED
$COLOR_YELLOW
$COLOR_BLUE
$COLOR_PURPLE
$COLOR_RESET
$COLOR_BG        # panel background (empty if THEME_BG_ENABLED=0)
$COLOR_BG_RESET
```

### Using colors

```bash
echo -e "${COLOR_GREEN}success${COLOR_RESET}"
echo -e "${COLOR_RED}error${COLOR_RESET}"
echo -e "${COLOR_ACCENT}highlight${COLOR_RESET}"
```

Inside `printf`, use `%b` to interpret escapes:

```bash
printf "    %b%-20s%b\n" "$COLOR_GREEN" "$name" "$COLOR_RESET"
```

### Bold and underline

`lib.sh` doesn't provide these, but you can use raw ANSI:

```bash
echo -e "\033[1m bold \033[0m"
echo -e "\033[4m underline \033[0m"
echo -e "\033[1;38;5;208m bold accent \033[0m"
```

## Extending lib.sh

You can add your own helpers to `lib.sh`. They become available to all
modules that source it.

Example: add a `human_bytes` helper:

```bash
# In ~/.sutd/lib.sh, append:
human_bytes() {
    local b=$1
    if [ "$b" -lt 1024 ]; then echo "${b}B"
    elif [ "$b" -lt 1048576 ]; then printf "%.1fK" "$(echo "$b/1024" | bc -l)"
    elif [ "$b" -lt 1073741824 ]; then printf "%.1fM" "$(echo "$b/1048576" | bc -l)"
    else printf "%.1fG" "$(echo "$b/1073741824" | bc -l)"
    fi
}
export -f human_bytes
```

Now any module can use it:

```bash
#!/bin/bash
source "$SUTD_DIR/lib.sh"

field "Total" "$(human_bytes 1234567890)"
# →   Total     : 1.1G
```

### Export rules

For functions to be available in modules (which run in subprocesses),
they must be exported with `export -f`. Variables need `export`.

```bash
my_var="hello"
export my_var               # works in subprocess

my_func() { echo "hi"; }
export -f my_func           # works in subprocess
```

## Coding standards

When adding to `lib.sh`:

1. **Local variables only** inside functions
2. **Return codes**: 0 = success, non-zero = failure
3. **No side effects** unless explicitly named (e.g. `apply_theme`)
4. **Document at top** with a comment line
5. **Export with `export -f`** if intended for module use

Template:

```bash
# my_helper — what it does
# usage: my_helper <arg1> <arg2>
# returns: prints result to stdout, exit code 0 on success
my_helper() {
    local arg1="$1"
    local arg2="$2"
    
    [ -z "$arg1" ] && return 1
    
    # ... logic ...
    
    echo "$result"
}
export -f my_helper
```

## Reading external state

Common pattern: read a `data/` file safely.

```bash
read_data() {
    local file="$1"
    local default="${2:-}"
    
    if [ -r "$file" ]; then
        cat "$file"
    else
        echo "$default"
    fi
}
```

Usage:

```bash
STREAK=$(read_data "$SUTD_DIR/data/streak.dat" "0")
```

## Atomic writes

When updating a data file, write atomically to avoid corruption if
interrupted:

```bash
write_atomic() {
    local file="$1"
    local content="$2"
    
    echo "$content" > "${file}.tmp" && mv "${file}.tmp" "$file"
}
```

Usage:

```bash
write_atomic "$SUTD_DIR/data/counter.dat" "$NEW_COUNT"
```

This pattern prevents half-written files if the shell is killed mid-write.