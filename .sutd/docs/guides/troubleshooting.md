---
title: "Troubleshooting"
description: "Common Bashboard issues and how to fix them"
order: 14
group: "Bashboard"
badge: "FIX"
---
# Troubleshooting
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
Common issues and how to fix them.

## "Numbers appearing in my prompt"

Symptom:

```
30979463097946root30979463097946@30979463097946onlysq30979463097946:30979463097946~30979463097946
```

**Cause:** Broken `PS1` — escape sequences not wrapped in `$$ $$`.

**Fix:**
```bash
exec bash
```

A fresh shell loads the corrected `prompt.sh`. If the problem persists,
check that `~/.sutd/terminal/prompt.sh` uses single-quoted PS1 (look for
`PS1='$$\033...'`).

If still broken:
```bash
unset PROMPT_COMMAND
PS1='\u@\h:\w \$ '
exec bash
```

## Bashboard doesn't load at all

**Check 1**: Is the entry in `~/.bashrc`?

```bash
grep sutd ~/.bashrc
```

Should show:

```bash
if [ "$PS1" ] && [ -x ~/.sutd/motd.sh ]; then
    ~/.sutd/motd.sh
fi

for f in ~/.sutd/terminal/*.sh; do
    [ -r "$f" ] && source "$f"
done
```

**Check 2**: Is `motd.sh` executable?

```bash
ls -la ~/.sutd/motd.sh
```

If not:
```bash
chmod +x ~/.sutd/motd.sh
```

**Check 3**: Run it manually:

```bash
~/.sutd/motd.sh
```

If errors appear, they'll tell you what's missing.

## A specific module crashes

**Find the culprit:**

```bash
for m in ~/.sutd/modules/*.sh; do
    echo "=== $m ==="
    bash "$m" 2>&1 | tail -5
done
```

**Disable it temporarily** in `info.conf`:

```bash
ENABLE_BROKEN_MODULE=0
```

**Debug it:**

```bash
bash -x ~/.sutd/modules/45-ssl-certs.sh 2>&1 | head -50
```

## SSL certs module shows nothing

```bash
# Are you root?
id -u

# Does the directory exist?
ls /etc/letsencrypt/live/

# Run manually with debug:
bash -x ~/.sutd/modules/45-ssl-certs.sh 2>&1 | head -30
```

If you're not root, set up passwordless sudo for openssl in
`/etc/sudoers.d/bashboard`:

```
youruser ALL=(ALL) NOPASSWD: /usr/bin/find /etc/letsencrypt/*, /usr/bin/openssl
```

## "command not found" for `al`, `chain`, `helpme`, etc

The terminal extensions aren't being loaded.

**Check:**

```bash
declare -f al | head -1
```

If empty, force reload:

```bash
for f in ~/.sutd/terminal/*.sh; do source "$f"; done
```

If that works but it breaks on next login, check `.bashrc` for the
sourcing block.

## `Ctrl+G` does nothing

```bash
bind -p | grep '\\C-g'
```

Should show:

```
"\C-g": __ctx_menu_wrapper
```

If not, source the file:

```bash
source ~/.sutd/terminal/ctx-menu.sh
```

If you want a different key, edit `info.conf`:

```bash
CTX_MENU_BIND="\C-o"
```

And `exec bash`.

## TUI mode displays garbage

Symptoms: random characters, broken boxes, weird positions.

**Cause:** Terminal doesn't support what `tput` outputs.

**Check `$TERM`:**

```bash
echo $TERM
```

Should be one of: `xterm-256color`, `screen-256color`, `tmux-256color`,
`alacritty`, `kitty`, etc.

If it's `linux`, `vt100`, `dumb` — your terminal can't do TUI.

**Fix:** Fall back to slides mode:

```bash
# In info.conf
INTERFACE_MODE=1
```

## Login is slow

Time it:

```bash
time exec bash
```

If > 2 seconds, find the slow module:

```bash
for m in ~/.sutd/modules/*.sh; do
    printf "%-40s " "$(basename $m)"
    { time bash "$m" >/dev/null 2>&1 ; } 2>&1 | grep real
done
```

Common offenders:

- `45-ssl-certs.sh` if you have many certs
- `60-docker.sh` if docker daemon is slow
- `80-updates.sh` if `journalctl` is huge
- Anything doing `curl` without `timeout`

Disable in `info.conf`:

```bash
ENABLE_SSL_CERTS=0
ENABLE_DOCKER=0
```

See [Performance Tuning](performance-tuning.md) for more.

## `helpme -w` won't bind to 0.0.0.0

**Check:**

```bash
grep HELPME ~/.sutd/info.conf
```

Should show:

```
HELPME_BIND="0.0.0.0"
```

If correct, fresh-source the file. The function loads `info.conf` on each
invocation, so no `exec bash` should be needed — but if it doesn't pick
up, restart your shell.

## Achievements show "Total unlocked: 0" forever

`51-achievements.sh` writes to `~/.sutd/data/achievements.dat`.

```bash
ls -la ~/.sutd/data/achievements.dat
cat ~/.sutd/data/achievements.dat
```

If the file is missing, check write permissions:

```bash
touch ~/.sutd/data/achievements.dat
ls -la ~/.sutd/data/
```

Make sure your user owns `~/.sutd/data/`:

```bash
chown -R $USER:$USER ~/.sutd/data/
```

## Service status doesn't show duration

Module `50-services.sh` calls `systemctl show <svc> --property=...`. If
your `systemctl` doesn't support this (rare), the duration is omitted but
the service still shows.

**Check:**

```bash
systemctl show ssh --property=ActiveEnterTimestamp --value
```

Should print a timestamp like `Mon 2026-05-25 10:23:01 UTC`.

## Per-project history isn't switching

```bash
projhist current
```

If it says "not in a project":

```bash
cd ~/projects/myproject
ls -la .git .sutd-project
```

You need either `.git/` (auto-detected) or `.sutd-project` file (manual).
Create it:

```bash
projhist mark
```

Then `cd` out and back in:

```bash
cd /tmp
cd ~/projects/myproject
projhist current
```

## "command not found: complete"

Tab completion uses `complete -F`, which needs bash. Check:

```bash
echo $BASH_VERSION
```

Must be 4.0+. Bashboard officially supports bash 5+. Older versions may
have partial functionality.

## fish-like autosuggestions

Bashboard doesn't ship fish-like grey-text autocomplete. The bash readline
library doesn't expose enough hooks for it natively.

**Options:**

1. **Use `Ctrl+R`** for reverse history search — built into bash
2. **Install `bash-preexec.sh`** — a single file that adds `preexec` hook
3. **Install `ble.sh`** — full fish-like behavior, single-file install:

   ```bash
   curl -L -o ~/.local/share/blesh.tar.xz \
       https://github.com/akinomyoga/ble.sh/releases/latest/download/ble-nightly.tar.xz
   tar -xJf ~/.local/share/blesh.tar.xz -C ~/.local/share/
   ```

   Add to `~/.bashrc` **before** Bashboard:

   ```bash
   [ -f ~/.local/share/ble.sh/ble.sh ] && source ~/.local/share/ble.sh/ble.sh --attach=none
   
   # ... existing bashrc ...
   
   [[ ${BLE_VERSION-} ]] && ble-attach
   ```

   Note: `ble.sh` may conflict with `PROMPT_COMMAND` chains. Test
   carefully.

## After install, terminal looks unstyled

```bash
echo $TERM
```

Should be `xterm-256color` or similar. If it's `dumb` or `linux`, your
SSH session is downgraded. Fix in your SSH config or `.bashrc`:

```bash
export TERM=xterm-256color
```

## Modules show `: integer expression expected`

Some value passed to `[ "$x" -gt 5 ]` isn't an integer. Almost always
because a command returned empty.

**Fix in your module:**

```bash
X=$(some-command)
is_int "$X" || X=0
[ "$X" -gt 5 ] && ...
```

Built-in modules have this fixed; if you wrote a custom one, add the
guard.

## Reset everything

To start over with default state but keep config:

```bash
rm -rf ~/.sutd/data/
mkdir -p ~/.sutd/data/
exec bash
```

To completely reinstall:

```bash
mv ~/.sutd ~/.sutd.broken
git clone https://github.com/yourname/bashboard ~/.sutd
exec bash
```

## Getting more help

- Read [Architecture](../03-architecture.md) for how things fit together
- Read [Modules](../04-modules.md) and [Terminal Extensions](../05-terminal-extensions.md)
- Run `helpme` for the interactive help
- Run `helpme -w` to read docs in a browser