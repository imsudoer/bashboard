#!/bin/bash

# :helpme:
# title: Help Center
# desc: Interactive documentation hub with TUI and web export
# category: docs
# usage:
#   helpme                       interactive TUI browser
#   helpme <topic>               jump to specific page
#   helpme -l                    list all topics
#   helpme -s <pattern>          search across all docs
#   helpme -w [port]             serve over HTTP
#   helpme --refresh             rebuild content index
#   helpme -h                    this help
# examples:
#   helpme
#   helpme al
#   helpme -s "git status"
#   helpme -w 8765
# :endhelpme:

__HELPME_DIR="$HOME/.sutd/data/helpme"
__HELPME_DOCS="$HOME/.sutd/docs"
__HELPME_TERMINAL="$HOME/.sutd/terminal"
__HELPME_CACHE="$HOME/.sutd/data/.helpme_index"
__HELPME_TEMPLATE="$HOME/.sutd/data/.helpme_template.html"

mkdir -p "$__HELPME_DIR"

# ──────────────────────────────────────────────────────────────────────
# inline-doc extraction (from terminal/*.sh :helpme: blocks)
# ──────────────────────────────────────────────────────────────────────

__helpme_extract_inline() {
    local file="$1"
    [ -z "$file" ] || [ ! -f "$file" ] && return
    
    python3 - "$file" << 'PYEOF'
import sys, os

fp = sys.argv[1]
if not os.path.isfile(fp):
    sys.exit(0)

in_block = False
with open(fp, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.rstrip('\n')
        if line.startswith('# :helpme:'):
            in_block = True
            continue
        if line.startswith('# :endhelpme:'):
            in_block = False
            continue
        if in_block:
            stripped = line
            if stripped.startswith('# '):
                stripped = stripped[2:]
            elif stripped.startswith('#'):
                stripped = stripped[1:]
            print(stripped)
PYEOF
}

__helpme_parse_inline() {
    local file="$1"
    local block
    block=$(__helpme_extract_inline "$file")
    [ -z "$block" ] && return 1
    
    local title="" desc="" category="terminal" usage="" examples=""
    local cur=""
    
    while IFS= read -r line; do
        case "$line" in
            "title:"*)    title="${line#title:}";       title="${title# }";       cur="" ;;
            "desc:"*)     desc="${line#desc:}";         desc="${desc# }";         cur="" ;;
            "category:"*) category="${line#category:}"; category="${category# }"; cur="" ;;
            "usage:")     cur="usage" ;;
            "examples:")  cur="examples" ;;
            *)
                case "$cur" in
                    usage)    usage+="${line}"$'\n' ;;
                    examples) examples+="${line}"$'\n' ;;
                esac
                ;;
        esac
    done <<< "$block"
    
    [ -z "$title" ] && return 1
    
    cat << EOF
TITLE=$title
DESC=$desc
CATEGORY=$category
USAGE_START
$usage
USAGE_END
EXAMPLES_START
$examples
EXAMPLES_END
EOF
    return 0
}

__helpme_parse_frontmatter() {
    local file="$1"
    [ -z "$file" ] || [ ! -f "$file" ] && return
    
    python3 - "$file" << 'PYEOF'
import sys, os
fp = sys.argv[1]
if not os.path.isfile(fp):
    sys.exit(0)
with open(fp, 'r', encoding='utf-8', errors='replace') as f:
    lines = f.read().split('\n')
if not lines or lines[0].strip() != '---':
    sys.exit(0)
for line in lines[1:]:
    if line.strip() == '---':
        break
    if ':' not in line:
        continue
    key, _, val = line.partition(':')
    key = key.strip().upper()
    val = val.strip()
    if val.startswith('"') and val.endswith('"'):
        val = val[1:-1]
    print(f"FM_{key}={val}")
PYEOF
}

__helpme_extract_funcs() {
    local file="$1"
    [ -f "$file" ] || return
    
    local fname
    fname=$(basename "$file" .sh)
    
    # primary: function name = file name
    # for files like mvr-cpr.sh containing multiple commands,
    # split by dash and treat each part as a potential function
    
    local candidates=()
    
    # 1) full filename as function name
    candidates+=("$fname")
    
    # 2) if filename contains "-", treat each part as candidate
    if [[ "$fname" == *-* ]]; then
        local IFS='-'
        for part in $fname; do
            [ -n "$part" ] && candidates+=("$part")
        done
    fi
    
    # filter: only output names that actually exist as functions in the file
    # (defined as: name() {  or  function name {  on its own line)
    local found=()
    for cand in "${candidates[@]}"; do
        if grep -qE "^[[:space:]]*(function[[:space:]]+)?${cand}[[:space:]]*\(\)" "$file" 2>/dev/null; then
            found+=("$cand")
        fi
    done
    
    printf '%s\n' "${found[@]}" | sort -u
}

__helpme_get_help_output() {
    local file="$1"
    local func="$2"
    
    (
        unset PROMPT_COMMAND
        trap - DEBUG
        
        source "$file" 2>/dev/null
        
        if declare -F "$func" &>/dev/null; then
            "$func" -h 2>&1 || "$func" --help 2>&1 || true
        fi
    ) 2>/dev/null | head -80
}

__helpme_build_index() {
    local idx="$__HELPME_CACHE"
    > "$idx"
    
    local NUL="-"
    
    # 1) docs/*.md
    if [ -d "$__HELPME_DOCS" ]; then
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            local rel="${f#$__HELPME_DOCS/}"
            local slug
            slug=$(echo "$rel" | sed 's|/|--|g; s|\.md$||')
            
            local title="$slug" desc="$NUL" order=999 badge="$NUL" parent="$NUL"
            local fm
            fm=$(__helpme_parse_frontmatter "$f")
            
            while IFS= read -r line; do
                case "$line" in
                    FM_TITLE=*)       title="${line#FM_TITLE=}" ;;
                    FM_DESCRIPTION=*) desc="${line#FM_DESCRIPTION=}" ;;
                    FM_ORDER=*)       order="${line#FM_ORDER=}" ;;
                    FM_BADGE=*)       badge="${line#FM_BADGE=}" ;;
                    FM_PARENT=*)      parent="${line#FM_PARENT=}" ;;
                esac
            done <<< "$fm"
            
            title=$(printf '%s' "$title" | tr -d '\t\n\r')
            desc=$(printf '%s' "$desc" | tr -d '\t\n\r')
            badge=$(printf '%s' "$badge" | tr -d '\t\n\r')
            parent=$(printf '%s' "$parent" | tr -d '\t\n\r')
            [ -z "$desc" ]   && desc="$NUL"
            [ -z "$badge" ]  && badge="$NUL"
            [ -z "$parent" ] && parent="$NUL"
            [ -z "$order" ]  && order=999
            
            printf 'docs\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$slug" "$title" "$desc" "$f" "$order" "$badge" "$parent" >> "$idx"
        done < <(find "$__HELPME_DOCS" -name "*.md" -type f 2>/dev/null | sort)
    fi
    
    # 2) data/helpme/*.md
    if [ -d "$__HELPME_DIR" ]; then
        for f in "$__HELPME_DIR"/*.md; do
            [ -f "$f" ] || continue
            local name title
            name=$(basename "$f" .md)
            title=$(head -1 "$f" | sed -e 's/^#[[:space:]]*//' -e 's/[[:cntrl:]]//g' -e 's/\t/ /g')
            [ -z "$title" ] && title="$name"
            printf 'user\t%s\t%s\t%s\t%s\t500\t%s\t%s\n' \
                "$name" "$title" "$NUL" "$f" "$NUL" "$NUL" >> "$idx"
        done
    fi
    
    # 3) terminal/*.sh
    if [ -d "$__HELPME_TERMINAL" ]; then
        for f in "$__HELPME_TERMINAL"/*.sh; do
            [ -f "$f" ] || continue
            local fname=$(basename "$f" .sh)
            
            local parsed
            parsed=$(__helpme_parse_inline "$f" 2>/dev/null)
            
            if [ -n "$parsed" ]; then
                local title="" desc="" category="terminal"
                while IFS= read -r line; do
                    case "$line" in
                        TITLE=*)    title="${line#TITLE=}" ;;
                        DESC=*)     desc="${line#DESC=}" ;;
                        CATEGORY=*) category="${line#CATEGORY=}" ;;
                    esac
                done <<< "$parsed"
                
                [ -z "$title" ] && title="$fname"
                title=$(printf '%s' "$title" | tr -d '\t\n\r')
                desc=$(printf '%s' "$desc" | tr -d '\t\n\r')
                [ -z "$desc" ] && desc="$NUL"
                
                printf 'terminal\t%s\t%s\t%s\t%s\t300\t%s\t%s\n' \
                    "$fname" "$title" "$desc" "$f" "$NUL" "$category" >> "$idx"
            else
                local funcs
                funcs=$(__helpme_extract_funcs "$f")
                
                if [ -z "$funcs" ]; then
                    continue
                fi
                
                while IFS= read -r func; do
                    [ -z "$func" ] && continue
                    [ "$func" = "complete" ] && continue
                    [ "$func" = "alias" ] && continue
                    
                    local help_out
                    help_out=$(__helpme_get_help_output "$f" "$func")
                    
                    if [ -z "$help_out" ] || \
                       echo "$help_out" | grep -qi "unknown\|invalid option\|not a function" ; then
                        local entry_slug="${func}"
                        local entry_title="${func}"
                        local entry_desc="(no docs — try: ${func} -h)"
                        entry_title=$(printf '%s' "$entry_title" | tr -d '\t\n\r')
                        entry_desc=$(printf '%s' "$entry_desc" | tr -d '\t\n\r')
                        
                        printf 'terminal\t%s\t%s\t%s\t%s\t400\t%s\t%s\n' \
                            "$entry_slug" "$entry_title" "$entry_desc" "$f" "$NUL" "auto" >> "$idx"
                        continue
                    fi
                    
                    local first_desc
                    first_desc=$(echo "$help_out" | grep -v "^[[:space:]]*$" \
                                                  | grep -v "^[[:space:]]*Usage" \
                                                  | grep -v "^[[:space:]]*usage" \
                                                  | head -1 \
                                                  | sed -e 's/^[[:space:]]*//' \
                                                        -e 's/[[:space:]]*$//' \
                                                        -e 's/^—[[:space:]]*//' \
                                                        -e 's/[[:cntrl:]]//g' \
                                                        -e 's/\t/ /g')
                    
                    first_desc=$(echo "$first_desc" | sed -E "s/^${func}[[:space:]]*[—-]?[[:space:]]*//")
                    
                    [ -z "$first_desc" ] && first_desc="(from --help)"
                    
                    local entry_title="$func"
                    entry_title=$(printf '%s' "$entry_title" | tr -d '\t\n\r')
                    first_desc=$(printf '%s' "$first_desc" | tr -d '\t\n\r')
                    
                    printf 'terminal\t%s\t%s\t%s\t%s\t400\t%s\t%s\n' \
                        "$func" "$entry_title" "$first_desc" "$f" "$NUL" "auto" >> "$idx"
                done <<< "$funcs"
            fi
        done
    fi
}

__helpme_unnul() {
    [ "$1" = "-" ] && echo "" || echo "$1"
}

__helpme_index_stale() {
    [ ! -f "$__HELPME_CACHE" ] && return 0
    
    local newest
    newest=$(find "$__HELPME_TERMINAL" "$__HELPME_DOCS" "$__HELPME_DIR" \
        \( -name "*.sh" -o -name "*.md" \) -newer "$__HELPME_CACHE" 2>/dev/null | head -1)
    
    [ -n "$newest" ] && return 0
    return 1
}

# ──────────────────────────────────────────────────────────────────────
# terminal renderers (for `helpme <topic>` and TUI preview)
# ──────────────────────────────────────────────────────────────────────

__helpme_render_inline() {
    local file="$1"
    local parsed
    parsed=$(__helpme_parse_inline "$file")
    [ -z "$parsed" ] && { echo "  (no inline docs)"; return; }
    
    local title="" desc="" usage="" examples=""
    local in_usage=0 in_examples=0
    
    while IFS= read -r line; do
        case "$line" in
            TITLE=*)        title="${line#TITLE=}" ;;
            DESC=*)         desc="${line#DESC=}" ;;
            USAGE_START)    in_usage=1; continue ;;
            USAGE_END)      in_usage=0; continue ;;
            EXAMPLES_START) in_examples=1; continue ;;
            EXAMPLES_END)   in_examples=0; continue ;;
            *)
                [ "$in_usage" = "1" ]    && usage+="${line}"$'\n'
                [ "$in_examples" = "1" ] && examples+="${line}"$'\n'
                ;;
        esac
    done <<< "$parsed"
    
    echo -e "\033[1;38;5;208m${title}\033[0m"
    printf '\033[90m'
    printf '─%.0s' $(seq 1 $((${#title} + 2)))
    printf '\033[0m\n\n'
    
    [ -n "$desc" ] && { echo -e "  $desc"; echo ""; }
    
    if [ -n "$usage" ]; then
        echo -e "\033[37m▸ Usage\033[0m"
        echo ""
        echo "$usage" | while IFS= read -r ln; do
            [ -z "$ln" ] && continue
            echo -e "    \033[38;5;75m${ln}\033[0m"
        done
        echo ""
    fi
    
    if [ -n "$examples" ]; then
        echo -e "\033[37m▸ Examples\033[0m"
        echo ""
        echo "$examples" | while IFS= read -r ln; do
            [ -z "$ln" ] && continue
            echo -e "    \033[32m${ln}\033[0m"
        done
        echo ""
    fi
}

__helpme_render_md() {
    local file="$1"
    local in_fm=0 in_code=0 first=1
    
    while IFS= read -r line; do
        if [ "$first" = "1" ] && [ "$line" = "---" ]; then
            in_fm=1; first=0; continue
        fi
        first=0
        
        if [ "$in_fm" = "1" ]; then
            [ "$line" = "---" ] && in_fm=0
            continue
        fi
        
        if [[ "$line" == '```'* ]]; then
            if [ "$in_code" = "0" ]; then
                in_code=1
                echo -e "\033[90m  ┌──────────────────────────────────────\033[0m"
            else
                in_code=0
                echo -e "\033[90m  └──────────────────────────────────────\033[0m"
            fi
            continue
        fi
        
        if [ "$in_code" = "1" ]; then
            echo -e "\033[90m  │\033[0m \033[38;5;75m${line}\033[0m"
            continue
        fi
        
        case "$line" in
            "# "*)
                local content="${line#\# }"
                echo ""
                echo -e "\033[1;38;5;208m${content}\033[0m"
                printf '\033[90m'
                printf '═%.0s' $(seq 1 $((${#content} + 2)))
                printf '\033[0m\n'
                ;;
            "## "*)
                echo ""
                echo -e "\033[1;37m▸ ${line#\#\# }\033[0m"
                ;;
            "### "*)
                echo ""
                echo -e "\033[37m  ${line#\#\#\# }\033[0m"
                ;;
            "- "*|"* "*)
                echo -e "    \033[38;5;208m•\033[0m ${line:2}"
                ;;
            "> "*)
                echo -e "  \033[90m│ ${line#> }\033[0m"
                ;;
            "    "*)
                echo -e "    \033[38;5;75m${line}\033[0m"
                ;;
            "")
                echo ""
                ;;
            *)
                local processed="$line"
                processed=$(echo "$processed" | sed -E "s/\`([^\`]+)\`/$(printf '\033[38;5;75m')\1$(printf '\033[0m')/g")
                processed=$(echo "$processed" | sed -E "s/\*\*([^\*]+)\*\*/$(printf '\033[1m')\1$(printf '\033[0m')/g")
                echo "  $processed"
                ;;
        esac
    done < "$file"
}

# ──────────────────────────────────────────────────────────────────────
# HTML renderers (for web mode) — entirely Python
# ──────────────────────────────────────────────────────────────────────

__helpme_md_to_html() {
    local file="$1"
    [ -z "$file" ] || [ ! -f "$file" ] && return
    
    python3 - "$file" << 'PYEOF'
import sys, os, re, html as htm

fp = sys.argv[1]
if not os.path.isfile(fp):
    sys.exit(0)

with open(fp, 'r', encoding='utf-8', errors='replace') as f:
    text = f.read()

lines = text.split('\n')
out = []
in_pre = False
in_ul = False
in_fm = False

if lines and lines[0].strip() == '---':
    in_fm = True
    lines = lines[1:]

LINK_RE = re.compile(r'\[([^\]]+)\]\(([^\)]+)\)')
CODE_RE = re.compile(r'`([^`]+)`')
BOLD_RE = re.compile(r'\*\*([^\*]+)\*\*')

def inline(s):
    s = CODE_RE.sub(r'<code>\1</code>', s)
    s = BOLD_RE.sub(r'<strong>\1</strong>', s)
    s = LINK_RE.sub(r'<a href="\2">\1</a>', s)
    return s

def close_ul():
    global in_ul
    if in_ul:
        out.append('</ul>')
        in_ul = False

for line in lines:
    if in_fm:
        if line.strip() == '---':
            in_fm = False
        continue
    
    if line.startswith('```'):
        if in_pre:
            out.append('</code></pre>')
            in_pre = False
        else:
            close_ul()
            out.append('<pre><code>')
            in_pre = True
        continue
    
    if in_pre:
        out.append(htm.escape(line))
        continue
    
    esc = htm.escape(line)
    
    if line.startswith('# '):
        close_ul()
        out.append(f'<h1>{inline(esc[2:])}</h1>')
    elif line.startswith('## '):
        close_ul()
        out.append(f'<h2>{inline(esc[3:])}</h2>')
    elif line.startswith('### '):
        close_ul()
        out.append(f'<h3>{inline(esc[4:])}</h3>')
    elif line.startswith('    '):
        close_ul()
        out.append(f'<pre><code>{esc[4:]}</code></pre>')
    elif line.startswith('- ') or line.startswith('* '):
        if not in_ul:
            out.append('<ul>')
            in_ul = True
        out.append(f'<li>{inline(esc[2:])}</li>')
    elif line.startswith('> '):
        close_ul()
        out.append(f'<blockquote>{inline(esc[2:])}</blockquote>')
    elif line.strip() == '':
        close_ul()
    else:
        close_ul()
        out.append(f'<p>{inline(esc)}</p>')

if in_pre:
    out.append('</code></pre>')
close_ul()

print('\n'.join(out))
PYEOF
}

__helpme_inline_to_html() {
    local file="$1"
    local parsed
    parsed=$(__helpme_parse_inline "$file")
    [ -z "$parsed" ] && return
    
    local title="" desc="" usage="" examples=""
    local in_usage=0 in_examples=0
    
    while IFS= read -r line; do
        case "$line" in
            TITLE=*)        title="${line#TITLE=}" ;;
            DESC=*)         desc="${line#DESC=}" ;;
            USAGE_START)    in_usage=1; continue ;;
            USAGE_END)      in_usage=0; continue ;;
            EXAMPLES_START) in_examples=1; continue ;;
            EXAMPLES_END)   in_examples=0; continue ;;
            *)
                [ "$in_usage" = "1" ]    && usage+="${line}"$'\n'
                [ "$in_examples" = "1" ] && examples+="${line}"$'\n'
                ;;
        esac
    done <<< "$parsed"
    
    python3 - << PYEOF
import html as htm
title = """$title"""
desc = """$desc"""
usage = """$usage"""
examples = """$examples"""

print(f"<h1>{htm.escape(title)}</h1>")
if desc.strip():
    print(f'<p class="lead">{htm.escape(desc)}</p>')
if usage.strip():
    print("<h2>Usage</h2>")
    print(f"<pre><code>{htm.escape(usage.rstrip())}</code></pre>")
if examples.strip():
    print("<h2>Examples</h2>")
    print(f"<pre><code>{htm.escape(examples.rstrip())}</code></pre>")
PYEOF
}

__helpme_json_escape() {
    python3 -c '
import sys, json
sys.stdout.write(json.dumps(sys.stdin.read())[1:-1])
'
}

__helpme_render_auto() {
    local file="$1"
    local func="$2"
    
    local help_out
    help_out=$(__helpme_get_help_output "$file" "$func")
    
    if [ -z "$help_out" ]; then
        echo "  (no help available)"
        return
    fi
    
    echo -e "\033[1;38;5;208m${func}\033[0m"
    printf '\033[90m'
    printf '─%.0s' $(seq 1 $((${#func} + 2)))
    printf '\033[0m\n'
    echo -e "\033[90m  auto-extracted from ${func} --help\033[0m\n"
    
    echo "$help_out" | while IFS= read -r line; do
        echo -e "  \033[38;5;75m${line}\033[0m"
    done
    echo ""
}

__helpme_auto_to_html() {
    local file="$1"
    local func="$2"
    
    local help_out
    help_out=$(__helpme_get_help_output "$file" "$func")
    
    python3 - "$func" "$help_out" << 'PYEOF'
import sys, html as htm
func = sys.argv[1]
help_out = sys.argv[2] if len(sys.argv) > 2 else ""

print(f"<h1>{htm.escape(func)}</h1>")
print(f'<p class="lead">Auto-extracted from <code>{htm.escape(func)} --help</code></p>')
if help_out.strip():
    print(f"<pre><code>{htm.escape(help_out)}</code></pre>")
else:
    print("<p>No help output available.</p>")
PYEOF
}

helpme() {
    local force_rebuild=0
    local mode=""
    local query=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -l|--list)    mode="list"; shift ;;
            -s|--search)  mode="search"; query="$2"; shift 2 ;;
            -w|--web)
                mode="web"
                if [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    query="$2"; shift 2
                else
                    query="${HELPME_PORT:-8765}"; shift
                fi
                ;;
            --refresh)    force_rebuild=1; shift ;;
            -h|--help)
                cat << 'EOF'
  helpme — interactive documentation hub

  helpme                       open TUI browser
  helpme <topic>               jump to specific topic
  helpme -l                    list all topics
  helpme -s <pattern>          search all docs
  helpme -w [port]             serve as web (default port 8765)
  helpme --refresh             rebuild content index and exit
  helpme -h                    this help
EOF
                return
                ;;
            *)
                if [ -z "$mode" ]; then
                    mode="show"
                    query="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [ "$force_rebuild" = "1" ]; then
        echo -n "  rebuilding helpme index... "
        __helpme_build_index
        local count
        count=$(wc -l < "$__HELPME_CACHE" 2>/dev/null || echo 0)
        echo -e "\033[32m✓\033[0m (${count} topics)"
        [ -z "$mode" ] && return
    fi
    
    if [ ! -f "$__HELPME_CACHE" ] || __helpme_index_stale; then
        __helpme_build_index
    fi
    
    [ -z "$mode" ] && mode="tui"
    
    case "$mode" in
        list)   __helpme_cmd_list ;;
        search) __helpme_cmd_search "$query" ;;
        web)    __helpme_cmd_web "$query" ;;
        show)   __helpme_cmd_show "$query" ;;
        tui)    __helpme_tui ;;
    esac
}

__helpme_cmd_list() {
    [ ! -s "$__HELPME_CACHE" ] && { echo "  no docs found"; return; }
    
    echo -e "  \033[37mAll documentation topics:\033[0m"
    
    local last_type=""
    while IFS=$'\t' read -r type slug title desc file order badge parent; do
        desc=$(__helpme_unnul "$desc")
        badge=$(__helpme_unnul "$badge")
        parent=$(__helpme_unnul "$parent")
        [ "$file" = "-" ] && file=""
        if [ "$type" != "$last_type" ]; then
            echo ""
            case "$type" in
                docs)     echo -e "  \033[38;5;208m▸ Documentation\033[0m" ;;
                terminal) echo -e "  \033[38;5;208m▸ Terminal Commands\033[0m" ;;
                user)     echo -e "  \033[38;5;208m▸ User Notes\033[0m" ;;
            esac
            last_type="$type"
        fi
        
        local b=""
        [ -n "$badge" ] && b=" \033[33m[$badge]\033[0m"
        
        printf "    \033[37m%-28s\033[0m \033[90m%s\033[0m%b\n" "$slug" "$desc" "$b"
    done < <(sort -t$'\t' -k1,1 -k5,5n "$__HELPME_CACHE")
}

__helpme_cmd_search() {
    local pattern="$1"
    [ -z "$pattern" ] && { echo "  usage: helpme -s <pattern>"; return 1; }
    
    echo -e "  \033[37mSearching for \033[38;5;208m$pattern\033[37m:\033[0m"
    
    local found=0
    
    while IFS=$'\t' read -r type slug title desc file order badge parent; do
        desc=$(__helpme_unnul "$desc")
        badge=$(__helpme_unnul "$badge")
        parent=$(__helpme_unnul "$parent")
        [ "$file" = "-" ] && file=""
        local matches
        matches=$(grep -in --color=never "$pattern" "$file" 2>/dev/null | head -3)
        if [ -n "$matches" ]; then
            found=$((found + 1))
            echo ""
            local icon
            case "$type" in
                docs)     icon="📄" ;;
                terminal) icon="⚡" ;;
                user)     icon="📝" ;;
                *)        icon="·" ;;
            esac
            echo -e "  ${icon} \033[38;5;208m${slug}\033[0m \033[90m— ${title}\033[0m"
            
            echo "$matches" | while IFS= read -r m; do
                local lineno="${m%%:*}"
                local content="${m#*:}"
                content="${content:0:90}"
                printf "      \033[90m%4s)\033[0m %s\n" "$lineno" "$content"
            done
        fi
    done < "$__HELPME_CACHE"
    
    echo ""
    [ "$found" -eq 0 ] && echo -e "  \033[90m(no matches)\033[0m" \
                       || echo -e "  \033[32m$found matching document(s)\033[0m"
}

__helpme_cmd_show() {
    local query="$1"
    
    local entry
    entry=$(awk -F'\t' -v q="$query" '$2 == q' "$__HELPME_CACHE" | head -1)
    [ -z "$entry" ] && entry=$(awk -F'\t' -v q="$query" '$2 ~ q' "$__HELPME_CACHE" | head -1)
    
    if [ -z "$entry" ]; then
        echo "  no topic matching: $query"
        echo "  try: helpme -l"
        return 1
    fi
    
    local type slug title desc file order badge parent
    IFS=$'\t' read -r type slug title desc file order badge parent <<< "$entry"
    
    clear
    
    case "$type" in
        terminal)
            if [ "$parent" = "auto" ]; then
                __helpme_render_auto "$file" "$slug"
            else
                __helpme_render_inline "$file"
            fi
            ;;
        docs|user) __helpme_render_md "$file" ;;
    esac
    
    echo ""
    echo -e "  \033[90m─── ${slug} (${type}) ─── press enter ───\033[0m"
    read -r _
}

# ──────────────────────────────────────────────────────────────────────
# TUI browser
# ──────────────────────────────────────────────────────────────────────

__helpme_tui() {
    if [ ! -t 1 ] || [ ! -t 0 ]; then
        echo "  TUI requires a terminal (not pipe/redirect)"
        echo "  try: helpme -l   or   helpme <topic>"
        return 1
    fi
    
    local entries=() titles=() types=() files=() parents=()

    while IFS=$'\t' read -r type slug title desc file order badge parent; do
        desc=$(__helpme_unnul "$desc")
        badge=$(__helpme_unnul "$badge")
        parent=$(__helpme_unnul "$parent")
        [ "$file" = "-" ] && file=""
        
        entries+=("$slug")
        titles+=("$title")
        types+=("$type")
        files+=("$file")
        parents+=("$parent")
    done < <(sort -t$'\t' -k1,1 -k5,5n "$__HELPME_CACHE")
    
    [ ${#entries[@]} -eq 0 ] && { echo "  no docs — run: helpme --refresh"; return 1; }
    
    tput smcup
    tput civis
    stty -echo
    trap 'tput cnorm; stty echo; tput rmcup; return 0' EXIT INT TERM
    
    local selected=0 scroll=0 filter="" update=1
    local filtered=()
    
    while true; do
        local cols=$(tput cols)
        local rows=$(tput lines)
        local sidebar_w=30
        local content_x=$((sidebar_w + 3))
        local content_w=$((cols - content_x - 2))
        local list_h=$((rows - 6))
        
        if [ "$update" = "1" ]; then
            filtered=()
            for i in "${!entries[@]}"; do
                if [ -z "$filter" ]; then
                    filtered+=("$i")
                else
                    local lf="${filter,,}"
                    local le="${entries[$i],,}"
                    local lt="${titles[$i],,}"
                    if [[ "$le" == *"$lf"* ]] || [[ "$lt" == *"$lf"* ]]; then
                        filtered+=("$i")
                    fi
                fi
            done
            update=0
            [ "$selected" -ge "${#filtered[@]}" ] && selected=$((${#filtered[@]} - 1))
            [ "$selected" -lt 0 ] && selected=0
            scroll=0
        fi
        
        clear
        
        tput cup 0 0
        printf '\033[38;5;208m  ╔ helpme '
        local dashes=$((cols - 14))
        printf '═%.0s' $(seq 1 $dashes)
        printf '╗\033[0m'
        
        tput cup 1 0
        printf '\033[38;5;208m  ║\033[0m '
        if [ -n "$filter" ]; then
            printf "\033[33m  filter: %s_\033[0m" "$filter"
        else
            printf "\033[90m  %d topics  •  / filter  •  ↑↓ nav  •  enter view  •  w web  •  q quit\033[0m" "${#filtered[@]}"
        fi
        tput cup 1 $((cols - 3))
        printf '\033[38;5;208m║\033[0m'
        
        tput cup 2 0
        printf '\033[38;5;208m  ╠'
        printf '═%.0s' $(seq 1 $sidebar_w)
        printf '╤'
        printf '═%.0s' $(seq 1 $((cols - sidebar_w - 5)))
        printf '╣\033[0m'
        
        local visible_start=$scroll
        local visible_end=$((scroll + list_h))
        [ "$visible_end" -gt "${#filtered[@]}" ] && visible_end=${#filtered[@]}
        
        local row=3
        for ((i=visible_start; i<visible_end; i++)); do
            tput cup $row 0
            printf '\033[38;5;208m  ║\033[0m '
            
            local idx="${filtered[$i]}"
            local entry="${entries[$idx]}"
            local etype="${types[$idx]}"
            
            local icon
            case "$etype" in
                docs)     icon="📄" ;;
                terminal) icon="⚡" ;;
                user)     icon="📝" ;;
                *)        icon=" ·" ;;
            esac
            
            local display="${entry:0:22}"
            
            if [ "$i" = "$selected" ]; then
                printf "\033[48;5;237m\033[38;5;208m ▸ %s %-22s \033[0m" "$icon" "$display"
            else
                printf "   %s \033[37m%-22s\033[0m" "$icon" "$display"
            fi
            
            tput cup $row $((sidebar_w + 2))
            printf '\033[38;5;208m│\033[0m'
            
            row=$((row + 1))
        done
        
        while [ "$row" -lt "$((list_h + 3))" ]; do
            tput cup $row 0
            printf '\033[38;5;208m  ║\033[0m'
            tput cup $row $((sidebar_w + 2))
            printf '\033[38;5;208m│\033[0m'
            row=$((row + 1))
        done
        
        if [ "${#filtered[@]}" -gt 0 ]; then
            local sel_idx="${filtered[$selected]}"
            local sel_title="${titles[$sel_idx]}"
            local sel_slug="${entries[$sel_idx]}"
            local sel_type="${types[$sel_idx]}"
            local sel_file="${files[$sel_idx]}"
            
            tput cup 3 $content_x
            printf '\033[1;38;5;208m%s\033[0m' "${sel_title:0:$content_w}"
            
            tput cup 4 $content_x
            printf '\033[90m%s • %s\033[0m' "$sel_slug" "$sel_type"
            
            local preview
            case "$sel_type" in
                terminal)
                    if [ "${parents[$sel_idx]}" = "auto" ]; then
                        preview=$(__helpme_render_auto "$sel_file" "$sel_slug" 2>/dev/null)
                    else
                        preview=$(__helpme_render_inline "$sel_file" 2>/dev/null)
                    fi
                    ;;
                *) preview=$(__helpme_render_md "$sel_file" 2>/dev/null) ;;
            esac
            
            local prow=6
            local max_row=$((list_h + 2))
            
            while IFS= read -r line; do
                [ "$prow" -gt "$max_row" ] && break
                tput cup $prow $content_x
                
                local stripped clip
                stripped=$(printf '%s' "$line" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g')
                if [ "${#stripped}" -gt "$content_w" ]; then
                    clip="${line:0:$((content_w * 2))}"
                else
                    clip="$line"
                fi
                printf '%b' "$clip"
                prow=$((prow + 1))
            done <<< "$preview"
        fi
        
        tput cup $((rows - 2)) 0
        printf '\033[38;5;208m  ╚'
        printf '═%.0s' $(seq 1 $((cols - 5)))
        printf '╝\033[0m'
        
        tput cup $((rows - 1)) 4
        printf '\033[90m↑↓ nav   enter view   / filter   w web   r refresh   q quit\033[0m'
        
        read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key2
            key="$key$key2"
        fi
        
        case "$key" in
            $'\x1b[A'|k)
                [ "$selected" -gt 0 ] && selected=$((selected - 1))
                [ "$selected" -lt "$scroll" ] && scroll=$selected
                ;;
            $'\x1b[B'|j)
                [ "$selected" -lt "$((${#filtered[@]} - 1))" ] && selected=$((selected + 1))
                [ "$selected" -ge "$((scroll + list_h))" ] && scroll=$((selected - list_h + 1))
                ;;
            $'\x1b[5~')
                selected=$((selected - list_h))
                [ "$selected" -lt 0 ] && selected=0
                scroll=$selected
                ;;
            $'\x1b[6~')
                selected=$((selected + list_h))
                [ "$selected" -ge "${#filtered[@]}" ] && selected=$((${#filtered[@]} - 1))
                ;;
            "")
                [ "${#filtered[@]}" -eq 0 ] && continue
                local idx="${filtered[$selected]}"
                local sel_type="${types[$idx]}"
                local sel_file="${files[$idx]}"
                
                tput rmcup
                tput cnorm
                stty echo
                clear
                
                case "$sel_type" in
                    terminal)
                        if [ "${parents[$idx]}" = "auto" ]; then
                            __helpme_render_auto "$sel_file" "${entries[$idx]}"
                        else
                            __helpme_render_inline "$sel_file"
                        fi
                        ;;
                    *) __helpme_render_md "$sel_file" ;;
                esac
                
                echo ""
                echo -e "  \033[90m─── press enter to return ───\033[0m"
                read -r _
                
                tput smcup
                tput civis
                stty -echo
                ;;
            "/")
                tput cup $((rows - 1)) 4
                tput el
                tput cnorm
                stty echo
                printf "\033[33m/\033[0m"
                read -r filter
                tput civis
                stty -echo
                update=1
                selected=0
                ;;
            w|W)
                tput rmcup
                tput cnorm
                stty echo
                __helpme_cmd_web "${HELPME_PORT:-8765}"
                tput smcup
                tput civis
                stty -echo
                ;;
            r|R)
                __helpme_build_index
                entries=(); titles=(); types=(); files=()
                while IFS=$'\t' read -r type slug title desc file order badge parent; do
                    desc=$(__helpme_unnul "$desc")
                    badge=$(__helpme_unnul "$badge")
                    parent=$(__helpme_unnul "$parent")
                    [ "$file" = "-" ] && file=""
                    entries+=("$slug")
                    titles+=("$title")
                    types+=("$type")
                    files+=("$file")
                done < <(sort -t$'\t' -k1,1 -k5,5n "$__HELPME_CACHE")
                update=1
                ;;
            q|Q)
                tput rmcup
                tput cnorm
                stty echo
                trap - EXIT INT TERM
                return
                ;;
            $'\x7f'|$'\b')
                if [ -n "$filter" ]; then
                    filter="${filter%?}"
                    update=1
                fi
                ;;
        esac
    done
}
__helpme_build_topics_json() {
    echo -n "["
    local first=1
    
    while IFS=$'\t' read -r type slug title desc file order badge parent; do
        desc=$(__helpme_unnul "$desc")
        badge=$(__helpme_unnul "$badge")
        parent=$(__helpme_unnul "$parent")
        [ "$file" = "-" ] && file=""
        local body_html
        case "$type" in
            terminal)
                if [ "$parent" = "auto" ]; then
                    body_html=$(__helpme_auto_to_html "$file" "$slug")
                else
                    body_html=$(__helpme_inline_to_html "$file")
                fi
                ;;
            *) body_html=$(__helpme_md_to_html "$file") ;;
        esac
        
        local body_json title_json desc_json slug_json badge_json
        body_json=$(printf '%s' "$body_html" | __helpme_json_escape)
        title_json=$(printf '%s' "$title" | __helpme_json_escape)
        desc_json=$(printf '%s' "$desc" | __helpme_json_escape)
        slug_json=$(printf '%s' "$slug" | __helpme_json_escape)
        badge_json=$(printf '%s' "$badge" | __helpme_json_escape)
        
        [ "$first" = "0" ] && echo -n ","
        first=0
        
        printf '{"slug":"%s","type":"%s","title":"%s","desc":"%s","badge":"%s","order":%s,"html":"%s"}' \
            "$slug_json" "$type" "$title_json" "$desc_json" "$badge_json" "${order:-999}" "$body_json"
    done < <(sort -t$'\t' -k1,1 -k5,5n "$__HELPME_CACHE")
    
    echo -n "]"
}

__helpme_cmd_web() {
    local port="${1:-${HELPME_PORT:-8765}}"
    
    [ -f "$HOME/.sutd/info.conf" ] && source "$HOME/.sutd/info.conf"
    
    local bind="${HELPME_BIND:-127.0.0.1}"
    
    if [ ! -f "$__HELPME_TEMPLATE" ]; then
        echo -e "  \033[31m✗\033[0m template not found: $__HELPME_TEMPLATE"
        echo "  download from repo and place at:"
        echo "    $__HELPME_TEMPLATE"
        return 1
    fi
    
    if ! command -v python3 &>/dev/null; then
        echo -e "  \033[31m✗\033[0m python3 not installed"
        return 1
    fi
    
    __helpme_build_index
    
    local tmp
    tmp=$(mktemp -d)
    trap "rm -rf '$tmp'" RETURN
    
    local json_file="$tmp/topics.json"
    __helpme_build_topics_json > "$json_file"
    
    if [ ! -s "$json_file" ]; then
        echo -e "  \033[31m✗\033[0m failed to build topics JSON"
        return 1
    fi
    
    local hostname_val date_val
    hostname_val=$(hostname)
    date_val=$(date '+%Y-%m-%d %H:%M')
    
    python3 - "$__HELPME_TEMPLATE" "$json_file" "$hostname_val" "$date_val" "$tmp/index.html" << 'PYEOF'
import sys

template_path, json_path, hostname, date_str, out_path = sys.argv[1:6]

with open(template_path, 'r', encoding='utf-8') as f:
    html = f.read()

with open(json_path, 'r', encoding='utf-8') as f:
    json_data = f.read()

html = html.replace('__TOPICS_JSON__', json_data)
html = html.replace('__HOSTNAME__', hostname)
html = html.replace('__DATE__', date_str)

with open(out_path, 'w', encoding='utf-8') as f:
    f.write(html)
PYEOF
    
    if [ ! -s "$tmp/index.html" ]; then
        echo -e "  \033[31m✗\033[0m failed to render HTML"
        return 1
    fi
    
    echo -e "  \033[37mHelpme web server:\033[0m"
    echo -e "  \033[32m●\033[0m http://${bind}:${port}/"
    if [ "$bind" = "0.0.0.0" ]; then
        local ext
        ext=$(hostname -I 2>/dev/null | awk '{print $1}')
        [ -n "$ext" ] && echo -e "  \033[32m●\033[0m http://${ext}:${port}/"
    fi
    echo -e "  \033[90m  Ctrl+C to stop\033[0m"
    
    (cd "$tmp" && python3 -m http.server "$port" --bind "$bind" 2>/dev/null)
}

# ──────────────────────────────────────────────────────────────────────
# convenient alias
# ──────────────────────────────────────────────────────────────────────

alias '?'='helpme'

_helpme_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    case "$prev" in
        helpme|'?')
            local slugs=""
            [ -f "$__HELPME_CACHE" ] && slugs=$(awk -F'\t' '{print $2}' "$__HELPME_CACHE")
            COMPREPLY=( $(compgen -W "$slugs -l -s -w --refresh -h --list --search --web --help" -- "$cur") )
            ;;
    esac
}
complete -F _helpme_complete helpme
complete -F _helpme_complete '?'