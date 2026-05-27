---
title: "Writing Terminal Extensions"
description: "How to build shell functions, aliases, and hooks that load on every session"
order: 5
group: "Bashboard"
badge: "GUIDE"
---
# Writing Terminal Extensions
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
A **terminal extension** is a bash script in `~/.sutd/terminal/` that's
**sourced** into your interactive shell on every login. Unlike modules,
extensions persist across the entire session and can:

- Define functions and aliases
- Modify `PROMPT_COMMAND`
- Bind keys with `bind -x`
- Set up `complete -F` autocompletions
- Override built-in commands (carefully)

## Anatomy of an extension

Minimal example:

```bash
#!/bin/bash

mycmd() {
    echo "hello, $1"
}
```

After `exec bash`:

```bash
$ mycmd world
hello, world
```

## Naming conventions

No numeric prefix is needed unless you care about load order. Use
descriptive lowercase names with hyphens:

```
~/.sutd/terminal/al.sh
~/.sutd/terminal/chain.sh
~/.sutd/terminal/my-tool.sh
```

If load order matters (e.g. you need to wrap a function defined by another
extension), prefix with two digits:

```
~/.sutd/terminal/10-base-utils.sh
~/.sutd/terminal/50-my-overrides.sh
```

## Core patterns

### Define a function

```bash
mytool() {
    local arg1="$1"
    [ -z "$arg1" ] && { echo "usage: mytool <arg>"; return 1; }
    echo "processing $arg1"
}
```

### Local variables

**Always** use `local` inside functions. Without it, variables leak into
the shell:

```bash
# BAD
mytool() {
    name="$1"        # leaks into shell as $name
}

# GOOD
mytool() {
    local name="$1"
}
```

### Persistent storage

For state that survives across sessions, write to `~/.sutd/data/`:

```bash
__MYTOOL_FILE="$HOME/.sutd/data/mytool.dat"
mkdir -p "$(dirname "$__MYTOOL_FILE")"
touch "$__MYTOOL_FILE"

mytool() {
    echo "$(date) $*" >> "$__MYTOOL_FILE"
}
```

Convention: prefix private vars/functions with `__` to avoid collisions:

```bash
__MYTOOL_INTERNAL_VAR
__mytool_internal_function() { ... }
```

### Subcommand pattern

For tools with multiple actions:

```bash
mytool() {
    local cmd="$1"; shift
    
    case "$cmd" in
        add)    __mytool_add "$@" ;;
        rm)     __mytool_rm "$@" ;;
        list|"") __mytool_list "$@" ;;
        -h|--help)
            cat << 'EOF'
  mytool — does something useful

  mytool add <item>
  mytool rm <item>
  mytool list
EOF
            ;;
        *)
            echo "unknown: $cmd"
            mytool --help
            return 1
            ;;
    esac
}

__mytool_add() { echo "added: $*"; }
__mytool_rm()  { echo "removed: $*"; }
__mytool_list() { echo "all items"; }
```

### Autocomplete

Use `complete -F` to provide tab completion:

```bash
_mytool_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "add rm list -h" -- "$cur") )
    elif [ "$prev" = "rm" ]; then
        local items
        items=$(cat "$__MYTOOL_FILE" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$items" -- "$cur") )
    fi
}
complete -F _mytool_complete mytool
```

Now `mytool <TAB>` shows subcommands; `mytool rm <TAB>` shows known items.

### Aliases

Simple aliases:

```bash
alias ll='ls -lah --color=auto'
alias ..='cd ..'
```

For complex behavior, use a function instead — functions accept arguments
and support shell expansion:

```bash
# BAD — alias doesn't accept args inline
alias gco='git checkout'

# OK for trivial cases:
alias gco='git checkout'

# BETTER — for anything with logic:
gco() {
    [ -z "$1" ] && { git branch; return; }
    git checkout "$1"
}
```

## Hooking into PROMPT_COMMAND

`PROMPT_COMMAND` is bash's hook that runs **before each prompt**. Use it
for things like:

- Updating `PS1` dynamically
- Logging commands to a file
- Switching `HISTFILE` per directory

### The safe way to append

```bash
__my_hook() {
    # your logic
}

if [ -z "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="__my_hook"
else
    case ";$PROMPT_COMMAND;" in
        *";__my_hook;"*) ;;
        *) PROMPT_COMMAND="$PROMPT_COMMAND;__my_hook" ;;
    esac
fi
```

This pattern:
- Adds your hook even if `PROMPT_COMMAND` is empty
- Detects if your hook is already registered (idempotent)
- Preserves existing hooks

### Prepending vs appending

```bash
# Append (runs after others):
PROMPT_COMMAND="$PROMPT_COMMAND;__my_hook"

# Prepend (runs before others):
PROMPT_COMMAND="__my_hook;$PROMPT_COMMAND"
```

`proj-history.sh` prepends so it can switch `HISTFILE` before `set_prompt`
reads anything. Order matters.

## Key bindings

Bind a custom key to a function with `bind -x`:

```bash
__my_action() {
    echo ""
    echo "you pressed the magic key"
}

bind -x '"\C-k": __my_action'
```

After `exec bash`, **Ctrl+K** runs your function.

### Common key escape codes

| Sequence    | Key            |
|-------------|----------------|
| `\C-a`      | Ctrl+A         |
| `\C-x\C-y`  | Ctrl+X, Ctrl+Y |
| `\ea`       | Alt+A          |
| `\e[1;5C`   | Ctrl+→         |
| `\e[1;5D`   | Ctrl+←         |

### Reading and writing the input line

Inside a `bind -x` handler, two readline variables are available:

```bash
__demo() {
    echo ""
    echo "current input: $READLINE_LINE"
    echo "cursor at: $READLINE_POINT"
    READLINE_LINE="echo hello"
    READLINE_POINT=${#READLINE_LINE}
}
bind -x '"\C-h": __demo'
```

This lets you write tools that **modify what's typed** (like fuzzy
history search).

## Overriding built-in commands

You can shadow built-ins with functions:

```bash
cd() {
    builtin cd "$@" && ls
}
```

To call the original from inside the wrapper, use `builtin` (for shell
builtins) or `command` (for external commands):

```bash
rm() {
    # ... safety logic ...
    command rm "$@"
}
```

### When NOT to override

- `cd`, `ls`, `cp`, `mv` — used by scripts that expect default behavior
- `echo`, `printf` — can break everything
- `[`, `test`, `:` — never override

## Loading conditions

If your tool depends on something, check at load time:

```bash
if ! command -v docker &>/dev/null; then
    return 0  # exit early, don't define functions
fi

dk() {
    docker "$@"
}
```

Or skip definition based on user preference:

```bash
if [ "$ENABLE_MY_TOOL" = "0" ]; then
    return 0
fi
```

## Performance

Terminal extensions add to **shell startup time**. Keep top-level code
minimal:

```bash
# BAD — runs on every shell start
SLOW_DATA=$(curl -s https://api.example.com/data)

mytool() {
    echo "$SLOW_DATA"
}

# GOOD — runs only when called
mytool() {
    local data
    data=$(curl -s https://api.example.com/data)
    echo "$data"
}
```

Time your full load:

```bash
time exec bash
```

If it's over 1 second, find the culprit:

```bash
for f in ~/.sutd/terminal/*.sh; do
    printf "%-30s " "$(basename $f)"
    { time source "$f" ; } 2>&1 | grep real
done
```

## Testing

Source and try:

```bash
source ~/.sutd/terminal/my-tool.sh
my-tool foo bar
```

If you change the file, re-source (`source`) — don't need to `exec bash`
unless top-level code changed.

For autocomplete testing:

```bash
source ~/.sutd/terminal/my-tool.sh
my-tool <TAB><TAB>
```

## Examples

See:

- [TODO Manager](examples/tool-todo-manager.md) — task tracker
- [Deploy Wrapper](examples/tool-deploy-wrapper.md) — multi-step deploy

## Common pitfalls

| Pitfall                                  | Fix                                  |
|------------------------------------------|--------------------------------------|
| Variables leak into shell                | Always use `local`                   |
| Stale `PROMPT_COMMAND` after reload      | Check before appending (see above)   |
| Slow startup                             | Move work into functions, not top    |
| Function names conflict with binaries    | Prefix custom funcs (`gw-build`)     |
| `exit` accidentally closes shell         | Use `return` inside functions        |
| Forgot `chmod +x`                        | Not needed for sourced files         |

## Reloading a single extension

If you edited one extension:

```bash
source ~/.sutd/terminal/my-tool.sh
```

If you added a new extension and want it picked up:

```bash
source ~/.sutd/terminal/new-tool.sh
```

It will also auto-load next time `.bashrc` runs.