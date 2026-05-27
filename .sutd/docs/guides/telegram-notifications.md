---
title: "Telegram Notifications"
description: "Send alerts to Telegram from your server — login events, service failures, long tasks"
order: 11
group: "Bashboard"
badge: "RECIPE"
---
# Guide: Telegram Notifications
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
Get notified on your phone when something happens on the server — long
tasks finish, alerts fire, deploys complete.

## Prerequisites

1. A Telegram bot (create one via [@BotFather](https://t.me/BotFather))
2. Your chat ID (get it from [@userinfobot](https://t.me/userinfobot))

## Step 1: Store the credentials

Use `remember` so they persist across sessions:

```bash
remember TG_BOT_TOKEN=1234567890:AAAA...your_token_here
remember TG_CHAT_ID=987654321
```

These will be exported on every login. Verify:

```bash
remember
# →   TG_BOT_TOKEN              = ********...
# →   TG_CHAT_ID                = 987654321
```

## Step 2: Create the notify tool

```bash
nano ~/.sutd/terminal/notify.sh
```

```bash
#!/bin/bash

notify() {
    local text="$*"
    
    if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
        echo "  notify: TG_BOT_TOKEN or TG_CHAT_ID not set"
        echo "  use: remember TG_BOT_TOKEN=... && remember TG_CHAT_ID=..."
        return 1
    fi
    
    if [ -z "$text" ]; then
        if [ -t 0 ]; then
            echo "  usage: notify \"message\""
            echo "  or:    long-command && notify done"
            return 1
        fi
        text=$(cat)
    fi
    
    local host
    host=$(hostname)
    local payload="[${host}] ${text}"
    
    local result
    result=$(curl -s --max-time 5 \
        "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "text=${payload}")
    
    if echo "$result" | grep -q '"ok":true'; then
        echo -e "  \033[32m✓\033[0m sent"
    else
        echo -e "  \033[31m✗\033[0m failed: $result"
        return 1
    fi
}

notify-file() {
    local file="$1"
    [ -f "$file" ] || { echo "no such file: $file"; return 1; }
    
    curl -s --max-time 30 \
        "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
        -F "chat_id=${TG_CHAT_ID}" \
        -F "document=@${file}" \
        -F "caption=[$(hostname)] ${file}" > /dev/null
    
    echo -e "  \033[32m✓\033[0m sent: $file"
}
```

## Step 3: Reload and test

```bash
source ~/.sutd/terminal/notify.sh
notify "hello from $(hostname)"
```

You should get a Telegram message.

## Usage patterns

### After long commands

```bash
backup-database && notify "backup done" || notify "BACKUP FAILED"
```

### With timing info

```bash
{ time long-task; } 2>&1 | tail -3 | notify
```

### Send file (e.g. log)

```bash
notify-file /var/log/nginx/error.log
```

### From a chain

```bash
chain add deploy "git pull"
chain add deploy "npm install"
chain add deploy "pm2 restart api"
chain add deploy "notify 'deploy complete'"
chain run deploy
```

## Step 4: SSH login alerts

Get notified whenever someone logs in via SSH.

Create a hook:

```bash
nano ~/.sutd/terminal/00-ssh-alert.sh
```

> Note the `00-` prefix to ensure it loads early.

```bash
#!/bin/bash

# Only fire for SSH sessions, not local terminals
if [ -n "$SSH_CONNECTION" ] && [ -n "$TG_BOT_TOKEN" ]; then
    REMOTE_IP=$(echo "$SSH_CONNECTION" | awk '{print $1}')
    
    (
        sleep 1
        curl -s --max-time 5 \
            "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TG_CHAT_ID}" \
            --data-urlencode "text=[$(hostname)] SSH login: ${USER} from ${REMOTE_IP} at $(date '+%Y-%m-%d %H:%M:%S')" \
            > /dev/null 2>&1
    ) &
    disown 2>/dev/null
fi
```

The `&` + `disown` ensures the notification fires in background without
blocking login.

## Step 5: Resource alerts (cron)

Set up a cron job that pings you if disk is critically low.

Create the alert script:

```bash
nano ~/.sutd/data/alerts/disk-alert.sh
mkdir -p ~/.sutd/data/alerts
chmod +x ~/.sutd/data/alerts/disk-alert.sh
```

```bash
#!/bin/bash

source ~/.sutd/data/remembered.dat 2>/dev/null

THRESHOLD=90

df -h --output=target,pcent | tail -n +2 | while read target pcent; do
    pct=${pcent%\%}
    [[ ! "$pct" =~ ^[0-9]+$ ]] && continue
    
    if [ "$pct" -ge "$THRESHOLD" ]; then
        curl -s --max-time 5 \
            "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TG_CHAT_ID}" \
            --data-urlencode "text=⚠️ [$(hostname)] Disk ${target} is at ${pcent}" \
            > /dev/null
    fi
done
```

Add to crontab:

```bash
crontab -e
```

```
*/15 * * * * /root/.sutd/data/alerts/disk-alert.sh
```

Runs every 15 minutes; only sends if threshold exceeded.

## Step 6: Service failure alerts

```bash
nano ~/.sutd/data/alerts/service-check.sh
chmod +x ~/.sutd/data/alerts/service-check.sh
```

```bash
#!/bin/bash

source ~/.sutd/data/remembered.dat 2>/dev/null

STATE_FILE=/tmp/sutd-svc-state

while IFS= read -r svc; do
    [ -z "$svc" ] || [[ "$svc" =~ ^# ]] && continue
    
    current=$(systemctl is-active "$svc" 2>/dev/null)
    previous=$(grep "^${svc}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2)
    
    if [ "$current" != "$previous" ]; then
        if [ "$current" = "failed" ] || [ "$current" = "inactive" ]; then
            curl -s --max-time 5 \
                "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
                -d "chat_id=${TG_CHAT_ID}" \
                --data-urlencode "text=🔴 [$(hostname)] ${svc} is now ${current}" \
                > /dev/null
        elif [ "$current" = "active" ] && [ -n "$previous" ]; then
            curl -s --max-time 5 \
                "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
                -d "chat_id=${TG_CHAT_ID}" \
                --data-urlencode "text=🟢 [$(hostname)] ${svc} recovered" \
                > /dev/null
        fi
    fi
done < ~/.sutd/services.list

# Update state
> "$STATE_FILE"
while IFS= read -r svc; do
    [ -z "$svc" ] || [[ "$svc" =~ ^# ]] && continue
    echo "${svc}=$(systemctl is-active "$svc" 2>/dev/null)" >> "$STATE_FILE"
done < ~/.sutd/services.list
```

Crontab:

```
*/2 * * * * /root/.sutd/data/alerts/service-check.sh
```

You'll get a 🔴 alert when a service goes down and a 🟢 when it recovers.

## Step 7: Long-running command auto-notify

Add to `~/.sutd/terminal/notify.sh`:

```bash
nag() {
    local start=$(date +%s)
    "$@"
    local rc=$?
    local end=$(date +%s)
    local duration=$((end - start))
    
    if [ "$duration" -gt 30 ]; then
        local mins=$((duration / 60))
        local secs=$((duration % 60))
        local msg="finished in ${mins}m${secs}s (exit $rc): $*"
        notify "$msg"
    fi
    
    return $rc
}
```

Usage:

```bash
nag make all
nag pg_dump huge_db > backup.sql
nag ./deploy.sh production
```

Auto-notifies only if the command took more than 30 seconds.

## Security notes

- **Never** commit `~/.sutd/data/remembered.dat` to git
- The file should be `chmod 600`:
  ```bash
  chmod 600 ~/.sutd/data/remembered.dat
  ```
- If you suspect token leakage, regenerate via @BotFather and:
  ```bash
  remember -d TG_BOT_TOKEN
  remember TG_BOT_TOKEN=new_token_here
  ```

## Troubleshooting

**Bot doesn't respond.** Check the bot has been started by you (send `/start`
once from your account).

**`chat_id` wrong.** Send any message to your bot, then visit:
```
https://api.telegram.org/bot<TOKEN>/getUpdates
```

Look for `"chat":{"id":...}`.

**Rate limits.** Telegram allows ~30 messages/sec for bots. Alerts hitting
this limit will silently fail. Don't put `notify` inside tight loops.