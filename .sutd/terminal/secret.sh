#!/bin/bash

# :helpme:
# title: Secret Manager
# desc: Encrypted secrets store using openssl AES-256
# category: security
# usage:
#   secret add <name>           prompts for value, stores encrypted
#   secret get <name>           prompts for master password, prints value
#   secret cp <name>            copy to clipboard (if available)
#   secret list                 list names (values stay encrypted)
#   secret rm <name>            remove
#   secret rename <old> <new>
#   secret export               dump all to stdout (asks confirmation)
#   secret import <file>        load from plaintext file (key=value lines)
#   secret change-password      change master password
# examples:
#   secret add db-password
#   secret get db-password
#   secret list
# :endhelpme:

__SECRETS_FILE="$HOME/.sutd/data/secrets.enc"
__SECRETS_DIR=$(dirname "$__SECRETS_FILE")
mkdir -p "$__SECRETS_DIR"
chmod 700 "$__SECRETS_DIR"

__secret_check_openssl() {
    if ! command -v openssl &>/dev/null; then
        echo -e "  \033[31m✗\033[0m openssl not installed"
        return 1
    fi
}

__secret_ask_password() {
    local prompt="${1:-master password}"
    local password
    read -rsp "  ${prompt}: " password
    echo "" >&2
    echo "$password"
}

__secret_read_store() {
    local password="$1"
    
    if [ ! -f "$__SECRETS_FILE" ]; then
        echo ""
        return 0
    fi
    
    local decoded
    decoded=$(openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 \
        -in "$__SECRETS_FILE" -pass "pass:$password" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    echo "$decoded"
}

__secret_write_store() {
    local password="$1"
    local content="$2"
    
    local tmp_out="${__SECRETS_FILE}.tmp"
    
    echo "$content" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
        -out "$tmp_out" -pass "pass:$password" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        rm -f "$tmp_out"
        return 1
    fi
    
    mv "$tmp_out" "$__SECRETS_FILE"
    chmod 600 "$__SECRETS_FILE"
}

secret() {
    __secret_check_openssl || return 1
    
    local cmd="$1"
    shift
    
    case "$cmd" in
        add)        __secret_add "$@" ;;
        get)        __secret_get "$@" ;;
        cp|copy)    __secret_cp "$@" ;;
        list|ls)    __secret_list "$@" ;;
        rm|remove)  __secret_rm "$@" ;;
        rename|mv)  __secret_rename "$@" ;;
        export)     __secret_export "$@" ;;
        import)     __secret_import "$@" ;;
        change-password|chpw) __secret_chpw "$@" ;;
        -h|--help|"")
            cat << 'EOF'
  secret — encrypted password store

  secret add <name>           prompts for value, stores encrypted
  secret get <name>           prompts for master password, prints value
  secret cp <name>            copy value to clipboard
  secret list                 list names (without values)
  secret rm <name>            remove entry
  secret rename <old> <new>   rename entry
  secret export               dump all entries to stdout
  secret import <file>        load from key=value file
  secret change-password      change master password

  Store: ~/.sutd/data/secrets.enc (AES-256-CBC, PBKDF2)
EOF
            ;;
        *)
            echo "  unknown: $cmd"
            secret -h
            return 1
            ;;
    esac
}

__secret_add() {
    local name="$1"
    [ -z "$name" ] && { echo "  usage: secret add <name>"; return 1; }
    
    local master
    master=$(__secret_ask_password)
    [ -z "$master" ] && { echo -e "  \033[31m✗\033[0m empty password"; return 1; }
    
    local existing
    existing=$(__secret_read_store "$master")
    if [ $? -ne 0 ]; then
        echo -e "  \033[31m✗\033[0m wrong password or corrupted store"
        return 1
    fi
    
    if echo "$existing" | grep -q "^${name}="; then
        read -p "  '$name' exists. Overwrite? [y/N]: " confirm
        [[ ! "$confirm" =~ ^[yY]$ ]] && { echo "  cancelled"; return; }
        existing=$(echo "$existing" | grep -v "^${name}=")
    fi
    
    local value
    read -rsp "  value for '$name': " value
    echo ""
    [ -z "$value" ] && { echo -e "  \033[31m✗\033[0m empty value"; return 1; }
    
    local updated
    if [ -z "$existing" ]; then
        updated="${name}=${value}"
    else
        updated="${existing}"$'\n'"${name}=${value}"
    fi
    
    __secret_write_store "$master" "$updated"
    
    if [ $? -eq 0 ]; then
        echo -e "  \033[32m✓\033[0m stored: $name"
    else
        echo -e "  \033[31m✗\033[0m failed to encrypt"
        return 1
    fi
}

__secret_get() {
    local name="$1"
    [ -z "$name" ] && { echo "  usage: secret get <name>"; return 1; }
    
    [ ! -f "$__SECRETS_FILE" ] && { echo "  no secrets stored yet"; return 1; }
    
    local master
    master=$(__secret_ask_password)
    
    local content
    content=$(__secret_read_store "$master")
    if [ $? -ne 0 ]; then
        echo -e "  \033[31m✗\033[0m wrong password"
        return 1
    fi
    
    local value
    value=$(echo "$content" | grep "^${name}=" | head -1 | cut -d= -f2-)
    
    if [ -z "$value" ]; then
        echo -e "  \033[33m⚠\033[0m no entry: $name"
        return 1
    fi
    
    echo "$value"
}

__secret_cp() {
    local value
    value=$(__secret_get "$@") || return 1
    
    local copy_cmd=""
    if command -v xclip &>/dev/null; then
        copy_cmd="xclip -selection clipboard"
    elif command -v xsel &>/dev/null; then
        copy_cmd="xsel --clipboard --input"
    elif command -v wl-copy &>/dev/null; then
        copy_cmd="wl-copy"
    elif command -v pbcopy &>/dev/null; then
        copy_cmd="pbcopy"
    fi
    
    if [ -n "$copy_cmd" ]; then
        echo -n "$value" | $copy_cmd
        echo -e "  \033[32m✓\033[0m copied to clipboard"
    else
        local clip_file="$HOME/.sutd/data/clipboard.txt"
        echo -n "$value" > "$clip_file"
        chmod 600 "$clip_file"
        echo -e "  \033[33m⚠\033[0m no clipboard tool, saved to: $clip_file"
    fi
}

__secret_list() {
    [ ! -f "$__SECRETS_FILE" ] && { echo "  no secrets stored yet"; return; }
    
    local master
    master=$(__secret_ask_password)
    
    local content
    content=$(__secret_read_store "$master")
    if [ $? -ne 0 ]; then
        echo -e "  \033[31m✗\033[0m wrong password"
        return 1
    fi
    
    [ -z "$content" ] && { echo "  (empty)"; return; }
    
    local count=0
    echo -e "  \033[37mStored secrets:\033[0m"
    echo "$content" | while IFS='=' read -r key val; do
        [ -z "$key" ] && continue
        local masked=$(echo "$val" | head -c 3)
        printf "    \033[38;5;208m▸\033[0m %-25s \033[90m%s***\033[0m\n" "$key" "$masked"
        count=$((count + 1))
    done
    
    local total=$(echo "$content" | grep -c '=')
    echo ""
    echo -e "  \033[90m── $total entries\033[0m"
}

__secret_rm() {
    local name="$1"
    [ -z "$name" ] && { echo "  usage: secret rm <name>"; return 1; }
    
    [ ! -f "$__SECRETS_FILE" ] && { echo "  no secrets stored"; return 1; }
    
    local master
    master=$(__secret_ask_password)
    
    local content
    content=$(__secret_read_store "$master")
    if [ $? -ne 0 ]; then
        echo -e "  \033[31m✗\033[0m wrong password"
        return 1
    fi
    
    if ! echo "$content" | grep -q "^${name}="; then
        echo -e "  \033[33m⚠\033[0m no entry: $name"
        return 1
    fi
    
    local updated=$(echo "$content" | grep -v "^${name}=")
    __secret_write_store "$master" "$updated"
    
    echo -e "  \033[31m✗\033[0m removed: $name"
}

__secret_rename() {
    local old="$1"
    local new="$2"
    [ -z "$old" ] || [ -z "$new" ] && { echo "  usage: secret rename <old> <new>"; return 1; }
    
    local master
    master=$(__secret_ask_password)
    
    local content
    content=$(__secret_read_store "$master")
    if [ $? -ne 0 ]; then
        echo -e "  \033[31m✗\033[0m wrong password"
        return 1
    fi
    
    if ! echo "$content" | grep -q "^${old}="; then
        echo -e "  \033[33m⚠\033[0m no entry: $old"
        return 1
    fi
    
    local updated=$(echo "$content" | sed "s/^${old}=/${new}=/")
    __secret_write_store "$master" "$updated"
    
    echo -e "  \033[32m✓\033[0m renamed: $old → $new"
}

__secret_export() {
    [ ! -f "$__SECRETS_FILE" ] && { echo "  no secrets stored"; return 1; }
    
    echo -e "  \033[31m⚠ This will print all secrets in PLAIN TEXT\033[0m"
    read -p "  Type 'yes' to confirm: " confirm
    [ "$confirm" != "yes" ] && { echo "  cancelled"; return; }
    
    local master
    master=$(__secret_ask_password)
    
    local content
    content=$(__secret_read_store "$master")
    if [ $? -ne 0 ]; then
        echo -e "  \033[31m✗\033[0m wrong password"
        return 1
    fi
    
    echo ""
    echo "$content"
}

__secret_import() {
    local file="$1"
    [ -z "$file" ] || [ ! -f "$file" ] && { echo "  usage: secret import <file>"; return 1; }
    
    local imported=$(cat "$file" | grep '=' | grep -v '^#')
    [ -z "$imported" ] && { echo "  no valid entries in file"; return 1; }
    
    local master
    master=$(__secret_ask_password)
    
    local existing=""
    if [ -f "$__SECRETS_FILE" ]; then
        existing=$(__secret_read_store "$master")
        if [ $? -ne 0 ]; then
            echo -e "  \033[31m✗\033[0m wrong password"
            return 1
        fi
    fi
    
    local merged
    if [ -z "$existing" ]; then
        merged="$imported"
    else
        merged="${existing}"$'\n'"${imported}"
    fi
    
    merged=$(echo "$merged" | awk -F= '!seen[$1]++')
    
    __secret_write_store "$master" "$merged"
    
    local count=$(echo "$imported" | wc -l)
    echo -e "  \033[32m✓\033[0m imported $count entries"
}

__secret_chpw() {
    [ ! -f "$__SECRETS_FILE" ] && { echo "  no secrets to re-encrypt"; return; }
    
    local old new confirm
    old=$(__secret_ask_password "current password")
    
    local content
    content=$(__secret_read_store "$old")
    if [ $? -ne 0 ]; then
        echo -e "  \033[31m✗\033[0m wrong password"
        return 1
    fi
    
    new=$(__secret_ask_password "new password")
    [ -z "$new" ] && { echo -e "  \033[31m✗\033[0m empty"; return 1; }
    
    confirm=$(__secret_ask_password "confirm new password")
    [ "$new" != "$confirm" ] && { echo -e "  \033[31m✗\033[0m mismatch"; return 1; }
    
    __secret_write_store "$new" "$content"
    
    echo -e "  \033[32m✓\033[0m password changed"
}

_secret_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    case "$prev" in
        secret)
            COMPREPLY=( $(compgen -W "add get cp list rm rename export import change-password -h" -- "$cur") )
            ;;
    esac
}
complete -F _secret_complete secret