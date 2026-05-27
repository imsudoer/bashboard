---
title: "Getting Started"
description: "Installation, first run, and core concepts of Bashboard"
order: 1
group: "Bashboard"
badge: "START"
---
# Getting Started
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
## What is Bashboard?

Bashboard is a framework that augments your bash shell with three layers:

1. **MOTD layer** — what you see when you SSH in. Replaces the boring default
   with an interactive dashboard showing host info, resource usage, services,
   SSL certs, and more.

2. **Terminal layer** — a set of shell functions and aliases that improve
   day-to-day work: file search, alias management, command chains, JSON
   viewing, persistent env vars, smart prompt, and so on.

3. **State layer** — persistent files that track your server's life: uptime
   records, login streaks, achievements, command history per project.

## Installation

### Manual install

```bash
git clone https://github.com/imsudoer/bashboard ~/.sutd
chmod +x ~/.sutd/motd.sh ~/.sutd/menu.sh
chmod +x ~/.sutd/modules/*.sh
chmod +x ~/.sutd/terminal/*.sh
```

Append to `~/.bashrc`:

```bash
if [ "$PS1" ] && [ -x ~/.sutd/motd.sh ]; then
    ~/.sutd/motd.sh
fi

for f in ~/.sutd/terminal/*.sh; do
    [ -r "$f" ] && source "$f"
done
```

Reload your shell:

```bash
exec bash
```

### What you should see

If installation succeeded, your first login will show:

- ASCII logo in the accent color (orange by default)
- An interactive slides menu (default `INTERFACE_MODE=1`)
- Use `←/→` to navigate slides, `q` to drop to shell

If you see plain text or errors — see [Troubleshooting](guides/troubleshooting.md).

## First Steps

### 1. Pick your interface mode

Edit `~/.sutd/info.conf`:

```bash
INTERFACE_MODE=1
```

Values:
- `0` — plain MOTD, all modules dumped to screen in order
- `1` — slides menu, navigate one section at a time (default)
- `2` — full TUI with sidebar and content panel

Try them all by changing the value and running `exec bash`.

### 2. Customize what's shown

In the same `info.conf`, toggle modules:

```bash
ENABLE_HOST=1
ENABLE_NETWORK=1
ENABLE_DOCKER=0
ENABLE_SSL_CERTS=1
```

Each `ENABLE_*` variable controls one module. Disabled modules don't run at
all and have zero performance cost.

### 3. Change colors

```bash
THEME_ACCENT="208"     # 208=orange, 75=blue, 46=matrix green
THEME_BG="237"         # background for panels
THEME_BG_ENABLED=1
```

See [Theming](08-theming.md) for full color palette.

### 4. Try a few commands

```bash
helpme                 # interactive help
note "deploy at 5pm"   # quick note
remember KEY=value     # persistent env var
serve                  # http server in current dir
svc                    # systemd service manager
al "docker ps -a" psa  # save an alias
psa                    # run it
```

### 5. Set up your services

Edit `~/.sutd/services.list`, one systemd unit per line:

```
ssh
nginx
docker
fail2ban
ufw
```

These appear in the **Services** slide and in `svc`.

## Concepts

### Modules vs. Terminal Extensions

| Modules                            | Terminal Extensions                  |
|------------------------------------|--------------------------------------|
| Live in `~/.sutd/modules/`         | Live in `~/.sutd/terminal/`          |
| Run **at login** only              | Run **every shell session**          |
| Produce **dashboard output**       | Provide **shell functions/aliases**  |
| Run in isolated subshells          | Source into current shell            |
| Numbered prefix sets order         | All sourced alphabetically           |
| Toggled by `ENABLE_<NAME>=1`       | Always sourced (delete to disable)   |

### Numeric prefix convention

Modules are prefixed with two digits (`10-host.sh`, `45-ssl-certs.sh`) so
their execution order is predictable. To re-order, just rename:

```bash
mv ~/.sutd/modules/60-docker.sh ~/.sutd/modules/35-docker.sh
```

### Naming → enable variable

The loader strips the numeric prefix, replaces `-` with `_`, uppercases,
and looks for `ENABLE_<NAME>`:

| Filename                  | Enable variable     |
|---------------------------|---------------------|
| `10-host.sh`              | `ENABLE_HOST`       |
| `45-ssl-certs.sh`         | `ENABLE_SSL_CERTS`  |
| `95-last-commands.sh`     | `ENABLE_LAST_COMMANDS` |

## Next Steps

- Read [Configuration](02-configuration.md) to fine-tune everything
- Read [Add a Custom Module](guides/add-custom-module.md) to write your first module
- Browse [Commands Reference](09-commands-reference.md) to see what's available