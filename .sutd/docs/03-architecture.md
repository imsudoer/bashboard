---
title: "Architecture"
description: "Directory layout, boot lifecycle, and how modules vs terminal extensions work"
order: 3
group: "Bashboard"
---
# Architecture
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
## Directory layout

```
~/.sutd/
├── motd.sh                    # entry point invoked from .bashrc
├── menu.sh                    # interactive slides interface
├── lib.sh                     # shared helper functions
├── info.conf                  # main configuration
├── services.list              # systemd services to monitor
│
├── modules/                   # dashboard modules
│   ├── 10-host.sh             # host info
│   ├── 20-network.sh          # network info
│   ├── 30-system.sh           # system info
│   ├── 40-resources.sh        # CPU/RAM/disk
│   ├── 45-ssl-certs.sh        # SSL certificate expiry
│   ├── 46-top-processes.sh    # top procs by CPU/RAM
│   ├── 47-streak.sh           # login streak
│   ├── 48-uptime-record.sh    # uptime record
│   ├── 49-server-age.sh       # server age
│   ├── 50-services.sh         # systemd services list
│   ├── 51-achievements.sh     # achievements
│   ├── 52-progress-bars.sh    # ASCII progress bars
│   ├── 53-ascii-graph.sh      # CPU history graph
│   ├── 60-docker.sh           # docker info
│   ├── 70-security.sh         # security (fail2ban, ufw)
│   ├── 80-updates.sh          # APT updates
│   └── 95-last-commands.sh    # last commands from previous session
│
├── terminal/                  # shell-injected extensions
│   ├── prompt.sh              # PS1 with breadcrumbs, git, timing
│   ├── mods.sh                # navigation, bookmarks, utilities
│   ├── safe-rm.sh             # dangerous command guards
│   ├── al.sh                  # alias manager
│   ├── chain.sh               # command pipelines
│   ├── helpme.sh              # help system + web server
│   ├── cfg.sh                 # quick-edit configs
│   ├── f.sh                   # fast file finder
│   ├── env-check.sh           # env verification
│   ├── redo.sh                # repeat with modification
│   ├── watch-reload.sh        # file watcher
│   ├── remember.sh            # persistent env vars
│   ├── peek.sh                # JSON viewer
│   ├── qr.sh                  # QR codes
│   ├── serve.sh               # quick HTTP server
│   ├── stats.sh               # shell statistics
│   ├── service-menu.sh        # systemd service menu
│   ├── ctx-menu.sh            # Ctrl+G context menu
│   ├── proj-history.sh        # per-project history
│   └── tui.sh                 # full TUI mode (also entry point)
│
├── data/                      # persistent state (see 07-data-storage.md)
│   ├── streak.dat
│   ├── uptime_record.dat
│   ├── achievements.dat
│   ├── install_date.dat
│   ├── cpu_history.dat
│   ├── notes.txt
│   ├── aliases.dat
│   ├── bookmarks
│   ├── cfgs.dat
│   ├── remembered.dat
│   ├── last_commands.log
│   ├── chains/                # one file per chain
│   ├── helpme/                # markdown help pages
│   ├── env-checks/            # tool presets
│   └── proj_histories/        # per-project history files
│
└── docs/                      # this documentation
```

## Boot lifecycle

When you SSH in, the following happens in order:

```
[1] /etc/profile + /etc/bash.bashrc        (system)
[2] ~/.bashrc                              (user)
[3]   └─ Calls ~/.sutd/motd.sh             (Bashboard entry)
[4]       ├─ Sources info.conf             (config)
[5]       ├─ Sources lib.sh                (helpers)
[6]       ├─ Sets up colors                (exported)
[7]       ├─ Calls apply_theme             (THEME_* → COLOR_ACCENT)
[8]       ├─ Defines field/divider/section (exported helpers)
[9]       └─ Branches on INTERFACE_MODE:
[9a]          0 → for f in modules/*; do bash "$f"; done
[9b]          1 → exec menu.sh
[9c]          2 → exec terminal/tui.sh
[10]  └─ for f in terminal/*.sh; do source "$f"; done
[11]     ├─ prompt.sh sets PROMPT_COMMAND
[12]     ├─ proj-history.sh prepends to PROMPT_COMMAND
[13]     ├─ ctx-menu.sh binds Ctrl+G
[14]     └─ All other tools define their functions
[15] Shell prompt appears
```

## How modules execute

When `motd.sh` (or `menu.sh`/`tui.sh`) decides to run a module:

1. **Iterate** files in `modules/` alphabetically (= numeric prefix order)
2. **Derive** enable variable name from filename
3. **Check** `${!var_name}` — if not `1`, skip
4. **Execute** module as `bash "$module"` (separate process, **not** sourced)
5. **Continue** to next module even if current one errored

This means modules are completely isolated:

- They cannot modify your shell's environment
- A `set -e` or `exit 1` in a module won't kill the dashboard
- They share **only** what was exported by `motd.sh` (colors, helpers, `SUTD_DIR`)

## How terminal extensions execute

When `.bashrc` runs `for f in ~/.sutd/terminal/*.sh; do source "$f"; done`:

1. Each file is **sourced into the interactive shell** (not subprocess)
2. Files load alphabetically — earlier files can be overridden by later ones
3. Functions, aliases, `PROMPT_COMMAND` chains accumulate
4. Anything defined at top level persists until shell exits

This is why:

- You should **never** put `exit` in a terminal extension
- You should **always** use `local` for variables inside functions
- Long-running code (loops, sleeps) **freezes login** until they finish

## Shared environment

`motd.sh` exports these for module use:

| Variable        | Meaning                              |
|-----------------|--------------------------------------|
| `SUTD_DIR`      | Path to `~/.sutd`                    |
| `COLOR_ACCENT`  | Theme accent (e.g. orange)           |
| `COLOR_WHITE`   | White                                |
| `COLOR_GRAY`    | Gray                                 |
| `COLOR_GREEN`   | Green                                |
| `COLOR_RED`     | Red                                  |
| `COLOR_YELLOW`  | Yellow                               |
| `COLOR_BLUE`    | Blue                                 |
| `COLOR_PURPLE`  | Purple                               |
| `COLOR_RESET`   | ANSI reset                           |
| `COLOR_BG`      | Panel background (or empty)          |
| `COLOR_BG_RESET`| Background reset (or empty)          |

And exports these functions:

| Function           | Use                                       |
|--------------------|-------------------------------------------|
| `field "k" "v"`    | Print aligned key:value row               |
| `divider`          | Print horizontal rule                     |
| `section "Title"`  | Print section header                      |
| `get_cpu_usage`    | Calculate CPU% from /proc/stat            |
| `is_int "$x"`      | Check if string is an integer             |
| `apply_theme`      | Re-derive `COLOR_ACCENT` from `THEME_*`   |

Modules typically `source "$SUTD_DIR/lib.sh"` themselves if they need
extra helpers from `lib.sh` that aren't pre-exported.

## Three interface modes side-by-side

### Mode 0: Plain MOTD

```
[motd.sh]
   ↓ source info.conf
   ↓ for module in modules/*: bash $module
   ↓ exit
[shell prompt]
```

Fastest, all output dumped to screen at once.

### Mode 1: Slides Menu

```
[motd.sh]
   ↓ source info.conf
   ↓ exec menu.sh
[menu.sh]
   ↓ define SLIDES array
   ↓ loop:
       show_slide $current
       read keypress
       case key: navigate / quit
[shell prompt] (when user presses q)
```

Each slide is a group of modules. Navigation is via arrow keys.

### Mode 2: Full TUI

```
[motd.sh]
   ↓ source info.conf
   ↓ exec tui.sh
[tui.sh]
   ↓ tput smcup                    (alternate screen)
   ↓ tput civis                    (hide cursor)
   ↓ draw header / sidebar / divider
   ↓ loop:
       redraw content panel only
       read keypress
       update selection
[shell prompt] (after tput rmcup)
```

Full-screen TUI with sidebar and refreshable content panel.

## Loading order matters

Within `terminal/`, files load alphabetically:

1. `al.sh` defines `al` function
2. `cfg.sh` defines `cfg` function
3. `chain.sh` defines `chain` function
4. `ctx-menu.sh` binds Ctrl+G
5. `env-check.sh` defines `env-check`
6. `f.sh` defines `f`
7. `helpme.sh` defines `helpme` and `?` alias
8. `mods.sh` defines navigation aliases and `note`, `extract`, etc.
9. `peek.sh` defines `peek`
10. `proj-history.sh` defines `projhist`, **prepends** `__proj_history_switch` to `PROMPT_COMMAND`
11. `prompt.sh` defines `set_prompt`, **appends** to `PROMPT_COMMAND`
12. `qr.sh` defines `qr`
13. `redo.sh` defines `redo`
14. `remember.sh` defines `remember`, auto-imports vars
15. `safe-rm.sh` wraps `rm`, `dd`, `mkfs`, `chmod`, `chown`, `iptables`
16. `serve.sh` defines `serve`
17. `service-menu.sh` defines `svc`
18. `stats.sh` defines `stats`
19. `tui.sh` is **only an executable**, not sourced
20. `watch-reload.sh` defines `watch-reload`

If you need to control order, use prefixes: `00-myearly.sh`, `99-mylate.sh`.

## Why bash and not zsh/fish?

Bash is preinstalled on every Linux server. No installation steps,
no convincing your team, no syntax differences across servers. The
sacrifice is some interactivity (no real-time autosuggestions), but
Bashboard fills most of those gaps with `complete -F` autocompletions
and explicit utilities like `redo`, `hrun`, `al`.

If you want fish-like behavior, see the [ble.sh integration guide](guides/troubleshooting.md#fish-like-autosuggestions).