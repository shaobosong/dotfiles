# =====================================================================
# Set Terminal Title
# =====================================================================

_terminal_title_hook() {
    printf '\033]0;%s\007' \
        "${PWD/#$HOME/\~}"
}

# =====================================================================
# Set History Sync
# =====================================================================

_history_sync_hook() {
    history -a
    #history -n
}

# =====================================================================
# Interactive Ghost Path
# =====================================================================

GHOST_VIRTUAL_PATH="$PWD"

_update_ps1_hook() {
    local last_status=$?

    local COLOR_USER="\e[1;32m"
    local COLOR_REAL_PATH="\e[1;34m"
    local COLOR_GHOST_PATH="\e[2;34m"
    local COLOR_OK="\e[1;32m"
    local COLOR_ERR="\e[1;31m"
    local COLOR_RESET="\e[0m"

    local ghost=""
    case "$GHOST_VIRTUAL_PATH" in
        "$PWD")
            ;;
        "$PWD"/*)
            ghost="${GHOST_VIRTUAL_PATH#$PWD}"
            ;;
        *)
            GHOST_VIRTUAL_PATH="$PWD"
            ;;
    esac

    local real_pwd="${PWD/#$HOME/\~}"

    local status_color=$COLOR_ERR
    test ${last_status} -eq 0 && status_color=$COLOR_OK

    PS1="\[${COLOR_USER}\]\u@\h\[${COLOR_RESET}\]:"
    PS1+="\[${COLOR_REAL_PATH}\]${real_pwd}\[${COLOR_RESET}\]"
    [[ -n "$ghost" ]] && \
        PS1+="\[${COLOR_GHOST_PATH}\]${ghost}\[${COLOR_RESET}\]"
    PS1+=" \[${status_color}\](${last_status})\[${COLOR_RESET}\]"
    PS1+='\n# '
}

PROMPT_COMMAND+=(_terminal_title_hook)
PROMPT_COMMAND+=(_history_sync_hook)
PROMPT_COMMAND+=(_update_ps1_hook)
