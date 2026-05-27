---
title: "Add a Terminal Tool"
description: "Build a full-featured TODO manager with subcommands, persistence, and autocompletion"
order: 2
group: "Bashboard"
parent: "Writing Terminal Extensions"
badge: "TUTORIAL"
---
# Guide: Adding a Terminal Tool
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
This guide builds a complete terminal extension: a **TODO manager** with
tab completion, persistence, and a clean API.

## What we'll build

```bash
todo add "fix nginx config"
todo add -p high "critical security patch"
todo list
todo done 2
todo rm 1
todo today
```

## Step 1: Create the file

```bash
nano ~/.sutd/terminal/todo.sh
```

## Step 2: Set up storage

Start with the data location:

```bash
#!/bin/bash

__TODO_FILE="$HOME/.sutd/data/todo.dat"
mkdir -p "$(dirname "$__TODO_FILE")"
touch "$__TODO_FILE"
```

We'll store one task per line in a pipe-delimited format:

```
1716800000|high|open|fix nginx config
1716801200|normal|done|update docs
```

Fields: `timestamp|priority|status|text`.

## Step 3: Define the main function

```bash
todo() {
    local cmd="$1"; shift
    
    case "$cmd" in
        add)        __todo_add "$@" ;;
        ls|list|"") __todo_list "$@" ;;
        done|d)     __todo_done "$@" ;;
        rm|remove)  __todo_rm "$@" ;;
        today)      __todo_today ;;
        clear)      __todo_clear ;;
        -h|--help)  __todo_help ;;
        *)
            echo "  unknown: $cmd"
            __todo_help
            return 1
            ;;
    esac
}
```

This dispatcher pattern keeps each action in its own private function.

## Step 4: Implement `add`

```bash
__todo_add() {
    local priority="normal"
    local text=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -p|--priority) priority="$2"; shift 2 ;;
            *)             text="${text:+$text }$1"; shift ;;
        esac
    done
    
    if [ -z "$text" ]; then
        echo "  usage: todo add [-p high|normal|low] \"text\""
        return 1
    fi
    
    local ts
    ts=$(date +%s)
    echo "${ts}|${priority}|open|${text}" >> "$__TODO_FILE"
    
    echo -e "  \033[32m✓\033[0m added: $text"
}
```

## Step 5: Implement `list`

```bash
__todo_list() {
    if [ ! -s "$__TODO_FILE" ]; then
        echo "  (no tasks)"
        echo "  add with: todo add \"text\""
        return
    fi
    
    local i=1
    while IFS='|' read -r ts priority status text; do
        [ -z "$ts" ] && continue
        
        local icon icon_color
        case "$status" in
            done) icon="✓"; icon_color="\033[32m" ;;
            *)    icon="○"; icon_color="\033[37m" ;;
        esac
        
        local prio_color
        case "$priority" in
            high)   prio_color="\033[31m" ;;
            low)    prio_color="\033[90m" ;;
            *)      prio_color="\033[37m" ;;
        esac
        
        local date_str
        date_str=$(date -d "@$ts" '+%m-%d' 2>/dev/null)
        
        if [ "$status" = "done" ]; then
            printf "  \033[90m%2d) ${icon_color}%s\033[0m \033[90m[%s] [%-6s] %s\033[0m\n" \
                "$i" "$icon" "$date_str" "$priority" "$text"
        else
            printf "  \033[90m%2d)\033[0m ${icon_color}%s\033[0m \033[90m[%s]\033[0m ${prio_color}[%-6s]\033[0m %s\n" \
                "$i" "$icon" "$date_str" "$priority" "$text"
        fi
        
        i=$((i+1))
    done < "$__TODO_FILE"
    
    local total open_count done_count
    total=$(wc -l < "$__TODO_FILE")
    open_count=$(grep -c '|open|' "$__TODO_FILE")
    done_count=$(grep -c '|done|' "$__TODO_FILE")
    
    echo ""
    echo -e "  \033[90m${open_count} open · ${done_count} done · ${total} total\033[0m"
}
```

## Step 6: Implement `done`

```bash
__todo_done() {
    local n="$1"
    
    if [ -z "$n" ] || ! [[ "$n" =~ ^[0-9]+$ ]]; then
        echo "  usage: todo done <number>"
        return 1
    fi
    
    local total
    total=$(wc -l < "$__TODO_FILE")
    
    if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        echo "  no such task: $n"
        return 1
    fi
    
    awk -v target="$n" -F'|' -v OFS='|' '
        NR == target { $3 = "done" }
        { print }
    ' "$__TODO_FILE" > "${__TODO_FILE}.tmp" && mv "${__TODO_FILE}.tmp" "$__TODO_FILE"
    
    local text
    text=$(sed -n "${n}p" "$__TODO_FILE" | cut -d'|' -f4-)
    echo -e "  \033[32m✓\033[0m done: $text"
}
```

Note the **atomic write** pattern: write to `.tmp`, then `mv`.

## Step 7: Implement `rm`

```bash
__todo_rm() {
    local n="$1"
    
    if [ -z "$n" ] || ! [[ "$n" =~ ^[0-9]+$ ]]; then
        echo "  usage: todo rm <number>"
        return 1
    fi
    
    local text
    text=$(sed -n "${n}p" "$__TODO_FILE" | cut -d'|' -f4-)
    [ -z "$text" ] && { echo "  no such task: $n"; return 1; }
    
    sed -i "${n}d" "$__TODO_FILE"
    echo -e "  \033[31m✗\033[0m removed: $text"
}
```

## Step 8: Implement `today`

```bash
__todo_today() {
    local start_of_day
    start_of_day=$(date -d 'today 00:00' +%s)
    
    local found=0
    while IFS='|' read -r ts priority status text; do
        [ -z "$ts" ] && continue
        if [ "$ts" -ge "$start_of_day" ]; then
            found=1
            local icon="○"
            [ "$status" = "done" ] && icon="✓"
            echo -e "  $icon $text"
        fi
    done < "$__TODO_FILE"
    
    [ "$found" -eq 0 ] && echo "  (no tasks added today)"
}
```

## Step 9: Implement `clear` and `help`

```bash
__todo_clear() {
    read -p "  Clear all completed tasks? [y/N]: " ans
    [[ ! "$ans" =~ ^[yY]$ ]] && { echo "  aborted"; return; }
    
    grep -v '|done|' "$__TODO_FILE" > "${__TODO_FILE}.tmp" && \
        mv "${__TODO_FILE}.tmp" "$__TODO_FILE"
    echo -e "  \033[31m✗\033[0m cleared completed tasks"
}

__todo_help() {
    cat << 'EOF'
  todo — simple task manager

  todo add "<text>"             add task
  todo add -p high "<text>"     add with priority (high|normal|low)
  todo                          list all
  todo list                     same as above
  todo done <n>                 mark task #n as done
  todo rm <n>                   delete task #n
  todo today                    show tasks added today
  todo clear                    remove all completed tasks
  todo -h                       this help
EOF
}
```

## Step 10: Add tab completion

```bash
_todo_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "add list done rm today clear -h" -- "$cur") )
    elif [ "$prev" = "-p" ] || [ "$prev" = "--priority" ]; then
        COMPREPLY=( $(compgen -W "high normal low" -- "$cur") )
    fi
}

complete -F _todo_complete todo
```

Now `todo <TAB>` shows subcommands, `todo add -p <TAB>` shows priorities.

## Step 11: Test

```bash
source ~/.sutd/terminal/todo.sh

todo add "test the new tool"
todo add -p high "critical bug"
todo
todo done 1
todo today
todo rm 2
```

## Step 12: Add to helpme

Create the documentation page:

```bash
cat > ~/.sutd/data/helpme/todo.md << 'EOF'
# Todo Manager

Track tasks with priorities and status.

## Add task
    todo add "fix the bug"
    todo add -p high "critical update"

## List
    todo                     all tasks
    todo today               only today's tasks

## Update status
    todo done 3              mark task #3 done
    todo rm 1                delete task #1
    todo clear               remove all completed

## Priorities
- `high` — red label
- `normal` — default
- `low` — gray label
EOF
```

Now `helpme todo` shows your documentation, and `helpme -w` includes it
in the web view.

## Step 13: Reload

```bash
exec bash
```

## Bonus: Integrate with a module

Want unfinished tasks shown at login? Create a module:

```bash
nano ~/.sutd/modules/85-todo-summary.sh
chmod +x ~/.sutd/modules/85-todo-summary.sh
```

```bash
#!/bin/bash

TODO_FILE="$HOME/.sutd/data/todo.dat"
[ -f "$TODO_FILE" ] || exit 0

OPEN=$(grep -c '|open|' "$TODO_FILE" 2>/dev/null)
[ "$OPEN" -eq 0 ] && exit 0

divider
section "Open todos:"

i=1
grep '|open|' "$TODO_FILE" | while IFS='|' read -r ts priority status text; do
    [ "$i" -gt 5 ] && break
    
    case "$priority" in
        high) prio_color="$COLOR_RED" ;;
        low)  prio_color="$COLOR_GRAY" ;;
        *)    prio_color="$COLOR_WHITE" ;;
    esac
    
    printf "    ${prio_color}○${COLOR_RESET} %s\n" "$text"
    i=$((i+1))
done

[ "$OPEN" -gt 5 ] && echo -e "    ${COLOR_GRAY}... and $((OPEN - 5)) more${COLOR_RESET}"
```

Add to `info.conf`:

```bash
ENABLE_TODO_SUMMARY=1
```

## Summary

You built:

- A **multi-subcommand tool** with help, args, persistence
- A **storage format** that's parseable but human-readable
- **Tab completion** that adapts to context
- A **help page** in the help center
- An **integration module** that surfaces data at login

This is the standard pattern. Most terminal tools in Bashboard follow it
(`al`, `chain`, `cfg`, `env-check`, `remember`).

## Patterns recap

- Private variables: `__TOOL_NAME` prefix
- Private functions: `__tool_action` prefix
- Storage: `~/.sutd/data/<name>.dat`
- Atomic writes: write `.tmp`, then `mv`
- Help: `cat << 'EOF'` block
- Completion: `complete -F`