#!/bin/bash

__authorized_keys_files() {
    local user="${1:-}"
    if [ -n "$user" ]; then
        local home
        home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6)
        [ -n "$home" ] && [ -f "$home/.ssh/authorized_keys" ] && echo "$user|$home/.ssh/authorized_keys"
        return
    fi
    
    while IFS=: read -r u _ uid _ _ home _; do
        [ "$uid" -lt 1000 ] && [ "$uid" -ne 0 ] && continue
        [ "$uid" -ge 65534 ] && continue
        local ak="$home/.ssh/authorized_keys"
        if [ "$(id -u)" -eq 0 ]; then
            [ -f "$ak" ] && echo "$u|$ak"
        else
            [ -r "$ak" ] && echo "$u|$ak"
        fi
    done < /etc/passwd
}

__key_fingerprint() {
    local key="$1"
    echo "$key" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}'
}

audit-keys() {
    local action="list"
    local target_user=""
    local key_input=""
    local key_id=""
    local with_last=0
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -a|--add)
                action="add"
                shift
                if [ -n "$1" ] && [[ "$1" != -* ]]; then
                    key_input="$1"
                    shift
                fi
                ;;
            -r|--remove)
                action="remove"
                key_id="$2"
                shift 2
                ;;
            -u|--user)
                target_user="$2"
                shift 2
                ;;
            -e|--last)
                with_last=1
                shift
                ;;
            -c|--check)
                action="check"
                shift
                ;;
            -h|--help)
                cat << 'EOF'
  audit-keys — manage SSH authorized_keys across users

  audit-keys                       list all authorized keys
  audit-keys -u <user>             only specific user
  audit-keys -e                    enrich with last-used info from auth.log
  audit-keys -a [key|@file]        add a key (interactive if no arg)
  audit-keys -a -u <user>          add for specific user
  audit-keys -r <n>                remove key #n (use list to see numbers)
  audit-keys -c                    sanity check (perms, weak keys, dupes)
  audit-keys -h                    this help

  Examples:
    audit-keys
    audit-keys -u root -e
    audit-keys -a "ssh-ed25519 AAAA... me@laptop"
    audit-keys -a @~/new_key.pub
    audit-keys -r 3
EOF
                return
                ;;
        esac
    done
    
    case "$action" in
        check)
            __audit_keys_check
            return
            ;;
        list)
            __audit_keys_list "$target_user" "$with_last"
            return
            ;;
        add)
            __audit_keys_add "$target_user" "$key_input"
            return
            ;;
        remove)
            __audit_keys_remove "$target_user" "$key_id"
            return
            ;;
    esac
}

__audit_keys_list() {
    local filter_user="$1"
    local with_last="$2"
    
    local files
    files=$(__authorized_keys_files "$filter_user")
    
    if [ -z "$files" ]; then
        echo "  no readable authorized_keys files found"
        [ "$(id -u)" -ne 0 ] && echo -e "  \033[90m  (run as root to see all users)\033[0m"
        return 1
    fi
    
    local global_idx=0
    local last_log=""
    [ -r /var/log/auth.log ] && last_log="/var/log/auth.log"
    [ -r /var/log/secure ]   && last_log="/var/log/secure"
    
    > /tmp/.audit_keys_index
    
    while IFS='|' read -r user keyfile; do
        [ -z "$user" ] && continue
        
        echo ""
        echo -e "  \033[37muser \033[38;5;208m${user}\033[0m \033[90m(${keyfile})\033[0m"
        
        local lineno=0
        local user_count=0
        
        while IFS= read -r line; do
            lineno=$((lineno + 1))
            [ -z "$line" ] && continue
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            
            global_idx=$((global_idx + 1))
            user_count=$((user_count + 1))
            
            echo "${global_idx}|${user}|${keyfile}|${lineno}" >> /tmp/.audit_keys_index
            
            local type=$(echo "$line" | awk '{
                for (i=1; i<=NF; i++) {
                    if ($i ~ /^(ssh-|ecdsa-|sk-)/) { print $i; exit }
                }
            }')
            
            local comment=$(echo "$line" | awk '{
                for (i=1; i<=NF; i++) {
                    if ($i ~ /^(ssh-|ecdsa-|sk-)/) {
                        for (j=i+2; j<=NF; j++) printf "%s ", $j
                        exit
                    }
                }
            }')
            comment=$(echo "$comment" | sed 's/[[:space:]]*$//')
            [ -z "$comment" ] && comment="(no comment)"
            
            local fp
            fp=$(__key_fingerprint "$line")
            [ -z "$fp" ] && fp="?"
            
            local type_color="\033[37m"
            case "$type" in
                ssh-ed25519)         type_color="\033[32m" ;;
                ssh-rsa)             type_color="\033[33m" ;;
                ecdsa-*)             type_color="\033[38;5;75m" ;;
                ssh-dss)             type_color="\033[31m" ;;
            esac
            
            local last_seen=""
            if [ "$with_last" = "1" ] && [ -n "$last_log" ] && [ -n "$fp" ] && [ "$fp" != "?" ]; then
                local hit
                hit=$(grep -F "$fp" "$last_log" 2>/dev/null | tail -1 | awk '{print $1" "$2" "$3}')
                [ -n "$hit" ] && last_seen=" \033[90mlast: $hit\033[0m"
            fi
            
            printf "    \033[90m%3d)\033[0m ${type_color}%-15s\033[0m %s\n" "$global_idx" "$type" "$comment"
            printf "         \033[90mfp: %s\033[0m%b\n" "$fp" "$last_seen"
            
        done < <(if [ "$(id -u)" -eq 0 ] && [ "$user" != "$(whoami)" ]; then
                    sudo -n cat "$keyfile" 2>/dev/null || cat "$keyfile" 2>/dev/null
                 else
                    cat "$keyfile" 2>/dev/null
                 fi)
        
        echo -e "    \033[90m  $user_count key(s)\033[0m"
    done <<< "$files"
    
    echo ""
    echo -e "  \033[90mTotal: $global_idx key(s) across all users\033[0m"
}

__audit_keys_add() {
    local target_user="${1:-$(whoami)}"
    local key_input="$2"
    
    local home
    home=$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)
    [ -z "$home" ] && { echo "  user not found: $target_user"; return 1; }
    
    local ssh_dir="$home/.ssh"
    local keyfile="$ssh_dir/authorized_keys"
    
    local key=""
    
    if [ -n "$key_input" ]; then
        if [[ "$key_input" =~ ^@ ]]; then
            local file="${key_input#@}"
            file="${file/#\~/$HOME}"
            [ ! -r "$file" ] && { echo "  cannot read: $file"; return 1; }
            key=$(cat "$file")
        else
            key="$key_input"
        fi
    else
        echo "  Paste the public key (one line) then press Enter:"
        read -r key
    fi
    
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -z "$key" ]; then
        echo "  empty key, aborted"
        return 1
    fi
    
    if ! echo "$key" | ssh-keygen -lf - &>/dev/null; then
        echo "  invalid SSH public key"
        echo "  expected format: ssh-ed25519 AAAA... comment"
        return 1
    fi
    
    local fp
    fp=$(__key_fingerprint "$key")
    
    if [ -r "$keyfile" ] && grep -qF "$key" "$keyfile" 2>/dev/null; then
        echo "  key already present (fingerprint: $fp)"
        return 1
    fi
    
    local use_sudo=""
    if [ "$target_user" != "$(whoami)" ] && [ "$(id -u)" -ne 0 ]; then
        if sudo -n true 2>/dev/null; then
            use_sudo="sudo"
        else
            echo "  need root to modify $target_user's keys"
            return 1
        fi
    fi
    
    $use_sudo mkdir -p "$ssh_dir"
    $use_sudo chmod 700 "$ssh_dir"
    $use_sudo touch "$keyfile"
    $use_sudo chmod 600 "$keyfile"
    
    if [ "$target_user" != "$(whoami)" ]; then
        $use_sudo chown "$target_user:$target_user" "$ssh_dir" "$keyfile" 2>/dev/null
    fi
    
    echo "$key" | $use_sudo tee -a "$keyfile" >/dev/null
    
    echo -e "  \033[32m✓\033[0m key added for ${target_user}"
    echo -e "  \033[90m  fingerprint: $fp\033[0m"
}

__audit_keys_remove() {
    local target_user="$1"
    local key_id="$2"
    
    [ -z "$key_id" ] && { echo "  usage: audit-keys -r <n>  (use audit-keys to see numbers)"; return 1; }
    [[ ! "$key_id" =~ ^[0-9]+$ ]] && { echo "  invalid id: $key_id"; return 1; }
    
    if [ ! -f /tmp/.audit_keys_index ]; then
        echo "  run 'audit-keys' first to build index"
        return 1
    fi
    
    local entry
    entry=$(grep "^${key_id}|" /tmp/.audit_keys_index)
    [ -z "$entry" ] && { echo "  no key #$key_id in last list"; return 1; }
    
    local user keyfile lineno
    user=$(echo "$entry" | cut -d'|' -f2)
    keyfile=$(echo "$entry" | cut -d'|' -f3)
    lineno=$(echo "$entry" | cut -d'|' -f4)
    
    local line_content
    if [ "$(id -u)" -eq 0 ] || [ "$user" = "$(whoami)" ]; then
        line_content=$(sed -n "${lineno}p" "$keyfile" 2>/dev/null)
    else
        line_content=$(sudo -n sed -n "${lineno}p" "$keyfile" 2>/dev/null)
    fi
    
    local comment
    comment=$(echo "$line_content" | awk '{for(i=3;i<=NF;i++) printf "%s ",$i}')
    
    echo -e "  \033[31m✗ About to remove:\033[0m"
    echo -e "    user:    $user"
    echo -e "    keyfile: $keyfile"
    echo -e "    line:    $lineno"
    echo -e "    comment: ${comment:-?}"
    echo ""
    read -p "  Type 'yes' to confirm: " ans
    [ "$ans" != "yes" ] && { echo "  cancelled"; return; }
    
    local backup="${keyfile}.bak.$(date +%s)"
    
    if [ "$(id -u)" -eq 0 ] || [ "$user" = "$(whoami)" ]; then
        cp "$keyfile" "$backup"
        sed -i "${lineno}d" "$keyfile"
    else
        sudo -n cp "$keyfile" "$backup"
        sudo -n sed -i "${lineno}d" "$keyfile"
    fi
    
    echo -e "  \033[32m✓\033[0m removed (backup: $backup)"
}

__audit_keys_check() {
    echo -e "  \033[37mSSH key sanity check:\033[0m"
    echo ""
    
    local issues=0
    local seen_fps=""
    
    while IFS='|' read -r user keyfile; do
        [ -z "$user" ] && continue
        
        local perms
        perms=$(stat -c '%a' "$keyfile" 2>/dev/null)
        if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
            printf "  \033[33m⚠\033[0m %s: permissions are %s (recommend 600)\n" "$keyfile" "$perms"
            issues=$((issues + 1))
        fi
        
        local ssh_dir
        ssh_dir=$(dirname "$keyfile")
        local dperms
        dperms=$(stat -c '%a' "$ssh_dir" 2>/dev/null)
        if [ "$dperms" != "700" ]; then
            printf "  \033[33m⚠\033[0m %s: dir permissions are %s (recommend 700)\n" "$ssh_dir" "$dperms"
            issues=$((issues + 1))
        fi
        
        local owner
        owner=$(stat -c '%U' "$keyfile" 2>/dev/null)
        if [ "$owner" != "$user" ]; then
            printf "  \033[31m✗\033[0m %s: owned by %s, expected %s\n" "$keyfile" "$owner" "$user"
            issues=$((issues + 1))
        fi
        
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            
            if echo "$line" | grep -q "^ssh-dss"; then
                printf "  \033[31m✗\033[0m %s: weak DSA key found\n" "$keyfile"
                issues=$((issues + 1))
            fi
            
            if echo "$line" | grep -q "^ssh-rsa"; then
                local bits
                bits=$(echo "$line" | ssh-keygen -lf - 2>/dev/null | awk '{print $1}')
                if [ -n "$bits" ] && [ "$bits" -lt 2048 ]; then
                    printf "  \033[31m✗\033[0m %s: short RSA key (%s bits)\n" "$keyfile" "$bits"
                    issues=$((issues + 1))
                fi
            fi
            
            local fp
            fp=$(__key_fingerprint "$line")
            if [ -n "$fp" ] && [[ "$seen_fps" == *"$fp"* ]]; then
                printf "  \033[33m⚠\033[0m %s: duplicate key (%s)\n" "$keyfile" "$fp"
                issues=$((issues + 1))
            fi
            seen_fps="${seen_fps} ${fp}"
            
        done < <(if [ "$(id -u)" -eq 0 ]; then
                    cat "$keyfile" 2>/dev/null
                 elif [ -r "$keyfile" ]; then
                    cat "$keyfile" 2>/dev/null
                 fi)
        
    done < <(__authorized_keys_files)
    
    echo ""
    if [ "$issues" -eq 0 ]; then
        echo -e "  \033[32m✓\033[0m no issues found"
    else
        echo -e "  \033[33mFound $issues issue(s)\033[0m"
    fi
}

_auditkeys_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    case "$prev" in
        -u|--user)
            local users
            users=$(awk -F: '$3 >= 1000 || $1 == "root" {print $1}' /etc/passwd 2>/dev/null)
            COMPREPLY=( $(compgen -W "$users" -- "$cur") )
            ;;
        *)
            COMPREPLY=( $(compgen -W "-a -r -u -e -c -h --add --remove --user --last --check --help" -- "$cur") )
            ;;
    esac
}
complete -F _auditkeys_complete audit-keys