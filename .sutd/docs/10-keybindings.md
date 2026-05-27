---
title: "Keybindings"
description: "All keyboard shortcuts across the dashboard, menu, TUI, and shell"
order: 10
group: "Bashboard"
---
# Keybindings
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
All keyboard shortcuts available in Bashboard.

## Global (always active)

| Key       | Action                                |
|-----------|---------------------------------------|
| `Ctrl+G`  | Open context menu (project-aware)     |

The context menu adapts based on the current directory:
- Inside a git repo → git actions appear
- With `docker-compose.yml` → compose actions
- With `package.json` → npm actions
- With `Makefile` → make actions
- Always: resources, ports, top procs, menus

To change the binding, edit `~/.sutd/info.conf`:

```bash
CTX_MENU_BIND="\C-o"        # Ctrl+O
CTX_MENU_BIND="\eq"         # Alt+Q
CTX_MENU_BIND="\C-x\C-m"    # Ctrl+X, Ctrl+M
```

## Slides menu (`INTERFACE_MODE=1`)

When the slides menu is showing:

| Key                    | Action                          |
|------------------------|---------------------------------|
| `→` / `d` / `l`        | Next slide                      |
| `←` / `a` / `j`        | Previous slide                  |
| `q` / `Enter`          | Exit to terminal                |
| `h`                    | Show help                       |

The slide indicator at top right shows position (e.g. `[3/11]`).

## TUI mode (`INTERFACE_MODE=2`)

When the full TUI is showing:

| Key                | Action                              |
|--------------------|-------------------------------------|
| `↑` / `k`          | Previous slide                      |
| `↓` / `j`          | Next slide                          |
| `r`                | Refresh current slide content       |
| `m`                | Switch to slides menu mode          |
| `q` / `Enter`      | Exit TUI to terminal                |

## Help center interactive (`helpme`)

| Key                | Action                              |
|--------------------|-------------------------------------|
| `1`–`9`            | Select topic by number              |
| `w`                | Start web server (`helpme -w`)      |
| `q` / `Enter`      | Exit                                |

## Service manager (`svc`)

| Key                | Action                              |
|--------------------|-------------------------------------|
| `1`–`N`            | Select service by number            |
| `q`                | Cancel                              |

Then in action menu:

| Key   | Action            |
|-------|-------------------|
| `1`   | start             |
| `2`   | stop              |
| `3`   | restart           |
| `4`   | status            |
| `5`   | enable            |
| `6`   | disable           |
| `7`   | logs (last 30)    |
| `q`   | Cancel            |

## Bash defaults (worth knowing)

These come from bash itself, not Bashboard, but they pair well:

### Movement

| Key         | Action                          |
|-------------|---------------------------------|
| `Ctrl+A`    | Beginning of line               |
| `Ctrl+E`    | End of line                     |
| `Alt+B`     | Word backward                   |
| `Alt+F`     | Word forward                    |

### Editing

| Key         | Action                          |
|-------------|---------------------------------|
| `Ctrl+W`    | Delete word backward            |
| `Ctrl+U`    | Delete to start of line         |
| `Ctrl+K`    | Delete to end of line           |
| `Ctrl+Y`    | Paste last deleted text         |
| `Ctrl+L`    | Clear screen (keeps current cmd)|

### History

| Key         | Action                          |
|-------------|---------------------------------|
| `↑` / `Ctrl+P` | Previous command             |
| `↓` / `Ctrl+N` | Next command                 |
| `Ctrl+R`    | Reverse search                  |
| `Ctrl+G`    | (overridden by Bashboard)       |

> Since `Ctrl+G` is normally "cancel search" in bash, Bashboard's override
> may interfere with reverse-search workflow. To restore default bash
> behavior, change `CTX_MENU_BIND` in `info.conf`.

### Job control

| Key         | Action                          |
|-------------|---------------------------------|
| `Ctrl+Z`    | Suspend foreground process      |
| `Ctrl+C`    | Interrupt (SIGINT)              |
| `Ctrl+D`    | Logout (EOF)                    |

### Tab completion (enhanced by Bashboard)

With autocomplete defined for several commands, you can do:

```
al <TAB>           → shows all alias names
chain <TAB>        → shows subcommands
chain run <TAB>    → shows chain names
cfg <TAB>          → shows registered configs
env-check <TAB>    → shows presets
svc <TAB>          → shows services from services.list (if configured)
```

## Customizing bindings

Bind your own keys via `bind -x` in any terminal extension:

```bash
# In ~/.sutd/terminal/my-binds.sh
__quick_status() {
    echo ""
    systemctl status nginx --no-pager -l
}
bind -x '"\C-n": __quick_status'        # Ctrl+N → nginx status
```

After `exec bash`, the binding is active.

### Common key sequences

| Sequence      | Key                |
|---------------|--------------------|
| `"\C-x"`      | Ctrl+X             |
| `"\C-x\C-y"`  | Ctrl+X, then Ctrl+Y|
| `"\ex"`       | Alt+X (or Esc, X)  |
| `"\e[1;5D"`   | Ctrl+←             |
| `"\e[1;5C"`   | Ctrl+→             |
| `"\eOA"`      | ↑                  |
| `"\e[2~"`     | Insert             |
| `"\e[3~"`     | Delete             |

### Conflict check

Before binding, check what's already mapped:

```bash
bind -p | grep '\\C-g'        # what's Ctrl+G doing?
bind -p | less                # all current bindings
```

## Bashboard binding conventions

When writing your own extensions, use bindings respectfully:

- **Don't bind** `Ctrl+C`, `Ctrl+D`, `Ctrl+Z`, `Ctrl+L`, `Ctrl+R` — these
  are deeply ingrained muscle memory
- **Prefer** `Alt+<letter>` for personal shortcuts — fewer conflicts
- **Avoid** `Ctrl+H` (backspace), `Ctrl+I` (tab), `Ctrl+M` (enter) —
  these are control characters
- **Single bindings** rather than multi-key sequences for daily-use
  commands; reserve `Ctrl+X <key>` for less-common actions