---
title: "Data Storage"
description: "Where Bashboard stores persistent state and how to back it up"
order: 7
group: "Bashboard"
---
# Data Storage
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
Bashboard keeps all persistent state in `~/.sutd/data/`. This directory
is the "memory" of your installation — login streaks, achievements,
aliases, command history per project, etc.

## Why a separate directory?

- **Backup-friendly** — copy `data/` to preserve your state
- **Reset-friendly** — `rm -rf data/` resets everything but keeps config
- **Git-friendly** — add `data/` to `.gitignore` when sharing your setup

## File inventory

### Single-value files

These store a single value or simple key=value pairs.

#### `data/streak.dat`

Login streak state.

```
last=2026-05-27
streak=12
max=45
```

| Key      | Meaning                       |
|----------|-------------------------------|
| `last`   | Date of last login            |
| `streak` | Current consecutive days      |
| `max`    | All-time record               |

Updated by `47-streak.sh` once per day.

#### `data/uptime_record.dat`

A single integer — longest uptime ever observed, in seconds.

```
3456789
```

Updated by `48-uptime-record.sh` every login.

#### `data/install_date.dat`

A single Unix timestamp — when the server was first observed by Bashboard
(approximation of OS install date).

```
1709251200
```

Created once by `49-server-age.sh` and never modified.

#### `data/cpu_history.dat`

One CPU% value per line, one per login. Used by `53-ascii-graph.sh`.

```
12
8
35
67
22
```

Trimmed to the last N values (terminal width-dependent) each run.

### Multi-line text files

#### `data/notes.txt`

Free-form notes added via `note "..."`. One per line with timestamp.

```
[2026-05-27 14:32] купить SSL для домена
[2026-05-27 18:01] deploy сделать в пятницу
[2026-05-28 09:15] проверить бэкап
```

Managed by the `note` command (see [Commands Reference](09-commands-reference.md)).

#### `data/last_commands.log`

Recent commands from previous sessions. Pipe-separated.

```
2026-05-27 14:32|systemctl restart nginx
2026-05-27 14:35|docker compose up -d
2026-05-27 14:40|tail -f /var/log/nginx/access.log
```

Capped at 100 lines. Updated by the command logger hook in `mods.sh`.

#### `data/achievements.dat`

One unlocked achievement ID per line.

```
uptime_1d
uptime_7d
streak_3
age_30
```

Updated by `51-achievements.sh` when conditions are met.

### Key-value files

These are sourceable bash files (`key=value` per line).

#### `data/aliases.dat`

Saved aliases from `al`. Format: `name|command`.

```
stapi|systemctl restart api
psa|docker ps -a
sysctl|systemctl {1} {2}
```

| Field   | Meaning                                |
|---------|----------------------------------------|
| `name`  | Alias name                             |
| `command` | Command template, `{N}` for args     |

Managed by `al`.

#### `data/bookmarks`

Directory bookmarks from `bookmark`/`go`.

```
api=/var/www/api
logs=/var/log/nginx
configs=/etc/nginx
```

Format: `name=absolute_path`.

#### `data/cfgs.dat`

Registered config files for `cfg`. Format: `name|path`.

```
nginx|/etc/nginx/nginx.conf
sshd|/etc/ssh/sshd_config
bashrc|/root/.bashrc
sutd|/root/.sutd/info.conf
```

#### `data/remembered.dat`

Persistent environment variables from `remember`. Plain `KEY=VALUE`.

```
API_KEY=sk-abc123
DATABASE_URL=postgres://...
DEBUG_MODE=1
```

**This file is sourced** on shell startup. Don't add malformed lines.

### Directory-based storage

#### `data/chains/`

One file per chain. Each line is one step.

```
~/.sutd/data/chains/deploy:
git pull
npm install
pm2 restart api

~/.sutd/data/chains/backup:
tar -czf /backups/db-$(date +%F).tar.gz /var/lib/postgresql
rsync -av /backups/ user@remote:/backups/
```

Managed by `chain`.

#### `data/helpme/`

Markdown files for the help center. Filenames become topic names.

```
~/.sutd/data/helpme/
├── aliases.md
├── chains.md
├── navigation.md
├── notes.md
├── safety.md
├── services.md
└── utils.md
```

You can add your own. They'll appear in `helpme` and `helpme -w`.

See [Add a Custom Module](guides/add-custom-module.md) for the simple
markdown format used.

#### `data/env-checks/`

One file per preset. Each line is one tool to verify.

```
~/.sutd/data/env-checks/py.txt:
python3
pip3
git
curl

~/.sutd/data/env-checks/docker.txt:
docker
docker-compose
git
```

Managed by `env-check`.

#### `data/proj_histories/`

Per-project bash history files. Filenames are md5 hashes of project paths,
with companion `.label` files storing the original path.

```
~/.sutd/data/proj_histories/
├── 3a7f9c2e1b8d.history
├── 3a7f9c2e1b8d.label      # contains: /var/www/api
├── 8e2d1f4a9c3b.history
└── 8e2d1f4a9c3b.label      # contains: /root/projects/dotfiles
```

Switched automatically by `proj-history.sh` when you `cd` into a project.

## File sizes and growth

Typical sizes after a year of use:

| File                            | Size           |
|---------------------------------|----------------|
| `streak.dat`                    | ~50 bytes      |
| `uptime_record.dat`             | ~10 bytes      |
| `cpu_history.dat`               | ~200 bytes     |
| `last_commands.log`             | ~10 KB         |
| `notes.txt`                     | depends on use |
| `achievements.dat`              | ~200 bytes     |
| `aliases.dat`                   | ~1 KB          |
| `chains/*`                      | ~500 bytes ea  |
| `proj_histories/*.history`      | ~10–100 KB ea  |

Total expected size: **under 5 MB** for years of normal use.

## Backup

Recommended backup approach:

```bash
tar -czf bashboard-data-$(date +%F).tar.gz -C ~ .sutd/data .sutd/info.conf .sutd/services.list
```

This captures **state** + **config**, excluding the modules/terminal code
(which lives in git anyway).

Restore:

```bash
tar -xzf bashboard-data-2026-05-27.tar.gz -C ~
```

## Reset

To reset specific subsystems:

```bash
# Reset all achievements
rm ~/.sutd/data/achievements.dat

# Reset streak (start over)
rm ~/.sutd/data/streak.dat

# Reset uptime record
rm ~/.sutd/data/uptime_record.dat

# Reset everything (keeps config)
rm -rf ~/.sutd/data/
mkdir ~/.sutd/data/
```

The next login will recreate any required files.

## Migration between servers

To move your Bashboard state to a new server:

1. **On old server**: `tar -czf bb.tar.gz -C ~ .sutd`
2. **Transfer**: `scp bb.tar.gz newserver:`
3. **On new server**: `tar -xzf bb.tar.gz -C ~`
4. **Re-add to `.bashrc`** (the lines from [Getting Started](01-getting-started.md))
5. **`exec bash`**

Note that `install_date.dat` will preserve your **old server's** age. If
you want it to reflect the new server, delete the file before logging in.

## Privacy considerations

`data/` may contain:

- **`remembered.dat`** — API keys, tokens, passwords. **Protect this file:**
  ```bash
  chmod 600 ~/.sutd/data/remembered.dat
  ```
- **`last_commands.log`** — commands you ran (may contain sensitive args)
- **`proj_histories/*.history`** — full bash history per project
- **`notes.txt`** — whatever you wrote down

If you share screenshots or hand over your setup, sanitize these first.

## Concurrent access

Bashboard isn't designed for multiple simultaneous logins writing to the
same data files. If you SSH in twice at once:

- **Streak**: both runs may double-increment (rare race condition)
- **Achievements**: harmless — duplicates would just be re-added
- **Commands log**: lines may interleave but file stays valid
- **Project history**: works correctly (each shell has its own `HISTFILE`)

For team servers with multiple users, each user gets their own `~/.sutd/`
under their `$HOME`. No conflicts.

## Inspecting state from the shell

Some quick commands to see what's stored:

```bash
# Current streak
cat ~/.sutd/data/streak.dat

# All achievements
cat ~/.sutd/data/achievements.dat | wc -l
cat ~/.sutd/data/achievements.dat

# All bookmarks
cat ~/.sutd/data/bookmarks

# All aliases
cat ~/.sutd/data/aliases.dat | column -t -s'|'

# Notes
cat ~/.sutd/data/notes.txt
```