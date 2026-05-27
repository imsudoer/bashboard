---
title: "Commands Reference"
description: "Every Bashboard command, alias, and shortcut at a glance"
order: 9
group: "Bashboard"
badge: "CHEAT"
---
# Commands Reference
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
Every command available in Bashboard, grouped by category.

## Navigation

| Command             | Description                          |
|---------------------|--------------------------------------|
| `..`                | `cd ..`                              |
| `...`               | `cd ../..`                           |
| `....`              | `cd ../../..`                        |
| `.....`             | `cd ../../../..`                     |
| `mkcd <dir>`        | `mkdir -p <dir>` + `cd <dir>`        |
| `bookmark <name>`   | Save current directory under name    |
| `go <name>`         | Jump to bookmarked directory         |
| `go`                | List all bookmarks                   |
| `unbookmark <name>` | Remove bookmark                      |

### Examples

```bash
cd /var/www/api
bookmark api
cd /
go api               # back to /var/www/api

go                   # list all
# →   api      = /var/www/api
# →   logs     = /var/log/nginx
```

## Listing & files

| Command             | Description                          |
|---------------------|--------------------------------------|
| `ll`                | `ls -lah --color=auto`               |
| `la`                | `ls -A --color=auto`                 |
| `l`                 | `ls -CF --color=auto`                |
| `bigfiles [n]`      | Top N largest files in current dir   |
| `extract <archive>` | Auto-detect and unpack any archive   |
| `backup <file>`     | Copy file with timestamp suffix      |

### Supported archive formats

`extract` handles: `.tar.bz2` `.tar.gz` `.tar.xz` `.tar` `.tbz2` `.tgz`
`.bz2` `.gz` `.zip` `.rar` `.7z` `.Z`

## Search

| Command                  | Description                       |
|--------------------------|-----------------------------------|
| `f <pattern>`            | Find files by name in current dir |
| `f <pattern> <dir>`      | Find in specific dir              |
| `f -c "<text>"`          | grep file contents                |
| `f -c "<text>" <dir>`    | grep in specific dir              |
| `f -h <hours>`           | Modified in last N hours          |
| `f -d <days>`            | Modified in last N days           |
| `f -t f`                 | Files only                        |
| `f -t d`                 | Directories only                  |
| `hgrep <pattern>`        | Search command history            |
| `hrun <pattern>`         | Run last command matching pattern |

### Examples

```bash
f config                 # find files matching "config"
f config /etc            # in /etc
f -c "DATABASE_URL"      # grep for text
f -d 1 -t f              # files modified in last day
```

## Alias manager (`al`)

| Command                       | Description                       |
|-------------------------------|-----------------------------------|
| `al`                          | List all saved aliases            |
| `al "<cmd>" <name>`           | Save alias                        |
| `al <name>`                   | Run alias                         |
| `al <name> arg1 arg2`         | Run with positional args          |
| `al <name> -e`                | Edit alias inline                 |
| `al <name> -d`                | Delete alias                      |
| `al <name> --info`            | Show command without running      |
| `al -s <pattern>`             | Search                            |
| `al -e`                       | Edit aliases file in `$EDITOR`    |
| `al -h`                       | Help                              |

### Argument templating

```bash
al "systemctl {1} {2}" sysctl
sysctl restart nginx          # → systemctl restart nginx
sysctl stop docker            # → systemctl stop docker
```

## Command chains (`chain`)

| Command                         | Description                     |
|---------------------------------|---------------------------------|
| `chain` / `chain ls`            | List chains                     |
| `chain new <name>`              | Create empty chain              |
| `chain add <name> "<cmd>"`      | Append step                     |
| `chain run <name>`              | Execute all steps               |
| `chain run <name> -c`           | Confirm each step               |
| `chain run <name> --confirm`    | Same as `-c`                    |
| `chain show <name>`             | Show all steps                  |
| `chain edit <name>`             | Edit in `$EDITOR`               |
| `chain rmstep <name> <n>`       | Remove step N                   |
| `chain rm <name>`               | Delete entire chain             |
| `chain -h`                      | Help                            |

### Interactive run prompts (with `-c`)

```
[1/3] ▸ git pull
  run? [Y/n/s(kip)/q(uit)]: y

[2/3] ▸ npm install
  run? [Y/n/s/q]: s          ← skip this step
[3/3] ▸ pm2 restart api
  run? [Y/n/s/q]: y
```

## Help system (`helpme`)

| Command                  | Description                          |
|--------------------------|--------------------------------------|
| `helpme`                 | Interactive browser of topics        |
| `helpme <topic>`         | Show specific topic                  |
| `helpme -l`              | List all topics                      |
| `helpme -w [port]`       | Serve docs over HTTP                 |
| `helpme -h`              | Help for helpme itself               |
| `?`                      | Short alias for `helpme`             |

### Adding topics

Create a markdown file in `~/.sutd/data/helpme/`:

```bash
nano ~/.sutd/data/helpme/mytool.md
```

Format:

```markdown
# Title of Topic

Description paragraph.

## Subsection

- bullet point
- another bullet

## Examples

    command --flag arg
    another-command
```

Now `helpme mytool` shows it, and it appears in the web view at
`helpme -w`.

## Config editor (`cfg`)

| Command                    | Description                       |
|----------------------------|-----------------------------------|
| `cfg`                      | List registered configs           |
| `cfg <name>`               | Edit config in `$EDITOR`          |
| `cfg add <name> <path>`    | Register new config               |
| `cfg rm <name>`            | Unregister                        |
| `cfg backup <name>`        | Timestamped backup                |
| `cfg -h`                   | Help                              |

### Pre-registered configs

On first run, `cfg` auto-registers (if files exist):

| Name       | Path                       |
|------------|----------------------------|
| `nginx`    | `/etc/nginx/nginx.conf`    |
| `sshd`     | `/etc/ssh/sshd_config`     |
| `ssh`      | `~/.ssh/config`            |
| `bashrc`   | `~/.bashrc`                |
| `hosts`    | `/etc/hosts`               |
| `crontab`  | `/etc/crontab`             |
| `sutd`     | `~/.sutd/info.conf`        |

## Environment check (`env-check`)

| Command                    | Description                       |
|----------------------------|-----------------------------------|
| `env-check`                | List available presets            |
| `env-check <preset>`       | Run preset (e.g. `env-check py`)  |
| `env-check tool1 tool2`    | Check individual tools            |
| `env-check -l <preset>`    | Edit preset in `$EDITOR`          |

### Built-in presets

| Preset   | Checks                              |
|----------|-------------------------------------|
| `web`    | curl, wget, git, nginx              |
| `py`     | python3, pip3, git, curl            |
| `node`   | node, npm, git, curl                |
| `docker` | docker, docker-compose, git         |

## Persistent env (`remember`)

| Command                    | Description                         |
|----------------------------|-------------------------------------|
| `remember KEY=value`       | Save and export                     |
| `remember`                 | List (sensitive values masked)      |
| `remember -d KEY`          | Forget                              |
| `remember -c`              | Forget all                          |
| `remember -s KEY`          | Show raw value                      |
| `remember -e`              | Edit file in `$EDITOR`              |

Auto-masks values for keys containing `KEY`, `TOKEN`, `SECRET`, `PASS`.

## Notes (`note`)

| Command            | Description                                   |
|--------------------|-----------------------------------------------|
| `note "<text>"`    | Add timestamped note                          |
| `note`             | List all notes                                |
| `note -d <n>`      | Delete note line N                            |
| `note -e`          | Edit in `$EDITOR`                             |
| `note -c`          | Clear all notes                               |

## File watcher (`watch-reload`)

| Command                                      | Description                  |
|----------------------------------------------|------------------------------|
| `watch-reload <file> "<cmd>"`                | Watch and re-run on change   |
| `watch-reload <dir> "<cmd>"`                 | Recursive watch              |
| `watch-reload <target> "<cmd>" --bg`         | Background mode (nohup)      |

Requires `inotify-tools`. Background mode logs to `~/.sutd/data/watch-*.log`.

## Repeat last command (`redo`)

| Command            | Description                                   |
|--------------------|-----------------------------------------------|
| `redo`             | Re-run last command                           |
| `redo <arg>`       | Last command's verb + new args                |
| `redo s/old/new/`  | sed-replace in last command                   |

### Examples

```bash
ls /etc
redo                  # ls /etc again
redo /var             # ls /var
redo s|etc|var|       # ls /var
```

## Quick HTTP server (`serve`)

| Command                              | Description              |
|--------------------------------------|--------------------------|
| `serve`                              | Serve `.` on `0.0.0.0:8000` |
| `serve -p <port>`                    | Custom port              |
| `serve -i <ip>`                      | Bind to specific IP      |
| `serve -d <dir>`                     | Serve different dir      |
| `serve <port>`                       | Shortcut for `-p`        |
| `serve -h`                           | Help                     |

### Examples

```bash
serve                          # all interfaces, port 8000
serve 9000                     # port 9000
serve -i 127.0.0.1 -p 8080     # local only
serve -d /var/www -p 80        # serve /var/www
```

## Systemd manager (`svc`)

```bash
svc
```

Opens interactive menu of services from `~/.sutd/services.list`.

After selecting a service, choose: **start / stop / restart / status /
enable / disable / logs**.

## Project history (`projhist`)

| Command             | Description                              |
|---------------------|------------------------------------------|
| `projhist`          | List all project histories               |
| `projhist current`  | Show current project info                |
| `projhist mark`     | Mark current dir as project (creates `.sutd-project`) |
| `projhist unmark`   | Remove project marker                    |
| `projhist clear`    | Wipe history for current project         |
| `projhist -h`       | Help                                     |

Auto-switches `HISTFILE` when you `cd` into a directory containing `.git`
or `.sutd-project`.

## Statistics (`stats`)

```bash
stats
```

Shows:
- Total commands in history
- Top 10 most-used commands
- Logged commands count
- Current streak and record
- Achievements unlocked

## Visualization

| Command          | Description                                |
|------------------|--------------------------------------------|
| `peek <file>`    | Colorized JSON view                        |
| `cat x | peek`   | JSON from stdin                            |
| `qr "<text>"`    | QR code in terminal                        |
| `qr -s "<text>"` | Compact QR code                            |
| `qr -f <file>`   | QR for file contents                       |
| `qr -u "<text>"` | Print URL to online QR generator           |

## System info

| Command          | Description                              |
|------------------|------------------------------------------|
| `ports`          | Listening TCP ports (`ss -tlnp`)         |
| `myip`           | Local + public IP                        |
| `weather [city]` | Brief weather via wttr.in                |
| `calc "<expr>"`  | Calculator (via `bc -l`)                 |

## Safety wrappers

These wrap built-ins with confirmation prompts:

| Command              | When prompted                              |
|----------------------|--------------------------------------------|
| `rm -rf <path>`      | Always (level depends on `SAFE_RM_LEVEL`)  |
| `rm <critical>`      | Always level 3 (random code)               |
| `chmod -R 777 ...`   | Type `yes`                                 |
| `chown <critical>`   | Type random code                           |
| `dd ...`             | Type random code                           |
| `mkfs.*`             | Type random code                           |
| `iptables -F`        | Type `yes`                                 |

To bypass:

```bash
command rm -rf /tmp/test       # original rm
\rm -rf /tmp/test              # same effect
```

## Internal/utility

| Command           | Description                              |
|-------------------|------------------------------------------|
| `apply_theme`     | Re-derive theme colors (after editing)   |
| `is_int <val>`    | Test if integer                          |
| `get_cpu_usage`   | Current CPU% (sleeps 300ms)              |

## Quick reference card

Print and pin near your terminal:

```
NAVIGATION       ALIAS MANAGER          CHAINS
  ..               al "cmd" name          chain new <n>
  mkcd <dir>       al name [args]         chain add <n> "cmd"
  bookmark <n>     al name -e             chain run <n> [-c]
  go <n>           al name -d             chain show <n>

UTILITIES        SAFETY                 INFO
  extract f        rm -rf x (confirm)    ports
  backup f         dd (confirm)          myip
  bigfiles         remember KEY=val      weather
  serve [port]     note "text"           stats

PROJECT          SEARCH                 HELP
  projhist         f pattern             helpme
  cfg name         f -c "text"           helpme -w
  svc              hgrep pattern         helpme <topic>
```