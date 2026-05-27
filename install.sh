#!/bin/bash
set -u

SUTD_REPO_URL="https://github.com/imsudoer/bashboard"
SUTD_VERSION="1.0.0"

C_ACCENT='\033[38;5;208m'
C_DIM='\033[90m'
C_OK='\033[32m'
C_WARN='\033[33m'
C_ERR='\033[31m'
C_BOLD='\033[1m'
C_RST='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-$HOME/.sutd}"
BASHRC="${BASHRC:-$HOME/.bashrc}"
MODE="full"
INTERFACE_MODE="1"
THEME_ACCENT="208"
THEME_BG="237"
THEME_BG_ENABLED="1"
SAFE_RM_LEVEL="2"
PROMPT_ONLY="0"
NONINTERACTIVE="0"
SKIP_DEPS="0"
SKIP_BASHRC="0"
DO_UNINSTALL="0"
FORCE="0"
DRY_RUN="0"
BACKUP_DIR="$HOME/.sutd-backup-$(date +%Y%m%d-%H%M%S)"

usage() {
    cat << 'EOF'
Bashboard installer

Usage:
  ./install.sh [options]

Modes:
  --full              Install everything (default)
  --minimal           Install only MOTD + prompt
  --prompt-only       Install ONLY the signature prompt to .bashrc
  --uninstall         Remove Bashboard

Options:
  --dir <path>        Install location (default: ~/.sutd)
  --bashrc <path>     Bashrc file to modify (default: ~/.bashrc)
  --interface <0|1|2> 0=plain, 1=menu, 2=TUI (default: 1)
  --accent <code>     256-color accent (default: 208 = orange)
  --bg <code>         256-color background (default: 237)
  --no-bg             Disable panel backgrounds
  --safe-rm <1|2|3>   Confirmation strictness (default: 2)
  --skip-deps         Don't install system packages
  --skip-bashrc       Don't modify .bashrc
  --non-interactive   No prompts, use defaults / flags
  --force             Overwrite existing without prompting
  --dry-run           Show what would be done, do nothing
  -h, --help          Show this help

Examples:
  ./install.sh
  ./install.sh --minimal
  ./install.sh --prompt-only
  ./install.sh --accent 75 --bg 235
  ./install.sh --non-interactive --interface 0
  ./install.sh --uninstall
EOF
}

say()      { printf "  %b\n" "$1"; }
say_ok()   { printf "  ${C_OK}✓${C_RST} %s\n" "$1"; }
say_warn() { printf "  ${C_WARN}⚠${C_RST} %s\n" "$1"; }
say_err()  { printf "  ${C_ERR}✗${C_RST} %s\n" "$1" >&2; }
say_step() { printf "\n${C_ACCENT}${C_BOLD}▸ %s${C_RST}\n" "$1"; }
say_dim()  { printf "  ${C_DIM}%s${C_RST}\n" "$1"; }

run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf "  ${C_DIM}[dry-run]${C_RST} %s\n" "$*"
        return 0
    fi
    "$@"
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$NONINTERACTIVE" = "1" ] || [ "$FORCE" = "1" ]; then
        [ "$default" = "y" ] && return 0 || return 1
    fi
    
    local hint
    [ "$default" = "y" ] && hint="[Y/n]" || hint="[y/N]"
    
    read -p "  $prompt $hint: " ans
    ans="${ans:-$default}"
    [[ "$ans" =~ ^[yY]$ ]]
}

ask() {
    local prompt="$1"
    local default="$2"
    
    if [ "$NONINTERACTIVE" = "1" ]; then
        echo "$default"
        return
    fi
    
    read -p "  $prompt [$default]: " ans
    echo "${ans:-$default}"
}

show_banner() {
    clear 2>/dev/null || true
    printf "${C_ACCENT}"
    cat << 'EOF'

   ____               _     _                         _ 
  | __ )  __ _ ___ __| |__ | |__   ___   __ _ _ __ __| |
  |  _ \ / _` / __/ _` '_ \| '_ \ / _ \ / _` | '__/ _` |
  | |_) | (_| \__ \ (_| |_) | |_) | (_) | (_| | | | (_| |
  |____/ \__,_|___/\__,_,__/|_.__/ \___/ \__,_|_|  \__,_|

EOF
    printf "${C_RST}"
    printf "  ${C_BOLD}Bashboard installer${C_RST} ${C_DIM}v${SUTD_VERSION}${C_RST}\n"
    printf "  ${C_DIM}${SUTD_REPO_URL}${C_RST}\n\n"
}

check_bash_version() {
    local major
    major=$(bash --version | head -1 | grep -oE '[0-9]+' | head -1)
    if [ -z "$major" ] || [ "$major" -lt 4 ]; then
        say_warn "Bash $major detected — Bashboard recommends 5+"
        say_dim "Some features (timing in prompt, etc.) may not work"
    fi
}

check_existing() {
    if [ -d "$INSTALL_DIR" ] && [ "$DO_UNINSTALL" = "0" ]; then
        say_warn "Existing installation at: $INSTALL_DIR"
        
        if [ "$FORCE" = "1" ]; then
            say "Force mode — backing up and overwriting"
            run mv "$INSTALL_DIR" "${INSTALL_DIR}.bak.$(date +%s)"
        elif confirm "Backup it and continue?" "y"; then
            run mv "$INSTALL_DIR" "${INSTALL_DIR}.bak.$(date +%s)"
            say_ok "Old installation moved aside"
        else
            say_err "Aborted by user"
            exit 1
        fi
    fi
}

install_deps() {
    [ "$SKIP_DEPS" = "1" ] && return 0
    
    say_step "Installing dependencies"
    
    local pkgs=()
    
    command -v curl &>/dev/null || pkgs+=(curl)
    command -v openssl &>/dev/null || pkgs+=(openssl)
    command -v python3 &>/dev/null || pkgs+=(python3)
    command -v inotifywait &>/dev/null || pkgs+=(inotify-tools)
    command -v qrencode &>/dev/null || pkgs+=(qrencode)
    command -v bc &>/dev/null || pkgs+=(bc)
    
    if [ ${#pkgs[@]} -eq 0 ]; then
        say_ok "All recommended packages already installed"
        return 0
    fi
    
    say_dim "Missing recommended packages: ${pkgs[*]}"
    
    if ! command -v apt-get &>/dev/null; then
        say_warn "Non-Debian/Ubuntu system — install manually: ${pkgs[*]}"
        return 0
    fi
    
    if ! confirm "Install via apt-get?" "y"; then
        say_warn "Skipping dependency install"
        return 0
    fi
    
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo &>/dev/null; then
            run sudo apt-get update -qq
            run sudo apt-get install -y "${pkgs[@]}" || say_warn "Some packages failed to install"
        else
            say_err "Need sudo or root to install packages"
            return 1
        fi
    else
        run apt-get update -qq
        run apt-get install -y "${pkgs[@]}" || say_warn "Some packages failed to install"
    fi
    
    say_ok "Dependencies installed"
}

choose_mode() {
    [ "$NONINTERACTIVE" = "1" ] && return 0
    [ "$PROMPT_ONLY" = "1" ] && return 0
    [ "$DO_UNINSTALL" = "1" ] && return 0
    
    say_step "Choose installation mode"
    echo "    1) Full     — all modules, terminal tools, menu/TUI (recommended)"
    echo "    2) Minimal  — MOTD + prompt only, no terminal extensions"
    echo "    3) Prompt   — only the signature prompt (no Bashboard dirs)"
    echo ""
    
    read -p "  Select [1]: " choice
    case "${choice:-1}" in
        1) MODE="full" ;;
        2) MODE="minimal" ;;
        3) PROMPT_ONLY="1"; MODE="prompt" ;;
        *) say_err "Invalid choice"; exit 1 ;;
    esac
    
    say_ok "Mode: $MODE"
}

choose_interface() {
    [ "$NONINTERACTIVE" = "1" ] && return 0
    [ "$PROMPT_ONLY" = "1" ] && return 0
    [ "$MODE" = "minimal" ] && return 0
    
    say_step "Choose interface mode"
    echo "    0) Plain MOTD  — all modules dumped at login"
    echo "    1) Slides menu — interactive ←/→ navigation (default)"
    echo "    2) Full TUI    — sidebar + content panel"
    echo ""
    
    INTERFACE_MODE=$(ask "Interface mode (0/1/2)" "1")
    
    case "$INTERFACE_MODE" in
        0|1|2) say_ok "Interface mode: $INTERFACE_MODE" ;;
        *) say_err "Invalid mode, defaulting to 1"; INTERFACE_MODE="1" ;;
    esac
}

choose_theme() {
    [ "$NONINTERACTIVE" = "1" ] && return 0
    [ "$PROMPT_ONLY" = "1" ] && return 0
    
    say_step "Choose theme"
    echo "    Preset accent colors:"
    echo "      ${C_ACCENT}208${C_RST} — orange (default)    ${C_ACCENT}201${C_RST} — pink"
    printf "      \033[38;5;75m75${C_RST}  — ocean blue          \033[38;5;46m46${C_RST}  — matrix green\n"
    printf "      \033[38;5;141m141${C_RST} — lavender             \033[38;5;220m220${C_RST} — gold\n"
    printf "      \033[38;5;196m196${C_RST} — red                  \033[38;5;87m87${C_RST}  — sky blue\n"
    echo ""
    
    THEME_ACCENT=$(ask "Accent color (256-color code)" "$THEME_ACCENT")
    THEME_BG=$(ask "Panel background (235-239 looks nice)" "$THEME_BG")
    
    if confirm "Enable panel backgrounds?" "y"; then
        THEME_BG_ENABLED="1"
    else
        THEME_BG_ENABLED="0"
    fi
}

choose_safe_rm() {
    [ "$NONINTERACTIVE" = "1" ] && return 0
    [ "$PROMPT_ONLY" = "1" ] && return 0
    [ "$MODE" = "minimal" ] && return 0
    
    say_step "Safe-rm confirmation strictness"
    echo "    1) Simple y/n      — minimal interruption"
    echo "    2) Type 'yes'      — recommended"
    echo "    3) Random code     — paranoid"
    echo ""
    
    SAFE_RM_LEVEL=$(ask "Level (1/2/3)" "2")
    case "$SAFE_RM_LEVEL" in
        1|2|3) ;;
        *) SAFE_RM_LEVEL="2" ;;
    esac
}

write_config() {
    [ "$PROMPT_ONLY" = "1" ] && return 0
    
    say_step "Writing configuration"
    
    local conf="$INSTALL_DIR/info.conf"
    
    run mkdir -p "$INSTALL_DIR"
    
    if [ "$DRY_RUN" = "1" ]; then
        say_dim "[dry-run] would write $conf"
        return
    fi
    
    cat > "$conf" << EOF
# Bashboard configuration
# Generated by install.sh on $(date)

# Interface mode: 0=plain MOTD, 1=slides menu, 2=full TUI
INTERFACE_MODE=$INTERFACE_MODE

# Theme
THEME_ACCENT="$THEME_ACCENT"
THEME_BG="$THEME_BG"
THEME_BG_ENABLED=$THEME_BG_ENABLED

# Safety level for dangerous commands (1/2/3)
SAFE_RM_LEVEL=$SAFE_RM_LEVEL

# Context menu binding
CTX_MENU_BIND="\C-g"

# Helpme web server
HELPME_PORT=8765
HELPME_BIND="127.0.0.1"

# Module-specific
SSL_CERTS_PATH=""
SSL_WARN_DAYS=14
TOP_PROCESSES_COUNT=3
LAST_COMMANDS_COUNT=5
SHOW_WEATHER_CITY="Moscow"
SHOW_EXTERNAL_IP=1
SHOW_CPU_TEMP=1

# Module toggles
ENABLE_HOST=1
ENABLE_NETWORK=1
ENABLE_SYSTEM=1
ENABLE_RESOURCES=1
ENABLE_SSL_CERTS=1
ENABLE_TOP_PROCESSES=1
ENABLE_STREAK=1
ENABLE_UPTIME_RECORD=1
ENABLE_SERVER_AGE=1
ENABLE_SERVICES=1
ENABLE_ACHIEVEMENTS=1
ENABLE_PROGRESS_BARS=1
ENABLE_ASCII_GRAPH=1
ENABLE_DOCKER=1
ENABLE_SECURITY=1
ENABLE_UPDATES=1
ENABLE_LAST_COMMANDS=1
ENABLE_FOOTER=0
EOF
    
    say_ok "Configuration written: $conf"
}

install_files() {
    [ "$PROMPT_ONLY" = "1" ] && return 0
    
    say_step "Installing files"
    
    run mkdir -p "$INSTALL_DIR/modules"
    run mkdir -p "$INSTALL_DIR/terminal"
    run mkdir -p "$INSTALL_DIR/data"
    run mkdir -p "$INSTALL_DIR/data/chains"
    run mkdir -p "$INSTALL_DIR/data/helpme"
    run mkdir -p "$INSTALL_DIR/data/env-checks"
    run mkdir -p "$INSTALL_DIR/data/proj_histories"
    run mkdir -p "$INSTALL_DIR/docs"
    
    say_ok "Directory structure created"
    
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ "$script_dir" = "$INSTALL_DIR" ]; then
        say_ok "Already in $INSTALL_DIR — keeping current files"
    elif [ -d "$script_dir/modules" ] && [ -d "$script_dir/terminal" ]; then
        say_dim "Copying from $script_dir → $INSTALL_DIR"
        run cp -r "$script_dir/modules/." "$INSTALL_DIR/modules/" 2>/dev/null || true
        run cp -r "$script_dir/terminal/." "$INSTALL_DIR/terminal/" 2>/dev/null || true
        [ -f "$script_dir/motd.sh" ]   && run cp "$script_dir/motd.sh" "$INSTALL_DIR/"
        [ -f "$script_dir/menu.sh" ]   && run cp "$script_dir/menu.sh" "$INSTALL_DIR/"
        [ -f "$script_dir/lib.sh" ]    && run cp "$script_dir/lib.sh" "$INSTALL_DIR/"
        [ -d "$script_dir/docs" ]      && run cp -r "$script_dir/docs/." "$INSTALL_DIR/docs/" 2>/dev/null || true
        say_ok "Files copied"
    else
        say_warn "Source files not detected — install from git:"
        say_dim "  git clone $SUTD_REPO_URL $INSTALL_DIR"
        return 1
    fi
    
    if [ ! -f "$INSTALL_DIR/services.list" ]; then
        if [ "$DRY_RUN" != "1" ]; then
            cat > "$INSTALL_DIR/services.list" << 'EOF'
ssh
nginx
docker
cron
ufw
fail2ban
EOF
        fi
        say_ok "Default services.list created"
    fi
    
    if [ "$MODE" = "minimal" ]; then
        say_dim "Minimal mode — removing terminal extensions except prompt"
        run find "$INSTALL_DIR/terminal" -type f -name "*.sh" ! -name "prompt.sh" ! -name "mods.sh" -delete 2>/dev/null || true
    fi
    
    if [ "$DRY_RUN" != "1" ]; then
        chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
        chmod +x "$INSTALL_DIR"/modules/*.sh 2>/dev/null || true
        chmod +x "$INSTALL_DIR"/terminal/*.sh 2>/dev/null || true
        chmod 700 "$INSTALL_DIR/data"
        say_ok "Permissions set"
    fi
}

write_signature_prompt() {
    say_step "Installing signature prompt"
    
    local prompt_file="$HOME/.sutd-prompt.sh"
    
    if [ "$DRY_RUN" = "1" ]; then
        say_dim "[dry-run] would write $prompt_file"
        return
    fi
    
    cat > "$prompt_file" << 'PROMPT_EOF'
# Bashboard signature prompt
# Generated by install.sh

set_prompt() {
    local EXIT_CODE="$?"
    
    if [ $EXIT_CODE -eq 0 ]; then
        local ARROW="$$\033[32m$$❯$$\033[0m$$"
    else
        local ARROW="$$\033[31m$$❯$$\033[0m$$"
    fi

    local UI_USER="$$\033[38;5;250m$$"
    local UI_HOST="$$\033[38;5;208m$$"
    local UI_PATH="$$\033[37m$$"
    local UI_RESET="$$\033[0m$$"

    PS1="${UI_USER}\u${UI_RESET}@${UI_HOST}\h${UI_RESET}:${UI_PATH}\w${UI_RESET} ${ARROW} "
}

PROMPT_COMMAND=set_prompt
PROMPT_EOF
    
    say_ok "Prompt installed: $prompt_file"
}

modify_bashrc() {
    [ "$SKIP_BASHRC" = "1" ] && {
        say_warn "Skipping .bashrc modification"
        return 0
    }
    
    say_step "Modifying $BASHRC"
    
    if [ ! -f "$BASHRC" ]; then
        say_dim "$BASHRC doesn't exist — creating"
        run touch "$BASHRC"
    fi
    
    if grep -q "BASHBOARD_BEGIN" "$BASHRC" 2>/dev/null; then
        say_warn "Bashboard entries already present in $BASHRC"
        
        if confirm "Remove old entries and re-install?" "y"; then
            local backup="${BASHRC}.bak.$(date +%s)"
            run cp "$BASHRC" "$backup"
            say_dim "Backup: $backup"
            
            if [ "$DRY_RUN" != "1" ]; then
                sed -i '/# >>> BASHBOARD_BEGIN >>>/,/# <<< BASHBOARD_END <<</d' "$BASHRC"
            fi
        else
            say "Leaving .bashrc untouched"
            return 0
        fi
    else
        local backup="${BASHRC}.bak.$(date +%s)"
        run cp "$BASHRC" "$backup"
        say_dim "Backup: $backup"
    fi
    
    if [ "$DRY_RUN" = "1" ]; then
        say_dim "[dry-run] would append Bashboard block to $BASHRC"
        return
    fi
    
    cat >> "$BASHRC" << EOF

# >>> BASHBOARD_BEGIN >>>
# Bashboard — $SUTD_REPO_URL
# Installed: $(date)
EOF
    
    if [ "$PROMPT_ONLY" = "1" ]; then
        cat >> "$BASHRC" << 'EOF'

if [ "$PS1" ] && [ -r ~/.sutd-prompt.sh ]; then
    source ~/.sutd-prompt.sh
fi
EOF
    else
        cat >> "$BASHRC" << EOF

if [ "\$PS1" ] && [ -x $INSTALL_DIR/motd.sh ]; then
    $INSTALL_DIR/motd.sh
fi

for f in $INSTALL_DIR/terminal/*.sh; do
    [ -r "\$f" ] && source "\$f"
done
EOF
    fi
    
    cat >> "$BASHRC" << 'EOF'
# <<< BASHBOARD_END <<<
EOF
    
    say_ok "Updated $BASHRC"
}

uninstall() {
    say_step "Uninstalling Bashboard"
    
    if [ ! -d "$INSTALL_DIR" ] && ! grep -q "BASHBOARD_BEGIN" "$BASHRC" 2>/dev/null; then
        say_warn "Bashboard doesn't appear to be installed"
        exit 0
    fi
    
    if confirm "This will remove $INSTALL_DIR and Bashboard entries from $BASHRC. Continue?" "n"; then
        if [ -d "$INSTALL_DIR" ]; then
            if confirm "Backup state to $BACKUP_DIR before deleting?" "y"; then
                run mkdir -p "$BACKUP_DIR"
                run cp -r "$INSTALL_DIR/data" "$BACKUP_DIR/" 2>/dev/null
                run cp "$INSTALL_DIR/info.conf" "$BACKUP_DIR/" 2>/dev/null
                run cp "$INSTALL_DIR/services.list" "$BACKUP_DIR/" 2>/dev/null
                say_ok "State backed up to: $BACKUP_DIR"
            fi
            
            run rm -rf "$INSTALL_DIR"
            say_ok "Removed $INSTALL_DIR"
        fi
        
        if [ -f "$HOME/.sutd-prompt.sh" ]; then
            run rm -f "$HOME/.sutd-prompt.sh"
            say_ok "Removed signature prompt"
        fi
        
        if grep -q "BASHBOARD_BEGIN" "$BASHRC" 2>/dev/null; then
            local backup="${BASHRC}.bak.$(date +%s)"
            run cp "$BASHRC" "$backup"
            
            if [ "$DRY_RUN" != "1" ]; then
                sed -i '/# >>> BASHBOARD_BEGIN >>>/,/# <<< BASHBOARD_END <<</d' "$BASHRC"
            fi
            
            say_ok "Cleaned $BASHRC (backup: $backup)"
        fi
        
        echo ""
        say_ok "${C_BOLD}Bashboard uninstalled${C_RST}"
        say_dim "To finish, run: exec bash"
        echo ""
    else
        say "Cancelled"
        exit 0
    fi
}

show_summary() {
    echo ""
    printf "${C_ACCENT}${C_BOLD}  Installation summary${C_RST}\n"
    printf "  ${C_DIM}─────────────────────────────────────${C_RST}\n"
    
    if [ "$PROMPT_ONLY" = "1" ]; then
        printf "  Mode            : ${C_OK}prompt-only${C_RST}\n"
        printf "  Prompt file     : %s\n" "$HOME/.sutd-prompt.sh"
    else
        printf "  Mode            : ${C_OK}%s${C_RST}\n" "$MODE"
        printf "  Install dir     : %s\n" "$INSTALL_DIR"
        printf "  Interface mode  : %s\n" "$INTERFACE_MODE"
        printf "  Accent color    : %s\n" "$THEME_ACCENT"
        printf "  Background      : %s (enabled=%s)\n" "$THEME_BG" "$THEME_BG_ENABLED"
        printf "  Safe-rm level   : %s\n" "$SAFE_RM_LEVEL"
    fi
    printf "  Bashrc modified : %s\n" "$BASHRC"
    
    echo ""
    printf "  ${C_BOLD}Next steps:${C_RST}\n"
    printf "    1. Reload your shell: ${C_ACCENT}exec bash${C_RST}\n"
    
    if [ "$PROMPT_ONLY" != "1" ]; then
        printf "    2. Type ${C_ACCENT}helpme${C_RST} for the interactive help\n"
        printf "    3. Edit ${C_ACCENT}%s/info.conf${C_RST} to customize\n" "$INSTALL_DIR"
    fi
    
    echo ""
    printf "  ${C_DIM}Repo: %s${C_RST}\n" "$SUTD_REPO_URL"
    echo ""
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --full)            MODE="full"; shift ;;
            --minimal)         MODE="minimal"; shift ;;
            --prompt-only)     PROMPT_ONLY="1"; MODE="prompt"; shift ;;
            --uninstall)       DO_UNINSTALL="1"; shift ;;
            --dir)             INSTALL_DIR="$2"; shift 2 ;;
            --bashrc)          BASHRC="$2"; shift 2 ;;
            --interface)       INTERFACE_MODE="$2"; shift 2 ;;
            --accent)          THEME_ACCENT="$2"; shift 2 ;;
            --bg)              THEME_BG="$2"; shift 2 ;;
            --no-bg)           THEME_BG_ENABLED="0"; shift ;;
            --safe-rm)         SAFE_RM_LEVEL="$2"; shift 2 ;;
            --skip-deps)       SKIP_DEPS="1"; shift ;;
            --skip-bashrc)     SKIP_BASHRC="1"; shift ;;
            --non-interactive) NONINTERACTIVE="1"; shift ;;
            --force)           FORCE="1"; shift ;;
            --dry-run)         DRY_RUN="1"; shift ;;
            -h|--help)         usage; exit 0 ;;
            *)
                say_err "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    show_banner
    
    if [ "$DO_UNINSTALL" = "1" ]; then
        uninstall
        exit 0
    fi
    
    check_bash_version
    
    if [ "$DRY_RUN" = "1" ]; then
        say_warn "DRY RUN — no changes will be made"
        echo ""
    fi
    
    choose_mode
    
    if [ "$PROMPT_ONLY" != "1" ]; then
        check_existing
        choose_interface
        choose_theme
        choose_safe_rm
    fi
    
    install_deps
    
    if [ "$PROMPT_ONLY" = "1" ]; then
        write_signature_prompt
    else
        install_files
        write_config
        write_signature_prompt
    fi
    
    modify_bashrc
    
    show_summary
}

main "$@"