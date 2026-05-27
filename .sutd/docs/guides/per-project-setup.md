---
title: "Per-Project Setup"
description: "Project-local hooks, commands, env vars, and isolated bash history per directory"
order: 13
group: "Bashboard"
badge: "RECIPE"
---
# Guide: Per-Project Configuration
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
Bashboard has built-in per-project history switching, but you can extend
this with per-project aliases, env vars, and commands.

## How project detection works

When you `cd` into a directory, `proj-history.sh` walks up the tree
looking for either:

- `.git/` directory
- `.sutd-project` marker file

The first one found defines the **project root**. All directories below
it share the same project context.

## Quick start

```bash
cd ~/projects/myapi
projhist mark            # creates .sutd-project here
```

Now `~/projects/myapi` is a project. Its history is isolated.

## Project-local Bashboard hooks

Extend per-project behavior with a `.sutd.sh` file at the project root.

Create `~/.sutd/terminal/01-proj-hooks.sh`:

```bash
#!/bin/bash

__proj_hooks_loaded=""

__proj_hooks_check() {
    local proj_root=""
    local d="$PWD"
    while [ "$d" != "/" ] && [ -n "$d" ]; do
        if [ -d "$d/.git" ] || [ -f "$d/.sutd-project" ]; then
            proj_root="$d"
            break
        fi
        d=$(dirname "$d")
    done
    
    if [ -z "$proj_root" ]; then
        if [ -n "$__proj_hooks_loaded" ] && [ -n "$__proj_hooks_unload" ]; then
            eval "$__proj_hooks_unload"
            unset __proj_hooks_unload
        fi
        __proj_hooks_loaded=""
        return
    fi
    
    if [ "$__proj_hooks_loaded" = "$proj_root" ]; then
        return
    fi
    
    if [ -n "$__proj_hooks_unload" ]; then
        eval "$__proj_hooks_unload"
        unset __proj_hooks_unload
    fi
    
    local hook="$proj_root/.sutd.sh"
    if [ -f "$hook" ]; then
        source "$hook"
        __proj_hooks_loaded="$proj_root"
        echo -e "  \033[90m→ loaded $hook\033[0m"
    else
        __proj_hooks_loaded="$proj_root"
    fi
}

if [ -z "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="__proj_hooks_check"
else
    case ";$PROMPT_COMMAND;" in
        *";__proj_hooks_check;"*) ;;
        *) PROMPT_COMMAND="__proj_hooks_check;$PROMPT_COMMAND" ;;
    esac
fi
```

## Example: project hook for a Node.js API

In `~/projects/myapi/.sutd.sh`:

```bash
# Local project commands
dev()    { npm run dev; }
build()  { npm run build; }
test()   { npm test; }
logs()   { pm2 logs api --lines 100; }
deploy() { 
    git pull && \
    npm install && \
    npm run build && \
    pm2 restart api
}

# Project-local env vars
export NODE_ENV=development
export DATABASE_URL="postgres://localhost/myapi_dev"
export PORT=3000

# Unload commands when leaving project
__proj_hooks_unload="
    unset -f dev build test logs deploy
    unset NODE_ENV DATABASE_URL PORT
"

# Welcome message
echo -e "  \033[38;5;208m▸ myapi project loaded\033[0m"
echo -e "  \033[90m  commands: dev, build, test, logs, deploy\033[0m"
```

Now:

```bash
cd ~/projects/myapi
# →   → loaded /home/me/projects/myapi/.sutd.sh
# →   ▸ myapi project loaded
# →     commands: dev, build, test, logs, deploy

dev               # works only inside this project
cd ..
dev               # → "command not found" — automatically unloaded
```

## Example: project hook with secrets

```bash
# ~/projects/website/.sutd.sh

export STRIPE_KEY="sk_test_..."
export AWS_PROFILE="website-dev"

# Quick deploys
ship-staging() {
    rsync -avz dist/ user@staging:/var/www/website/
    ssh user@staging "systemctl reload nginx"
    notify "website deployed to staging"
}

ship-prod() {
    read -p "  Deploy to PRODUCTION? Type 'yes': " ans
    [ "$ans" != "yes" ] && return
    rsync -avz dist/ user@prod:/var/www/website/
    ssh user@prod "systemctl reload nginx"
    notify "🚀 website deployed to PROD"
}

__proj_hooks_unload="
    unset STRIPE_KEY AWS_PROFILE
    unset -f ship-staging ship-prod
"
```

## Example: per-project Bashboard module overrides

You can have the dashboard show project-specific info when you cd in.

In `~/projects/myapi/.sutd.sh`:

```bash
project-status() {
    echo ""
    echo -e "  \033[37mProject status:\033[0m"
    
    field "Branch" "$(git symbolic-ref --short HEAD 2>/dev/null)"
    field "Changes" "$(git status --porcelain | wc -l) files"
    field "Behind" "$(git rev-list HEAD...origin/main --count 2>/dev/null) commits"
    field "TODO" "$(grep -rn TODO src/ 2>/dev/null | wc -l) markers"
    
    if [ -f package.json ]; then
        field "Version" "$(node -p "require('./package.json').version")"
    fi
}
```

Call `project-status` whenever you want.

## Project bookmarks

You can have a `bookmarks` file inside each project to navigate fast
within it:

```bash
# ~/projects/myapi/.sutd.sh

cd-src()    { cd "$PROJECT_ROOT/src"; }
cd-tests()  { cd "$PROJECT_ROOT/__tests__"; }
cd-config() { cd "$PROJECT_ROOT/config"; }
cd-logs()   { cd "/var/log/myapi"; }

PROJECT_ROOT=$(pwd)

__proj_hooks_unload="
    unset -f cd-src cd-tests cd-config cd-logs
    unset PROJECT_ROOT
"
```

## Auto-activate Python venv

```bash
# ~/projects/pyapp/.sutd.sh

if [ -d .venv ] && [ -z "$VIRTUAL_ENV" ]; then
    source .venv/bin/activate
    echo -e "  \033[32m✓\033[0m venv activated"
fi

__proj_hooks_unload="
    [ -n \"\$VIRTUAL_ENV\" ] && deactivate
"
```

## Auto-load .env files

Many projects have a `.env` file. Auto-source it:

```bash
# ~/projects/myapi/.sutd.sh

if [ -f .env ]; then
    set -a
    source .env
    set +a
    echo -e "  \033[90m  .env loaded\033[0m"
fi

__proj_hooks_unload="
    # unset env vars from .env
    while IFS='=' read -r key val; do
        [[ \"\$key\" =~ ^[A-Z_]+\$ ]] && unset \"\$key\"
    done < .env
"
```

## Caveats

- `.sutd.sh` is **sourced** into your shell. Anyone with write access to
  the project can inject commands. Only mark projects you trust as such.
- Functions defined in `.sutd.sh` override existing commands if names
  match. Be careful with names like `test` (a shell built-in).
- The hook runs on **every** prompt while you're in the project. Keep top
  level code minimal — only function definitions and env exports.

## Best practices

- Use a prefix or suffix for project commands: `api-dev`, `web-deploy` —
  reduces collision risk
- Put **paths** in `__proj_hooks_unload` carefully — use `unset -f` for
  functions and plain `unset` for variables
- Keep `.sutd.sh` in **git** so your teammates get the same commands
- Add **sensitive `.env`** to `.gitignore` but commit a `.env.example`