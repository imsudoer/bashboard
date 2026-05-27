---
title: "Writing Modules"
description: "How to build custom dashboard modules with the Bashboard module system"
order: 4
group: "Bashboard"
badge: "GUIDE"
---
# Writing Dashboard Modules
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
A **module** is a bash script in `~/.sutd/modules/` that produces a chunk of
dashboard output. Modules run at login time (or when a slide is shown) in
isolated subshells.

## Anatomy of a module

The simplest possible module:

```bash
#!/bin/bash
echo "  Hello from my module"
```

A more typical module using the shared helpers:

```bash
#!/bin/bash

divider
section "My Section:"

field "Time"      "$(date '+%H:%M:%S')"
field "Hostname"  "$(hostname)"
field "Whoami"    "$(whoami)"
```

Output:

```
  --------------------------------------------------
  My Section:
  Time      : 14:32:01
  Hostname  : onlysq
  Whoami    : root
```

## Naming conventions

Filename format: `<NN>-<name>.sh`

- `NN` — two digits controlling execution order (lower = earlier)
- `<name>` — lowercase, hyphen-separated

| Filename                | Order | Enable variable        |
|-------------------------|-------|------------------------|
| `10-host.sh`            | 1st   | `ENABLE_HOST`          |
| `45-ssl-certs.sh`       | mid   | `ENABLE_SSL_CERTS`     |
| `95-last-commands.sh`   | last  | `ENABLE_LAST_COMMANDS` |

The loader transforms the name: strip prefix → replace `-` with `_` →
uppercase → prepend `ENABLE_`.

## Enabling your module

Add to `~/.sutd/info.conf`:

```bash
ENABLE_MYMODULE=1
```

Without this line (or with `=0`), the module is skipped entirely.

## Available helpers

These are pre-exported by `motd.sh` and available in every module:

### Output functions

```bash
field "Key" "Value"
# →   Key       : Value

section "My Title:"
# →   My Title:

divider
# →   --------------------------------------------------
```

### Color variables

```bash
echo -e "${COLOR_GREEN}ok${COLOR_RESET}"
echo -e "${COLOR_RED}fail${COLOR_RESET}"
echo -e "${COLOR_ACCENT}highlighted${COLOR_RESET}"
```

| Variable        | Typical use                  |
|-----------------|------------------------------|
| `$COLOR_ACCENT` | Theme accent (orange)        |
| `$COLOR_WHITE`  | Default text                 |
| `$COLOR_GRAY`   | Subtle, secondary info       |
| `$COLOR_GREEN`  | Success, "OK", "running"     |
| `$COLOR_RED`    | Errors, "down", "expired"    |
| `$COLOR_YELLOW` | Warnings                     |
| `$COLOR_BLUE`   | Info, links                  |
| `$COLOR_PURPLE` | Special items                |
| `$COLOR_RESET`  | Always reset after coloring  |

### Library helpers

If you need more than the pre-exported helpers, source `lib.sh`:

```bash
#!/bin/bash
source "$SUTD_DIR/lib.sh"

CPU=$(get_cpu_usage)
is_int "$CPU" || CPU=0

field "CPU" "${CPU}%"
```

See [Library API](06-lib-api.md) for the full list.

### Environment

| Variable     | Value                          |
|--------------|--------------------------------|
| `$SUTD_DIR`  | Absolute path to `~/.sutd`     |
| `$HOME`      | User home                      |
| `$USER`      | Username                       |

You also have access to all the `info.conf` variables, since the config
is sourced before modules run. So you can read your own custom settings:

```bash
# In info.conf:
MY_API_URL="https://api.example.com"

# In your module:
field "API" "$(curl -s -o /dev/null -w '%{http_code}' $MY_API_URL)"
```

## Layout & spacing conventions

To stay consistent with built-in modules:

- **Indent content by 4 spaces** (`field` does this automatically)
- **Start sections with `divider` then `section`**
- **Use `field` for key-value rows** when possible
- **Keep labels under 12 characters** so they align with built-in modules

```bash
#!/bin/bash

divider
section "Database:"

field "Host"      "db.local"
field "Port"      "5432"
field "Connected" "yes"
```

For non-aligned content (lists, custom rows), use 4-space indentation:

```bash
divider
section "Containers:"

docker ps --format '{{.Names}}|{{.Status}}' | while IFS='|' read -r name status; do
    printf "    ${COLOR_GREEN}●${COLOR_RESET} %-20s ${COLOR_GRAY}%s${COLOR_RESET}\n" "$name" "$status"
done
```

## Error handling

Modules run with relaxed error handling — they continue past failures.
This is intentional. To be robust:

### Always check for tools

```bash
command -v docker &>/dev/null || exit 0
```

If `docker` isn't installed, exit cleanly without output.

### Always check for files

```bash
[ -r /sys/class/thermal/thermal_zone0/temp ] || exit 0
```

### Default to safe values

```bash
COUNT=$(some-command 2>/dev/null | wc -l)
is_int "$COUNT" || COUNT=0
```

### Use timeouts for network calls

```bash
EXT_IP=$(timeout 2 curl -s ifconfig.me 2>/dev/null)
[ -n "$EXT_IP" ] && field "Public IP" "$EXT_IP"
```

Without `timeout`, a network hang would freeze the entire login.

## Performance tips

A typical module should run in **under 100ms**. To check yours:

```bash
time bash ~/.sutd/modules/45-myslow.sh
```

Common pitfalls:

| Bad                                    | Good                                  |
|----------------------------------------|---------------------------------------|
| `top -bn1` (slow, 1+ sec)              | `get_cpu_usage` (300ms)               |
| `journalctl ... | wc -l` (parses logs) | `[ -f /var/run/reboot-required ]`     |
| Bare `curl` (no timeout)               | `timeout 2 curl ...`                  |
| `find /` (huge)                        | `find /etc/letsencrypt -maxdepth 3`   |
| Multiple invocations of same command   | Cache result in a variable            |

## Module lifecycle hooks (advanced)

Modules run in subprocesses, so they can't directly affect the parent
shell. But they **can** write to files in `data/`, which terminal
extensions or future module runs can read.

Example: A "command counter" module:

```bash
#!/bin/bash
COUNT_FILE="$SUTD_DIR/data/login_count.dat"
COUNT=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

field "Logins" "$COUNT"
```

## Conditional inclusion

You can skip a module based on runtime conditions:

```bash
#!/bin/bash

# Only show on weekdays
DAY=$(date +%u)
[ "$DAY" -ge 6 ] && exit 0

field "Workday" "$(date '+%A')"
```

```bash
#!/bin/bash

# Only show after 18:00
HOUR=$(date +%H)
[ "$HOUR" -lt 18 ] && exit 0

divider
section "Evening reminder:"
field "Backup" "scheduled at 23:00"
```

## Testing your module

Standalone test:

```bash
bash -x ~/.sutd/modules/55-mymodule.sh
```

Or run within the full dashboard environment:

```bash
~/.sutd/motd.sh
```

To test inside a slide, edit `menu.sh` and add the filename to a `SLIDES`
entry:

```bash
SLIDES=(
    "Overview|10-host.sh 30-system.sh 55-mymodule.sh"
    # ...
)
```

## Examples

See:

- [Disk Health module](examples/module-disk-health.md) — SMART status
- [Backup Status module](examples/module-backup-status.md) — last backup age

## Disabling without deleting

If you want to keep a module file but stop it from running:

**Option A**: Set `ENABLE_<NAME>=0` in `info.conf`.

**Option B**: Rename to disable globally:
```bash
mv ~/.sutd/modules/55-mymodule.sh ~/.sutd/modules/55-mymodule.sh.disabled
```

The loader only picks up `.sh` files.