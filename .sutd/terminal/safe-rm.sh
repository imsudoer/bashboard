#!/bin/bash

__SAFE_LEVEL="${SAFE_RM_LEVEL:-2}"

__safe_critical_paths=(
    "/" "/etc" "/var" "/usr" "/boot" "/bin" "/sbin" "/lib"
    "/lib64" "/opt" "/root" "/home" "$HOME"
)

__safe_is_critical() {
    local target="$1"
    target=$(realpath -m "$target" 2>/dev/null || echo "$target")
    for p in "${__safe_critical_paths[@]}"; do
        [ "$target" = "$p" ] && return 0
    done
    return 1
}

__safe_confirm() {
    local level=$1
    local msg="$2"
    
    case "$level" in
        1)
            echo -e "\033[33m⚠ ${msg}\033[0m"
            read -p "  Continue? [y/N]: " ans
            [[ "$ans" =~ ^[yY]$ ]]
            ;;
        2)
            echo -e "\033[31m⚠ ${msg}\033[0m"
            read -p "  Type 'yes' to confirm: " ans
            [ "$ans" = "yes" ]
            ;;
        3)
            echo -e "\033[1;31m⚠ ⚠ ⚠ ${msg} ⚠ ⚠ ⚠\033[0m"
            local code=$((RANDOM % 9000 + 1000))
            read -p "  Type $code to confirm: " ans
            [ "$ans" = "$code" ]
            ;;
    esac
}

rm() {
    local recursive=0 force=0
    local critical=0
    
    for arg in "$@"; do
        case "$arg" in
            -*r*) recursive=1 ;;
            -*R*) recursive=1 ;;
            --recursive) recursive=1 ;;
            -*f*) force=1 ;;
        esac
        if [[ "$arg" != -* ]]; then
            if __safe_is_critical "$arg"; then
                critical=1
            fi
        fi
    done
    
    if [ "$critical" -eq 1 ]; then
        __safe_confirm 3 "rm targeting CRITICAL path: $*" || { echo "✗ aborted"; return 1; }
    elif [ "$recursive" -eq 1 ] && [ "$force" -eq 1 ]; then
        __safe_confirm "$__SAFE_LEVEL" "rm -rf $*" || { echo "✗ aborted"; return 1; }
    fi
    
    command rm "$@"
}

chmod() {
    if [[ "$*" == *"-R"* ]] && [[ "$*" == *"777"* ]]; then
        __safe_confirm 2 "chmod -R 777 $*" || { echo "✗ aborted"; return 1; }
    fi
    command chmod "$@"
}

chown() {
    for arg in "$@"; do
        if __safe_is_critical "$arg"; then
            __safe_confirm 3 "chown on CRITICAL path: $*" || { echo "✗ aborted"; return 1; }
            break
        fi
    done
    command chown "$@"
}

dd() {
    __safe_confirm 3 "dd is potentially destructive: dd $*" || { echo "✗ aborted"; return 1; }
    command dd "$@"
}

mkfs() { __safe_confirm 3 "mkfs $*" || { echo "✗ aborted"; return 1; }; command mkfs "$@"; }
mkfs.ext4() { __safe_confirm 3 "mkfs.ext4 $*" || { echo "✗ aborted"; return 1; }; command mkfs.ext4 "$@"; }
mkfs.ext3() { __safe_confirm 3 "mkfs.ext3 $*" || { echo "✗ aborted"; return 1; }; command mkfs.ext3 "$@"; }
mkfs.xfs()  { __safe_confirm 3 "mkfs.xfs $*"  || { echo "✗ aborted"; return 1; }; command mkfs.xfs  "$@"; }

iptables() {
    for arg in "$@"; do
        if [ "$arg" = "-F" ] || [ "$arg" = "--flush" ]; then
            __safe_confirm 2 "iptables flush: $*" || { echo "✗ aborted"; return 1; }
            break
        fi
    done
    command iptables "$@"
}