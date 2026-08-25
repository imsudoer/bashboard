if [ "$PS1" ] && [ -x ~/.sutd/motd.sh ]; then
    ~/.sutd/motd.sh
fi

for f in ~/.sutd/terminal/*.sh; do
    [ -r "$f" ] && source "$f"
done

# For nice signature arrow prompt add this:

set_prompt() {
    local EXIT_CODE="$?"
    
    if [ $EXIT_CODE -eq 0 ]; then
        local ARROW="\[\033[32m\]❯\[\033[0m\]"
    else
        local ARROW="\[\033[31m\]❯\[\033[0m\]"
    fi

    local UI_USER="\[\033[38;5;250m\]"
    local UI_HOST="\[\033[38;5;208m\]"
    local UI_PATH="\[\033[37m\]"
    local UI_RESET="\[\033[0m\]"

    PS1="${UI_USER}\u${UI_RESET}@${UI_HOST}\h${UI_RESET}:${UI_PATH}\w${UI_RESET} ${ARROW} "
}

if [ -z "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="set_prompt"
else
    case ";$PROMPT_COMMAND;" in
        *";set_prompt;"*) ;;
        *) PROMPT_COMMAND="$PROMPT_COMMAND;set_prompt" ;;
    esac
fi