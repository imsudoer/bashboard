---
title: "Performance Tuning"
description: "Measure, profile, and optimize Bashboard startup for fast SSH logins"
order: 15
group: "Bashboard"
badge: "SPEED"
---
# Performance Tuning
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
Bashboard's default config takes about 0.5–1.0 seconds to display on a
typical VDS. For most use cases that's fine. If you log into the server
many times a day, or you're on a slow connection, here's how to make it
nearly instant.

## Measuring startup time

```bash
time exec bash
```

Or to time just Bashboard:

```bash
time ~/.sutd/motd.sh
```

For module-by-module breakdown:

```bash
for m in ~/.sutd/modules/*.sh; do
    printf "%-40s " "$(basename $m)"
    { time bash "$m" >/dev/null 2>&1 ; } 2>&1 | grep real
done
```

Output looks like:

```
10-host.sh                               real    0m0.012s
20-network.sh                            real    0m0.501s  ← slow
30-system.sh                             real    0m0.008s
40-resources.sh                          real    0m0.310s  ← CPU sample
45-ssl-certs.sh                          real    0m0.087s
46-top-processes.sh                      real    0m0.145s
...
```

## Common slow culprits

| Module                | Reason                            | Fix                              |
|-----------------------|-----------------------------------|----------------------------------|
| `20-network.sh`       | `curl ifconfig.me`                | Set `SHOW_EXTERNAL_IP=0`         |
| `40-resources.sh`     | `get_cpu_usage` sleeps 300ms      | Accept it or skip module         |
| `45-ssl-certs.sh`     | Many certs, openssl per cert      | Cache results in cron            |
| `52-progress-bars.sh` | Another `get_cpu_usage` call      | Disable if `40` is enabled       |
| `53-ascii-graph.sh`   | Yet another `get_cpu_usage`       | Disable if `40` is enabled       |
| `60-docker.sh`        | Docker daemon slow on big setups  | Cache `docker ps` for 60s        |
| `70-security.sh`      | Reads `/var/log/auth.log` fully   | Set fail2ban-only mode           |
| `80-updates.sh`       | `journalctl` if huge journal      | Increase max age or skip         |
| `90-footer.sh`        | `curl wttr.in`                    | Set `ENABLE_FOOTER=0`            |

## Strategy 1: Disable expensive modules

In `~/.sutd/info.conf`:

```bash
ENABLE_NETWORK=1
SHOW_EXTERNAL_IP=0           # no curl call

ENABLE_SSL_CERTS=0           # only if you don't need it
ENABLE_DOCKER=0
ENABLE_FOOTER=0

# Eliminate redundant CPU sampling — pick one:
ENABLE_RESOURCES=1
ENABLE_PROGRESS_BARS=0       # also calls get_cpu_usage
ENABLE_ASCII_GRAPH=0
```

This typically cuts startup time by 60%.

## Strategy 2: Cache slow data

For data that doesn't change often (SSL expiry, weather, docker counts),
update via cron and read from a cache file in your module.

**Example: cached SSL check**

Create the cache updater:

```bash
nano ~/.sutd/data/cache/ssl-cache.sh
mkdir -p ~/.sutd/data/cache
chmod +x ~/.sutd/data/cache/ssl-cache.sh
```

```bash
#!/bin/bash

CACHE_FILE="$HOME/.sutd/data/cache/ssl.txt"
> "$CACHE_FILE.tmp"

NOW_EPOCH=$(date +%s)

for cert in /etc/letsencrypt/live/*/cert.pem; do
    [ -f "$cert" ] || continue
    domain=$(basename "$(dirname "$cert")")
    end_date=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
    [ -z "$end_date" ] && continue
    end_epoch=$(date -d "$end_date" +%s 2>/dev/null)
    days=$(( (end_epoch - NOW_EPOCH) / 86400 ))
    echo "${domain}|${days}" >> "$CACHE_FILE.tmp"
done

mv "$CACHE_FILE.tmp" "$CACHE_FILE"
```

Add to crontab:

```
0 * * * * /root/.sutd/data/cache/ssl-cache.sh
```

Replace `45-ssl-certs.sh` to read from cache:

```bash
#!/bin/bash

CACHE_FILE="$HOME/.sutd/data/cache/ssl.txt"
WARN_DAYS="${SSL_WARN_DAYS:-14}"

[ -r "$CACHE_FILE" ] || exit 0

divider
section "SSL Certificates: ${COLOR_GRAY}(cached)${COLOR_RESET}"

while IFS='|' read -r domain days; do
    [ -z "$domain" ] && continue
    
    if [ "$days" -lt 0 ]; then
        COLOR="$COLOR_RED"; ICON="✗"; STATUS="EXPIRED"
    elif [ "$days" -lt "$WARN_DAYS" ]; then
        COLOR="$COLOR_YELLOW"; ICON="⚠"; STATUS="${days}d left"
    else
        COLOR="$COLOR_GREEN"; ICON="●"; STATUS="${days}d left"
    fi
    
    printf "    ${COLOR}${ICON}${COLOR_RESET} %-30s ${COLOR_GRAY}%s${COLOR_RESET}\n" "$domain" "$STATUS"
done < "$CACHE_FILE"
```

Same approach works for `docker ps`, `journalctl`, weather, etc.

## Strategy 3: Async modules (advanced)

Run slow modules in background, show "loading" placeholder, update later.
This requires more work — typically you'd:

1. Render plain MOTD with placeholder text
2. Fire background `bash module &`
3. When done, update terminal output (tricky)

Simpler approach: don't show slow data at login. Provide a command:

```bash
nano ~/.sutd/terminal/fresh.sh
```

```bash
fresh() {
    case "$1" in
        ssl)     bash ~/.sutd/modules/45-ssl-certs.sh ;;
        docker)  bash ~/.sutd/modules/60-docker.sh ;;
        all)     ~/.sutd/motd.sh ;;
        *)       echo "  usage: fresh ssl|docker|all" ;;
    esac
}
```

Now expensive modules are off by default, and you call `fresh ssl` when
you actually want it.

## Strategy 4: Minimal MOTD

Skip the MOTD entirely and use a fast prompt:

```bash
INTERFACE_MODE=0

ENABLE_HOST=1
ENABLE_SYSTEM=1
ENABLE_RESOURCES=0
ENABLE_PROGRESS_BARS=0
ENABLE_ASCII_GRAPH=0
ENABLE_SSL_CERTS=0
ENABLE_TOP_PROCESSES=0
ENABLE_DOCKER=0
ENABLE_SECURITY=0
ENABLE_UPDATES=0
ENABLE_LAST_COMMANDS=0
ENABLE_SERVICES=0
ENABLE_ACHIEVEMENTS=0
ENABLE_STREAK=0
ENABLE_UPTIME_RECORD=0
ENABLE_SERVER_AGE=0
ENABLE_NETWORK=0
```

This gives you:

```
  Welcome to OnlySq Infrastructure
  --------------------------------------------------
  Host      : onlysq.example.com
  OS        : Ubuntu 22.04.5 LTS
  Kernel    : 5.15.0-91-generic
  Uptime    : 12 days, 3 hours
  Load      : 0.45, 0.32, 0.28
  Users     : 1 logged in
  Procs     : 287 total
```

In <100ms.

For full data, run:

```bash
~/.sutd/menu.sh           # interactive menu
~/.sutd/terminal/tui.sh   # full TUI
```

## Terminal extension overhead

Terminal scripts source on every login. Most are small (~10ms total), but
if you've added many, time them:

```bash
for f in ~/.sutd/terminal/*.sh; do
    printf "%-30s " "$(basename $f)"
    { time source "$f" >/dev/null 2>&1 ; } 2>&1 | grep real
done
```

Common slow patterns:

```bash
# BAD — runs every login
EXTERNAL_DATA=$(curl -s https://api.example.com/data)

# BAD — runs every login  
LARGE_LIST=$(find / -name "something" 2>/dev/null)

# GOOD — runs only when called
mytool() {
    local data
    data=$(curl -s https://api.example.com/data)
}
```

Top-level code runs at source time. Functions only run when called.

## Network calls in modules

Any `curl` or `wget` without `timeout` can hang your login indefinitely
if the network is down. Always:

```bash
EXT_IP=$(timeout 2 curl -s ifconfig.me 2>/dev/null)
[ -n "$EXT_IP" ] && field "Public IP" "$EXT_IP"
```

The `timeout 2` ensures max 2 seconds. The `&& field` ensures empty
responses don't print anything.

## Profile your prompt

If `PROMPT_COMMAND` is slow (git status on huge repos, etc), every
keypress feels laggy.

Time it:

```bash
{ time eval "$PROMPT_COMMAND" ; }
```

If > 100ms, the worst offender is usually `__sutd_git_info`. Optimize:

```bash
# In prompt.sh, only check git in small repos:
if [ -d "$dir/.git" ]; then
    local size
    size=$(du -s "$dir/.git" 2>/dev/null | awk '{print $1}')
    [ "${size:-0}" -gt 100000 ] && return  # skip if .git > 100MB
fi
```

Or disable git info entirely on slow systems:

```bash
# In info.conf or as override:
GIT_INFO_DISABLED=1
```

And check in `__sutd_git_info`:

```bash
[ "$GIT_INFO_DISABLED" = "1" ] && return
```

## Benchmark target

| Target          | Time         | Use case                       |
|-----------------|--------------|--------------------------------|
| Aggressive      | < 100ms      | Frequent quick logins          |
| Balanced (default) | 300-600ms | Normal usage                   |
| Full-featured   | 1-2s         | Daily summary, slow logins OK  |

Choose based on how often you SSH in.

## Recommended settings by use case

### Workstation (rare SSH)

Keep everything enabled. Use `INTERFACE_MODE=1` for slides.

### Bastion/jump host (frequent SSH)

```bash
INTERFACE_MODE=0
ENABLE_SSL_CERTS=0
ENABLE_DOCKER=0
SHOW_EXTERNAL_IP=0
ENABLE_PROGRESS_BARS=0
ENABLE_ASCII_GRAPH=0
ENABLE_FOOTER=0
```

### Production server (cautious, fast logins)

```bash
INTERFACE_MODE=0
ENABLE_HOST=1
ENABLE_SYSTEM=1
ENABLE_RESOURCES=1
ENABLE_SERVICES=1     # critical for ops
# everything else off
```

Add a `01-banner.sh` module that screams "PRODUCTION" in red.

### Personal VPS (vanity)

Keep everything on. Add weather, achievements, etc.