---
title: "Multi-Server SSH Workflow"
description: "Manage many servers with named hosts, sync configs, and per-server theming"
order: 12
group: "Bashboard"
badge: "RECIPE"
---
# Guide: Multi-Server SSH Workflow
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
If you manage more than one server, Bashboard's state is per-server — but
you can sync configs, share aliases, and jump between hosts efficiently.

## Setting up the SSH menu tool

Create `~/.sutd/terminal/s.sh`:

```bash
#!/bin/bash

__SSH_HOSTS="$HOME/.sutd/data/ssh_hosts.dat"
mkdir -p "$(dirname "$__SSH_HOSTS")"
touch "$__SSH_HOSTS"

s() {
    local cmd="$1"
    
    case "$cmd" in
        add)
            local name="$2"; local target="$3"
            [ -z "$name" ] || [ -z "$target" ] && {
                echo "  usage: s add <name> <user@host[:port]>"
                return 1
            }
            sed -i "/^${name}|/d" "$__SSH_HOSTS"
            echo "${name}|${target}" >> "$__SSH_HOSTS"
            echo -e "  \033[32m✓\033[0m saved: $name → $target"
            ;;
        rm)
            sed -i "/^${2}|/d" "$__SSH_HOSTS"
            echo -e "  \033[31m✗\033[0m removed: $2"
            ;;
        ls|list)
            if [ ! -s "$__SSH_HOSTS" ]; then
                echo "  (no hosts) — add with: s add <name> <user@host>"
                return
            fi
            echo -e "  \033[37mSSH hosts:\033[0m"
            while IFS='|' read -r name target; do
                printf "    \033[38;5;208m▸\033[0m %-15s \033[90m%s\033[0m\n" "$name" "$target"
            done < "$__SSH_HOSTS"
            ;;
        -h|--help)
            cat << 'EOF'
  s — SSH host manager

  s                       interactive menu
  s <name>                connect by name
  s add <name> <target>   save host (user@host or user@host:port)
  s rm <name>             remove
  s ls                    list all
EOF
            ;;
        "")
            if [ ! -s "$__SSH_HOSTS" ]; then
                echo "  no hosts saved"
                return 1
            fi
            local hosts=()
            while IFS='|' read -r name target; do
                hosts+=("${name}|${target}")
            done < "$__SSH_HOSTS"
            
            local i=1
            echo ""
            for h in "${hosts[@]}"; do
                local n="${h%%|*}"
                local t="${h##*|}"
                printf "  \033[90m%2d)\033[0m \033[38;5;208m%-15s\033[0m \033[90m%s\033[0m\n" "$i" "$n" "$t"
                i=$((i+1))
            done
            echo ""
            read -p "  Select: " choice
            
            [[ "$choice" =~ ^[qQ]$ ]] && return
            [[ ! "$choice" =~ ^[0-9]+$ ]] && return 1
            [ "$choice" -lt 1 ] || [ "$choice" -gt "${#hosts[@]}" ] && return 1
            
            local selected="${hosts[$((choice-1))]}"
            __s_connect "${selected##*|}"
            ;;
        *)
            local entry
            entry=$(grep "^${cmd}|" "$__SSH_HOSTS")
            [ -z "$entry" ] && { echo "  no such host: $cmd"; return 1; }
            __s_connect "${entry##*|}"
            ;;
    esac
}

__s_connect() {
    local target="$1"
    local port=""
    if [[ "$target" == *:* ]]; then
        port="-p ${target##*:}"
        target="${target%%:*}"
    fi
    echo -e "  \033[90m→\033[0m ssh $port $target"
    ssh $port "$target"
}

_s_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    if [ "$COMP_CWORD" -eq 1 ]; then
        local names
        names=$(cut -d'|' -f1 "$__SSH_HOSTS" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$names add rm ls -h" -- "$cur") )
    elif [ "$prev" = "rm" ]; then
        local names
        names=$(cut -d'|' -f1 "$__SSH_HOSTS" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$names" -- "$cur") )
    fi
}
complete -F _s_complete s
```

Reload and use:

```bash
exec bash

s add prod root@1.2.3.4
s add dev me@dev.local:2222
s add db postgres@db.internal

s                   # interactive picker
s prod              # direct connect
s ls                # list all
```

## Syncing your Bashboard across servers

### Strategy 1: Git-based

Put your `~/.sutd/` (without `data/`) into a private git repo.

On the master server:

```bash
cd ~/.sutd
git init
echo "data/" > .gitignore
git add .
git commit -m "initial bashboard config"
git remote add origin git@github.com:you/dotfiles.git
git push -u origin main
```

On every new server:

```bash
git clone git@github.com:you/dotfiles.git ~/.sutd
# add bashrc lines from getting-started
exec bash
```

### Strategy 2: Push-only sync tool

Create `~/.sutd/terminal/sync.sh`:

```bash
#!/bin/bash

bb-push() {
    local host="$1"
    [ -z "$host" ] && { echo "usage: bb-push <user@host>"; return 1; }
    
    echo -e "  \033[90m→\033[0m syncing to $host"
    
    rsync -avz --delete \
        --exclude='data/' \
        --exclude='docs/' \
        ~/.sutd/ "$host":~/.sutd/
    
    ssh "$host" "chmod +x ~/.sutd/motd.sh ~/.sutd/menu.sh ~/.sutd/modules/*.sh ~/.sutd/terminal/*.sh"
    
    echo -e "  \033[32m✓\033[0m synced"
}

bb-push-all() {
    [ ! -s "$HOME/.sutd/data/ssh_hosts.dat" ] && { echo "no hosts"; return 1; }
    
    while IFS='|' read -r name target; do
        echo ""
        echo -e "  \033[38;5;208m=== $name ($target) ===\033[0m"
        bb-push "${target%:*}"
    done < "$HOME/.sutd/data/ssh_hosts.dat"
}
```

Usage:

```bash
bb-push prod
bb-push-all          # push to every host in s list
```

### Strategy 3: Selective sync

For just a few files (e.g. you added a useful alias on one server):

```bash
scp ~/.sutd/terminal/al.sh prod:~/.sutd/terminal/
ssh prod 'exec bash'
```

## Per-server overrides

You want the same `info.conf` everywhere, but specific overrides per
server. Solution: a sourced override file.

In `info.conf`:

```bash
THEME_ACCENT="208"
THEME_BG="237"
INTERFACE_MODE=1

# ... usual config ...

# Server-local overrides
[ -f "$HOME/.sutd/info.local.conf" ] && source "$HOME/.sutd/info.local.conf"
```

Then on each server, create `~/.sutd/info.local.conf`:

```bash
# On production:
THEME_ACCENT="196"        # red, so I never confuse it with staging
ENABLE_DOCKER=0           # no docker here
```

```bash
# On staging:
THEME_ACCENT="220"        # yellow
SAFE_RM_LEVEL=1           # less paranoid
```

Add `info.local.conf` to your `.gitignore`.

## Visual server identification

Make each server look different so you never run a destructive command on
the wrong one. Combine:

1. **Different `THEME_ACCENT`** per server type
   - Red for production
   - Yellow for staging
   - Green for development
   - Blue for testing

2. **Hostname-based PS1 highlight** in `prompt.sh`:

   ```bash
   case "$(hostname)" in
       prod*) HOST_COLOR='$$\033[38;5;196m$$' ;;  # red
       stage*) HOST_COLOR='$$\033[38;5;220m$$' ;; # yellow
       *) HOST_COLOR='$$\033[38;5;208m$$' ;;
   esac
   ```

3. **Banner in MOTD** — add a module `~/.sutd/modules/01-banner.sh`:

   ```bash
   #!/bin/bash
   case "$(hostname)" in
       prod*)
           echo -e "${COLOR_RED}"
           cat << 'EOF'
     ╔════════════════════════════════╗
     ║       PRODUCTION SERVER        ║
     ║      THINK BEFORE YOU TYPE     ║
     ╚════════════════════════════════╝
   EOF
           echo -e "${COLOR_RESET}"
           ;;
   esac
   ```

   Enable with `ENABLE_BANNER=1`.

## Multi-server commands

Run the same command across all your servers in one go:

```bash
bb-run-all() {
    [ -z "$1" ] && { echo "usage: bb-run-all '<command>'"; return 1; }
    
    while IFS='|' read -r name target; do
        echo -e "\n\033[38;5;208m=== $name ($target) ===\033[0m"
        ssh -o ConnectTimeout=5 "${target%:*}" "$*"
    done < "$HOME/.sutd/data/ssh_hosts.dat"
}
```

Usage:

```bash
bb-run-all "uptime"
bb-run-all "df -h /"
bb-run-all "systemctl status nginx --no-pager | head -3"
```

For paralleled execution, add `&` and `wait`:

```bash
bb-run-all-parallel() {
    [ -z "$1" ] && return 1
    local pids=()
    
    while IFS='|' read -r name target; do
        (
            out=$(ssh -o ConnectTimeout=5 "${target%:*}" "$*" 2>&1)
            echo -e "\n\033[38;5;208m=== $name ===\033[0m\n$out"
        ) &
        pids+=($!)
    done < "$HOME/.sutd/data/ssh_hosts.dat"
    
    wait "${pids[@]}"
}
```

## Best practices

- **Tag your hosts** descriptively: `prod-web-1`, not `server1`
- **Always test on dev first** when pushing config changes
- **Keep `data/` local** — never sync it. Each server's state is unique.
- **Use `bb-push` after `git pull`** so all servers stay in sync
- **Test the connection menu** weekly — stale entries are a foot-gun