---
title: "Add a Custom Module"
description: "Step-by-step walkthrough building a disk-health dashboard module from scratch"
order: 1
group: "Bashboard"
parent: "Writing Modules"
badge: "TUTORIAL"
---
# Guide: Adding a Custom Module
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
This guide walks you through creating a new dashboard module from scratch.
By the end you'll have a working module that displays on every login.

## What we'll build

A **disk health module** that shows free space and warns if any partition
is over 85% full.

```
  --------------------------------------------------
  Disk Health:
    ●  /              30G free of 158G  (19%)
    ●  /var           45G free of 80G   (44%)
    ⚠  /boot          120M free of 500M (76%)
    ✗  /home          1G free of 100G   (99%)
```

## Step 1: Create the file

Choose a numeric prefix. Looking at existing modules:

- `40-resources.sh` — general resources
- `45-ssl-certs.sh` — SSL certs
- `46-top-processes.sh` — top procs

`44` fits between resources and SSL — close in topic. Let's use it:

```bash
nano ~/.sutd/modules/44-disk-health.sh
```

## Step 2: Write the skeleton

Start with the basic template:

```bash
#!/bin/bash

divider
section "Disk Health:"

echo "    placeholder line"
```

Make it executable:

```bash
chmod +x ~/.sutd/modules/44-disk-health.sh
```

## Step 3: Enable it

Edit `~/.sutd/info.conf`:

```bash
ENABLE_DISK_HEALTH=1
```

> Note: filename `44-disk-health.sh` → strip `44-` → `disk-health` → 
> replace `-` with `_` → `DISK_HEALTH` → `ENABLE_DISK_HEALTH`

## Step 4: Test it

```bash
~/.sutd/motd.sh
```

You should see the placeholder line.

If you don't see it:

```bash
bash -x ~/.sutd/modules/44-disk-health.sh
```

## Step 5: Add real logic

Replace the placeholder with disk parsing:

```bash
#!/bin/bash

divider
section "Disk Health:"

df -h --output=target,used,size,avail,pcent | tail -n +2 | while read target used size avail pcent; do
    case "$target" in
        /dev|/proc|/sys|/run*|/tmp) continue ;;
    esac
    
    pct_num=${pcent%\%}
    
    if [ "$pct_num" -ge 95 ]; then
        icon="${COLOR_RED}✗${COLOR_RESET}"
    elif [ "$pct_num" -ge 85 ]; then
        icon="${COLOR_YELLOW}⚠${COLOR_RESET}"
    else
        icon="${COLOR_GREEN}●${COLOR_RESET}"
    fi
    
    printf "    %b  %-14s ${COLOR_GRAY}%s free of %s (%s)${COLOR_RESET}\n" \
        "$icon" "$target" "$avail" "$size" "$pcent"
done
```

Test again:

```bash
~/.sutd/motd.sh
```

You should see actual disk data.

## Step 6: Handle edge cases

What if `df` fails or returns empty? Add defensive checks:

```bash
#!/bin/bash

divider
section "Disk Health:"

DF_OUT=$(df -h --output=target,used,size,avail,pcent 2>/dev/null | tail -n +2)

if [ -z "$DF_OUT" ]; then
    echo -e "    ${COLOR_GRAY}unable to read disk info${COLOR_RESET}"
    exit 0
fi

echo "$DF_OUT" | while read target used size avail pcent; do
    case "$target" in
        /dev|/proc|/sys|/run*|/tmp|/snap*) continue ;;
    esac
    
    pct_num=${pcent%\%}
    [[ ! "$pct_num" =~ ^[0-9]+$ ]] && continue
    
    if [ "$pct_num" -ge 95 ]; then
        icon="${COLOR_RED}✗${COLOR_RESET}"
    elif [ "$pct_num" -ge 85 ]; then
        icon="${COLOR_YELLOW}⚠${COLOR_RESET}"
    else
        icon="${COLOR_GREEN}●${COLOR_RESET}"
    fi
    
    printf "    %b  %-14s ${COLOR_GRAY}%s free of %s (%s)${COLOR_RESET}\n" \
        "$icon" "$target" "$avail" "$size" "$pcent"
done
```

## Step 7: Add module-specific config

Let's make the warning threshold configurable. In `info.conf`:

```bash
DISK_WARN_PCT=85
DISK_CRIT_PCT=95
```

In your module:

```bash
WARN=${DISK_WARN_PCT:-85}
CRIT=${DISK_CRIT_PCT:-95}

if [ "$pct_num" -ge "$CRIT" ]; then
    icon="${COLOR_RED}✗${COLOR_RESET}"
elif [ "$pct_num" -ge "$WARN" ]; then
    icon="${COLOR_YELLOW}⚠${COLOR_RESET}"
else
    icon="${COLOR_GREEN}●${COLOR_RESET}"
fi
```

## Step 8: Add to a slide (optional)

If you use `INTERFACE_MODE=1`, modules go into slides defined in
`menu.sh`. Edit it to include your module:

```bash
SLIDES=(
    "Overview|10-host.sh 30-system.sh ..."
    "Resources|40-resources.sh 44-disk-health.sh 52-progress-bars.sh"
    # ...
)
```

Or give it its own slide:

```bash
SLIDES=(
    "Overview|..."
    "Resources|40-resources.sh 52-progress-bars.sh"
    "Disks|44-disk-health.sh"
    # ...
)
```

## Step 9: Reload and verify

```bash
exec bash
```

Navigate to your slide (or just see plain MOTD if `INTERFACE_MODE=0`).

## Step 10: Polish

A few finishing touches:

### Skip if no real partitions

```bash
[ -z "$DF_OUT" ] && exit 0
```

### Only show problem partitions (optional)

```bash
SHOW_ALL=${DISK_SHOW_ALL:-1}

# inside the loop:
if [ "$SHOW_ALL" != "1" ] && [ "$pct_num" -lt "$WARN" ]; then
    continue
fi
```

This way you can set `DISK_SHOW_ALL=0` in `info.conf` to only see
problematic partitions, keeping the dashboard cleaner.

### Add summary line

```bash
PROBLEM_COUNT=$(echo "$DF_OUT" | awk -v w="$WARN" '
    { pct=$5; gsub("%","",pct); if (pct+0 >= w) c++ }
    END { print c+0 }
')

if [ "$PROBLEM_COUNT" -gt 0 ]; then
    echo -e "    ${COLOR_YELLOW}${PROBLEM_COUNT} partition(s) need attention${COLOR_RESET}"
fi
```

## Final module

```bash
#!/bin/bash

WARN=${DISK_WARN_PCT:-85}
CRIT=${DISK_CRIT_PCT:-95}
SHOW_ALL=${DISK_SHOW_ALL:-1}

divider
section "Disk Health:"

DF_OUT=$(df -h --output=target,used,size,avail,pcent 2>/dev/null | tail -n +2)

if [ -z "$DF_OUT" ]; then
    echo -e "    ${COLOR_GRAY}unable to read disk info${COLOR_RESET}"
    exit 0
fi

PROBLEMS=0

echo "$DF_OUT" | while read target used size avail pcent; do
    case "$target" in
        /dev|/proc|/sys|/run*|/tmp|/snap*) continue ;;
    esac
    
    pct_num=${pcent%\%}
    [[ ! "$pct_num" =~ ^[0-9]+$ ]] && continue
    
    if [ "$pct_num" -ge "$CRIT" ]; then
        icon="${COLOR_RED}✗${COLOR_RESET}"
    elif [ "$pct_num" -ge "$WARN" ]; then
        icon="${COLOR_YELLOW}⚠${COLOR_RESET}"
    else
        icon="${COLOR_GREEN}●${COLOR_RESET}"
        [ "$SHOW_ALL" != "1" ] && continue
    fi
    
    printf "    %b  %-14s ${COLOR_GRAY}%s free of %s (%s)${COLOR_RESET}\n" \
        "$icon" "$target" "$avail" "$size" "$pcent"
done
```

## Summary checklist

- [x] Create file in `~/.sutd/modules/`
- [x] `chmod +x` the file
- [x] Add `ENABLE_<NAME>=1` to `info.conf`
- [x] Test with `~/.sutd/motd.sh` or `bash -x <file>`
- [x] Handle errors gracefully (`exit 0` on missing data)
- [x] Use shared helpers (`field`, `section`, `divider`, colors)
- [x] Add custom config vars to `info.conf` if needed
- [x] Optionally add to a slide in `menu.sh`
- [x] `source ~/.bashrc` to reload

## Next steps

- Read [Library API](../06-lib-api.md) to see what helpers are available
- Browse existing modules in `~/.sutd/modules/` for inspiration
- See [Backup Status example](../examples/module-backup-status.md) for
  another full module walkthrough