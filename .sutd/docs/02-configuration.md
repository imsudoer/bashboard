---
title: "Configuration"
description: "Complete reference for info.conf — themes, modes, module toggles"
order: 2
group: "Bashboard"
---
# Configuration Reference
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
All configuration lives in **`~/.sutd/info.conf`**. It's a plain bash file
that's sourced before everything else.

## File structure

```bash
# Theme
THEME_ACCENT="208"
THEME_BG="237"
THEME_BG_ENABLED=1

# Interface
INTERFACE_MODE=1

# Module toggles
ENABLE_HOST=1
ENABLE_NETWORK=1
# ... etc

# Module-specific options
SSL_WARN_DAYS=14
TOP_PROCESSES_COUNT=3
LAST_COMMANDS_COUNT=5
SHOW_WEATHER_CITY="Moscow"
SHOW_EXTERNAL_IP=1
SHOW_CPU_TEMP=1

# Safety
SAFE_RM_LEVEL=2

# Key bindings
CTX_MENU_BIND="\C-g"

# helpme web server
HELPME_PORT=8765
HELPME_BIND="127.0.0.1"
```

## Theme variables

| Variable           | Type    | Default | Description                                |
|--------------------|---------|---------|--------------------------------------------|
| `THEME_ACCENT`     | int     | `"208"` | 256-color code for accent (logo, headers)  |
| `THEME_BG`         | int     | `"237"` | 256-color code for panel backgrounds       |
| `THEME_BG_ENABLED` | 0/1     | `1`     | Toggle panel backgrounds in menu/TUI       |

Reference: [Theming Guide](08-theming.md).

## Interface variables

| Variable          | Type   | Default | Description                          |
|-------------------|--------|---------|--------------------------------------|
| `INTERFACE_MODE`  | 0/1/2  | `1`     | 0=plain, 1=slides menu, 2=full TUI   |

## Module toggles

Each module is enabled by `ENABLE_<NAME>=1`. Set to `0` or remove to disable.

| Variable                 | Module                  | Effect                              |
|--------------------------|-------------------------|-------------------------------------|
| `ENABLE_HOST`            | host info               | Hostname, OS, kernel, arch          |
| `ENABLE_NETWORK`         | network info            | Local/public IP, connections        |
| `ENABLE_SYSTEM`          | system info             | Uptime, load, users, procs          |
| `ENABLE_RESOURCES`       | resources               | CPU%, RAM, disk, swap, inodes       |
| `ENABLE_SSL_CERTS`       | SSL certificates        | Let's Encrypt expiry tracking       |
| `ENABLE_TOP_PROCESSES`   | top processes           | Top N by CPU and RAM                |
| `ENABLE_STREAK`          | login streak            | Consecutive-day counter             |
| `ENABLE_UPTIME_RECORD`   | uptime record           | Longest-uptime tracker              |
| `ENABLE_SERVER_AGE`      | server age              | Days since install                  |
| `ENABLE_SERVICES`        | systemd services        | Services list with status           |
| `ENABLE_ACHIEVEMENTS`    | achievements            | Unlock-style badges                 |
| `ENABLE_PROGRESS_BARS`   | progress bars           | ASCII bars for CPU/RAM/disk         |
| `ENABLE_ASCII_GRAPH`     | ASCII graph             | CPU history visualization           |
| `ENABLE_DOCKER`          | docker containers       | Running/total counts, container list|
| `ENABLE_SECURITY`        | security                | Failed SSH, fail2ban, ufw           |
| `ENABLE_UPDATES`         | system updates          | APT updates, reboot required        |
| `ENABLE_LAST_COMMANDS`   | last commands           | History from previous session       |
| `ENABLE_FOOTER`          | footer                  | Weather / motd footer               |

## Module-specific options

### SSL certificates
```bash
SSL_CERTS_PATH=""          # leave empty for auto-detect
SSL_WARN_DAYS=14           # turn yellow if fewer days remain
```

The auto-detect searches:
- `/etc/letsencrypt/live`
- `/etc/ssl/letsencrypt/live`
- `/opt/letsencrypt/live`
- `/usr/local/etc/letsencrypt/live`

### Top processes
```bash
TOP_PROCESSES_COUNT=3      # how many to show per category (CPU, RAM)
```

### Last commands
```bash
LAST_COMMANDS_COUNT=5      # how many recent commands to show
```

### Weather (footer module)
```bash
SHOW_WEATHER_CITY="Moscow" # any string accepted by wttr.in
```

### Network module
```bash
SHOW_EXTERNAL_IP=1         # query ifconfig.me on login (slows down by ~500ms)
```

### Resources module
```bash
SHOW_CPU_TEMP=1            # show temperature (requires `sensors` or /sys/class/thermal)
```

## Safety variables

```bash
SAFE_RM_LEVEL=2
```

Controls confirmation strictness for dangerous commands:

| Level | Behavior                                                |
|-------|---------------------------------------------------------|
| `1`   | Simple y/n prompt                                       |
| `2`   | Must type `yes`                                         |
| `3`   | Must type a random 4-digit code (used for critical paths)|

Level `3` always applies to commands targeting system paths (`/`, `/etc`,
`/var`, `/usr`, `/boot`, `$HOME`), regardless of this setting.

## Key bindings

```bash
CTX_MENU_BIND="\C-g"
```

Readline-style key sequences. Examples:
- `"\C-g"` — Ctrl+G
- `"\C-o"` — Ctrl+O
- `"\eq"` — Alt+Q
- `"\C-x\C-m"` — Ctrl+X, Ctrl+M

## helpme web server

```bash
HELPME_PORT=8765
HELPME_BIND="127.0.0.1"    # set to 0.0.0.0 to expose to network
```

When `helpme -w` is invoked, these defaults apply. The port can be
overridden per-call: `helpme -w 9000`.

## Editing config safely

The recommended workflow:

```bash
cfg backup sutd            # creates timestamped backup
cfg sutd                   # opens in $EDITOR
exec bash                  # reload to apply
```

Or manually:

```bash
cp ~/.sutd/info.conf ~/.sutd/info.conf.bak
nano ~/.sutd/info.conf
exec bash
```

## Per-project config

You can override defaults inside specific project directories. See
[Per-Project Setup](guides/per-project-setup.md).

## Live reload

Most changes require running `exec bash` to take effect, because the
config is sourced at shell start. The exception is `helpme -w` which
re-sources the config on each invocation.