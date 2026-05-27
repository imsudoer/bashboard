#!/bin/bash

__WIKI_DIR="$HOME/.sutd/data/wiki"
mkdir -p "$__WIKI_DIR"

wikinote() {
    local cmd="$1"
    
    case "$cmd" in
        ""|ls|list)
            __wiki_list
            ;;
        new|add)
            __wiki_new "$2"
            ;;
        rm|remove)
            __wiki_rm "$2"
            ;;
        search|grep|find)
            shift
            __wiki_search "$*"
            ;;
        tag)
            shift
            __wiki_tag "$@"
            ;;
        tags)
            __wiki_tags
            ;;
        export)
            __wiki_export "$2"
            ;;
        cat|show)
            __wiki_show "$2"
            ;;
        -h|--help)
            cat << 'EOF'
  wikinote — personal wiki

  wikinote                       list all pages
  wikinote new <name>            create page (opens in $EDITOR)
  wikinote <name>                edit existing page
  wikinote show <name>           print to terminal
  wikinote rm <name>             delete page
  wikinote search "<text>"       full-text search
  wikinote tag <name> t1 t2      tag a page
  wikinote tags                  list all tags
  wikinote export <name>         export to ~/.sutd/data/helpme/
  wikinote -h                    this help

  All pages stored as markdown in:
    ~/.sutd/data/wiki/*.md
EOF
            ;;
        *)
            local file="$__WIKI_DIR/${cmd}.md"
            if [ -f "$file" ]; then
                ${EDITOR:-nano} "$file"
            else
                echo "  no such page: $cmd"
                echo "  create with:  wikinote new $cmd"
            fi
            ;;
    esac
}

__wiki_list() {
    local count=0
    
    if [ -z "$(ls "$__WIKI_DIR" 2>/dev/null)" ]; then
        echo "  (no wiki pages)"
        echo "  create one with:  wikinote new <name>"
        return
    fi
    
    echo -e "  \033[37mWiki pages:\033[0m"
    
    for f in "$__WIKI_DIR"/*.md; do
        [ -f "$f" ] || continue
        local name=$(basename "$f" .md)
        local title=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //')
        [ -z "$title" ] && title="(no title)"
        
        local tags=""
        local tagline=$(grep -m1 '^tags:' "$f" 2>/dev/null | sed 's/^tags:[[:space:]]*//')
        [ -n "$tagline" ] && tags=" \033[90m[$tagline]\033[0m"
        
        local mtime
        mtime=$(stat -c %Y "$f" 2>/dev/null)
        local mdate=""
        [ -n "$mtime" ] && mdate=$(date -d "@$mtime" '+%m-%d' 2>/dev/null)
        
        printf "    \033[38;5;208m▸\033[0m %-20s \033[37m%s\033[0m\033[90m  %s\033[0m%b\n" \
            "$name" "$title" "$mdate" "$tags"
        count=$((count+1))
    done
    
    echo ""
    echo -e "  \033[90mTotal: $count page(s)\033[0m"
}

__wiki_new() {
    local name="$1"
    [ -z "$name" ] && { echo "  usage: wikinote new <name>"; return 1; }
    
    name=$(echo "$name" | sed 's/[^a-zA-Z0-9_-]/-/g')
    
    local file="$__WIKI_DIR/${name}.md"
    
    if [ -f "$file" ]; then
        echo "  page exists, opening for edit"
    else
        cat > "$file" << EOF
# ${name}

tags:

Created: $(date '+%Y-%m-%d %H:%M')

---

Write your notes here.
EOF
        echo -e "  \033[32m✓\033[0m created: $name"
    fi
    
    ${EDITOR:-nano} "$file"
}

__wiki_rm() {
    local name="$1"
    [ -z "$name" ] && { echo "  usage: wikinote rm <name>"; return 1; }
    
    local file="$__WIKI_DIR/${name}.md"
    [ ! -f "$file" ] && { echo "  no such page: $name"; return 1; }
    
    read -p "  Delete '$name'? [y/N]: " ans
    [[ ! "$ans" =~ ^[yY]$ ]] && { echo "  cancelled"; return; }
    
    rm -f "$file"
    echo -e "  \033[31m✗\033[0m deleted: $name"
}

__wiki_search() {
    local pattern="$1"
    [ -z "$pattern" ] && { echo "  usage: wikinote search \"<text>\""; return 1; }
    
    echo -e "  \033[37mSearching for '\033[38;5;208m$pattern\033[37m':\033[0m"
    
    local found=0
    
    for f in "$__WIKI_DIR"/*.md; do
        [ -f "$f" ] || continue
        local matches
        matches=$(grep -in --color=never "$pattern" "$f" 2>/dev/null)
        if [ -n "$matches" ]; then
            local name=$(basename "$f" .md)
            echo ""
            echo -e "  \033[38;5;208m▸ ${name}\033[0m"
            echo "$matches" | while IFS= read -r line; do
                local lineno="${line%%:*}"
                local content="${line#*:}"
                content=$(echo "$content" | sed "s/${pattern}/\\\033[33m&\\\033[0m/gi")
                printf "    \033[90m%4s)\033[0m %b\n" "$lineno" "$content"
            done
            found=1
        fi
    done
    
    [ "$found" -eq 0 ] && echo -e "  \033[90m  (no matches)\033[0m"
}

__wiki_tag() {
    local name="$1"
    shift
    [ -z "$name" ] || [ $# -eq 0 ] && { echo "  usage: wikinote tag <name> tag1 tag2 ..."; return 1; }
    
    local file="$__WIKI_DIR/${name}.md"
    [ ! -f "$file" ] && { echo "  no such page: $name"; return 1; }
    
    local new_tags="$*"
    
    if grep -q '^tags:' "$file"; then
        sed -i "s/^tags:.*/tags: ${new_tags}/" "$file"
    else
        sed -i "2i tags: ${new_tags}\n" "$file"
    fi
    
    echo -e "  \033[32m✓\033[0m tagged '$name' with: $new_tags"
}

__wiki_tags() {
    echo -e "  \033[37mAll tags:\033[0m"
    
    grep -h '^tags:' "$__WIKI_DIR"/*.md 2>/dev/null \
        | sed 's/^tags:[[:space:]]*//' \
        | tr ' ' '\n' \
        | grep -v '^$' \
        | sort | uniq -c | sort -rn \
        | while read count tag; do
            printf "    \033[38;5;208m▸\033[0m %-20s \033[90m(%s)\033[0m\n" "$tag" "$count"
        done
}

__wiki_show() {
    local name="$1"
    [ -z "$name" ] && { echo "  usage: wikinote show <name>"; return 1; }
    
    local file="$__WIKI_DIR/${name}.md"
    [ ! -f "$file" ] && { echo "  no such page: $name"; return 1; }
    
    while IFS= read -r line; do
        case "$line" in
            "# "*)  echo -e "\033[38;5;208m${line#\# }\033[0m" ;;
            "## "*) echo -e "\n\033[37m▸ ${line#\#\# }\033[0m" ;;
            "### "*) echo -e "\033[37m  ${line#\#\#\# }\033[0m" ;;
            "    "*) echo -e "\033[38;5;75m${line}\033[0m" ;;
            "- "*) echo -e "  ${line}" ;;
            tags:*) echo -e "\033[90m${line}\033[0m" ;;
            "---") echo -e "\033[90m──────────────────────\033[0m" ;;
            *) echo "  $line" ;;
        esac
    done < "$file"
}

__wiki_export() {
    local name="$1"
    [ -z "$name" ] && { echo "  usage: wikinote export <name>"; return 1; }
    
    local src="$__WIKI_DIR/${name}.md"
    local dst="$HOME/.sutd/data/helpme/${name}.md"
    
    [ ! -f "$src" ] && { echo "  no such page: $name"; return 1; }
    
    cp "$src" "$dst"
    echo -e "  \033[32m✓\033[0m exported to helpme: $dst"
    echo -e "  \033[90m  now available as: helpme $name\033[0m"
}

_wikinote_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    case "$prev" in
        wikinote)
            local names
            names=$(ls "$__WIKI_DIR" 2>/dev/null | sed 's/\.md$//')
            COMPREPLY=( $(compgen -W "$names new ls rm search tag tags show export -h" -- "$cur") )
            ;;
        new|rm|tag|show|export)
            local names
            names=$(ls "$__WIKI_DIR" 2>/dev/null | sed 's/\.md$//')
            COMPREPLY=( $(compgen -W "$names" -- "$cur") )
            ;;
    esac
}
complete -F _wikinote_complete wikinote