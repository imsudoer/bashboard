#!/bin/bash

__sutd_timer_start() {
    __SUTD_TIMER_START=${__SUTD_TIMER_START:-$EPOCHREALTIME}
}

__sutd_timer_stop() {
    if [ -n "$__SUTD_TIMER_START" ] && [ -n "$EPOCHREALTIME" ]; then
        local end="$EPOCHREALTIME"
        __SUTD_LAST_DURATION=$(awk -v s="$__SUTD_TIMER_START" -v e="$end" 'BEGIN {printf "%.2f", e - s}')
        unset __SUTD_TIMER_START
    else
        __SUTD_LAST_DURATION=""
    fi
}

trap '__sutd_timer_start' DEBUG

__sutd_git_info() {
    local dir="$PWD"
    while [ "$dir" != "/" ] && [ -n "$dir" ]; do
        if [ -d "$dir/.git" ]; then
            break
        fi
        dir=$(dirname "$dir")
    done
    [ "$dir" = "/" ] && return
    [ ! -d "$dir/.git" ] && return
    
    local branch
    branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)
    [ -z "$branch" ] && return
    
    local dirty=""
    local status
    status=$(git -C "$dir" status --porcelain 2>/dev/null)
    if [ -n "$status" ]; then
        local staged unstaged
        staged=$(echo "$status" | grep -c '^[MADRC]')
        unstaged=$(echo "$status" | grep -c '^.[MD?]')
        [ "$staged" -gt 0 ] && dirty="${dirty}+"
        [ "$unstaged" -gt 0 ] && dirty="${dirty}*"
    fi
    
    local ahead behind
    local tracking
    tracking=$(git -C "$dir" rev-list --count --left-right '@{upstream}...HEAD' 2>/dev/null)
    if [ -n "$tracking" ]; then
        behind=$(echo "$tracking" | awk '{print $1}')
        ahead=$(echo "$tracking" | awk '{print $2}')
        [ "$ahead" -gt 0 ] && dirty="${dirty}↑${ahead}"
        [ "$behind" -gt 0 ] && dirty="${dirty}↓${behind}"
    fi
    
    if [ -n "$dirty" ]; then
        echo " $$\033[38;5;208m$$(${branch} ${dirty})$$\033[0m$$"
    else
        echo " $$\033[32m$$(${branch})$$\033[0m$$"
    fi
}

__sutd_breadcrumbs() {
    local proj_root=""
    local d="$PWD"
    while [ "$d" != "/" ] && [ -n "$d" ]; do
        if [ -d "$d/.git" ] || [ -f "$d/.sutd-project" ]; then
            proj_root="$d"
            break
        fi
        d=$(dirname "$d")
    done
    
    if [ -n "$proj_root" ]; then
        local proj_name
        proj_name=$(basename "$proj_root")
        local rel
        if [ "$PWD" = "$proj_root" ]; then
            rel=""
        else
            rel="${PWD#$proj_root/}"
        fi
        
        if [ -z "$rel" ]; then
            echo "$$\033[38;5;208m$$⌂ ${proj_name}$$\033[0m$$"
        else
            local crumbs
            crumbs=$(echo "$rel" | sed 's|/| \$$\\033[90m\$$›\$$\\033[37m\$$ |g')
            echo "$$\033[38;5;208m$$⌂ ${proj_name}$$\033[90m$$ › $$\033[37m$$${crumbs}$$\033[0m$$"
        fi
    else
        echo "$$\033[37m$$\w$$\033[0m$$"
    fi
}

set_prompt() {
    local EXIT_CODE="$?"
    __sutd_timer_stop
    
    local ARROW_COLOR
    if [ "$EXIT_CODE" -eq 0 ]; then
        ARROW_COLOR='$$\033[32m$$'
    else
        ARROW_COLOR='$$\033[31m$$'
    fi
    
    local DUR=""
    if [ -n "$__SUTD_LAST_DURATION" ]; then
        local secs="${__SUTD_LAST_DURATION%.*}"
        if [ "${secs:-0}" -ge 3 ]; then
            DUR=' $$\033[33m$$[took '"$__SUTD_LAST_DURATION"'s]$$\033[0m$$'
        fi
    fi
    
    local CRUMBS GITINFO
    CRUMBS=$(__sutd_breadcrumbs)
    GITINFO=$(__sutd_git_info)
    
    PS1='$$\033[38;5;250m$$\u$$\033[0m$$@$$\033[38;5;208m$$\h$$\033[0m$$:'"${CRUMBS}${GITINFO}${DUR}"' '"${ARROW_COLOR}"'❯$$\033[0m$$ '
}

if [ -z "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="set_prompt"
else
    case ";$PROMPT_COMMAND;" in
        *";set_prompt;"*) ;;
        *) PROMPT_COMMAND="$PROMPT_COMMAND;set_prompt" ;;
    esac
fi