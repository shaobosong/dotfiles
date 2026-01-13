#!/usr/bin/env bash

RUNTIME_DIR="/tmp/fzf-kit.${USER}"
FIND_FILES_CMD= # fd
FIND_DIRS_CMD= # fd
FIND_HIDDEN_OPT=
FIND_IGNORE_OPT=
FIND_FLAG_HIDDEN=
FIND_FLAG_IGNORE=
FIND_BIND_HIDDEN=
FIND_BIND_IGNORE=
FIND_GHOST=
FIND_HISTORY=
GREP_CMD= # rg
GREP_HIDDEN_OPT=
GREP_IGNORE_OPT=
GREP_BIND_HIDDEN=
GREP_BIND_IGNORE=
GREP_FLAG_HIDDEN=
GREP_FLAG_IGNORE=
GREP_GHOST=
GREP_HISTORY=
VIM_CMD= # nvim
CAT_CMD= # bat
CAT_HIGHLIGHT_LINE_OPT=

FZF_CMD="fzf --bind=change:first --color dark"

_check_commands() {
    if command -v fd &> /dev/null; then
        FIND_FILES_CMD="fd --type file"
        FIND_DIRS_CMD="fd --type directory"
        FIND_HIDDEN_OPT="--hidden"
        FIND_IGNORE_OPT="--no-ignore"
        FIND_FLAG_HIDDEN="(+hidden)"
        FIND_FLAG_IGNORE="(+ignore)"
        FIND_BIND_HIDDEN="alt-h:transform:
            [[ \"\${FZF_PROMPT}\" == *\"${FIND_FLAG_HIDDEN}\"* ]] &&
                new_prompt=\${FZF_PROMPT/\"${FIND_FLAG_HIDDEN}\"/} ||
                new_prompt=\${FZF_PROMPT/>/\"${FIND_FLAG_HIDDEN}\">}
            new_cmd=\"${FIND_FILES_CMD}\"
            [[ \"\${new_prompt}\" == *\"${FIND_FLAG_IGNORE}\"* ]] && new_cmd+=\" ${FIND_IGNORE_OPT}\"
            [[ \"\${new_prompt}\" == *\"${FIND_FLAG_HIDDEN}\"* ]] && new_cmd+=\" ${FIND_HIDDEN_OPT}\"
            echo \"change-prompt(\$new_prompt)+change-header(\$new_cmd)+reload:\$new_cmd\""
        FIND_BIND_IGNORE="alt-i:transform:
            [[ \"\${FZF_PROMPT}\" == *\"${FIND_FLAG_IGNORE}\"* ]] &&
                new_prompt=\${FZF_PROMPT/\"${FIND_FLAG_IGNORE}\"/} ||
                new_prompt=\${FZF_PROMPT/>/\"${FIND_FLAG_IGNORE}\">}
            new_cmd=\"${FIND_FILES_CMD}\"
            [[ \"\${new_prompt}\" == *\"${FIND_FLAG_HIDDEN}\"* ]] && new_cmd+=\" ${FIND_HIDDEN_OPT}\"
            [[ \"\${new_prompt}\" == *\"${FIND_FLAG_IGNORE}\"* ]] && new_cmd+=\" ${FIND_IGNORE_OPT}\"
            echo \"change-prompt(\$new_prompt)+change-header(\$new_cmd)+reload:\$new_cmd\""
        FIND_GHOST="<enter>: Vim | <ctrl-v>: View | <alt-i>: Ignore | <alt-h>: Hidden"
        FIND_HISTORY="${RUNTIME_DIR}/fd_vim_history"
    elif command -v find &> /dev/null; then
        FIND_FILES_CMD="find . -type f"
        FIND_DIRS_CMD="find . -mindepth 1 -type d"
        FIND_HIDDEN_OPT=""
        FIND_IGNORE_OPT=""
        FIND_BIND_HIDDEN="alt-h:unbind(alt-h)"
        FIND_BIND_IGNORE="alt-i:unbind(alt-i)"
        FIND_GHOST="<enter>: Vim | <ctrl-v>: View"
        FIND_HISTORY="${RUNTIME_DIR}/find_vim_history"
    else
        echo "Error: Failed to locate 'fd' or 'find'" >&2
    fi

    if command -v rg &> /dev/null; then
        GREP_CMD="rg --line-number --color=always --no-heading --follow --no-binary --no-config --smart-case"
        GREP_HIDDEN_OPT="--hidden"
        GREP_IGNORE_OPT="--no-ignore"
        GREP_FLAG_HIDDEN="(+hidden)"
        GREP_FLAG_IGNORE="(+ignore)"
        GREP_BIND_HIDDEN="alt-h:transform:
            [[ \"\${FZF_PROMPT}\" == *\"${GREP_FLAG_HIDDEN}\"* ]] &&
                new_prompt=\${FZF_PROMPT/\"${GREP_FLAG_HIDDEN}\"/} ||
                new_prompt=\${FZF_PROMPT/>/\"${GREP_FLAG_HIDDEN}\">}
            new_cmd=\"${GREP_CMD}\"
            [[ \"\${new_prompt}\" == *\"${GREP_FLAG_IGNORE}\"* ]] && new_cmd+=\" ${GREP_IGNORE_OPT}\"
            [[ \"\${new_prompt}\" == *\"${GREP_FLAG_HIDDEN}\"* ]] && new_cmd+=\" ${GREP_HIDDEN_OPT}\"
            echo \"change-prompt(\$new_prompt)+change-header(\$new_cmd)+reload:\$new_cmd ''\""
        GREP_BIND_IGNORE="alt-i:transform:
            [[ \"\${FZF_PROMPT}\" == *\"${GREP_FLAG_IGNORE}\"* ]] &&
                new_prompt=\${FZF_PROMPT/\"${GREP_FLAG_IGNORE}\"/} ||
                new_prompt=\${FZF_PROMPT/>/\"${GREP_FLAG_IGNORE}\">}
            new_cmd=\"${GREP_CMD}\"
            [[ \"\${new_prompt}\" == *\"${GREP_FLAG_HIDDEN}\"* ]] && new_cmd+=\" ${GREP_HIDDEN_OPT}\"
            [[ \"\${new_prompt}\" == *\"${GREP_FLAG_IGNORE}\"* ]] && new_cmd+=\" ${GREP_IGNORE_OPT}\"
            echo \"change-prompt(\$new_prompt)+change-header(\$new_cmd)+reload:\$new_cmd ''\""
        GREP_GHOST="<enter>: Vim | <ctrl-v>: View | <alt-i>: Ignore | <alt-h>: Hidden"
        GREP_HISTORY="${RUNTIME_DIR}/rg_vim_history"
    elif command -v grep &> /dev/null; then
        GREP_CMD="grep --line-number --color=always --dereference-recursive --binary-files=without-match"
        GREP_HIDDEN_OPT=""
        GREP_IGNORE_OPT=""
        GREP_BIND_HIDDEN="alt-h:unbind(alt-h)"
        GREP_BIND_IGNORE="alt-i:unbind(alt-i)"
        GREP_GHOST="<enter>: Vim | <ctrl-v>: View"
        GREP_HISTORY="${RUNTIME_DIR}/grep_vim_history"
    else
        echo "Error: Failed to locate 'rg' or 'grep'" >&2
    fi

    if command -v nvim &> /dev/null; then
        VIM_CMD="nvim"
    elif command -v vim &> /dev/null; then
        VIM_CMD="vim"
    else
        echo "Error: Failed to locate 'neovim' or 'vim'" >&2
    fi

    if command -v bat &> /dev/null; then
        CAT_CMD="bat -n --decorations=always --color=never"
        CAT_HIGHLIGHT_LINE_OPT="--highlight-line"
    elif command -v cat &> /dev/null; then
        CAT_CMD="cat -n"
        CAT_HIGHLIGHT_LINE_OPT="||:"
    else
        echo "Error: Failed to locate 'bat' or 'cat'" >&2
    fi
}

_fzf_file_vim_action() {
    export FD_CONFIG_PATH=

    ${FIND_FILES_CMD} | ${FZF_CMD} \
        --ghost="${FIND_GHOST}" \
        --header="${FIND_FILES_CMD}" \
        --prompt="File> " \
        --preview "${CAT_CMD} {}" \
        --history="${FIND_HISTORY}" \
        --bind "enter:become(${VIM_CMD} {})" \
        --bind "alt-J:jump,jump:become(${VIM_CMD} {})" \
        --bind "ctrl-v:execute(${VIM_CMD} -R {})" \
        --bind "f4:toggle-preview" \
        --bind "${FIND_BIND_HIDDEN}" \
        --bind "${FIND_BIND_IGNORE}"
}

_fzf_grep_vim_action() {
    FZF_DEFAULT_COMMAND="${GREP_CMD} ''" ${FZF_CMD} \
        --ansi \
        --delimiter=: \
        --nth=3.. \
        --prompt="Grep> " \
        --header="${GREP_CMD}" \
        --ghost="${GREP_GHOST}" \
        --preview "${CAT_CMD} {1} ${CAT_HIGHLIGHT_LINE_OPT} {2}" \
        --preview-window 'up,50%,border-down,+{2}/2' \
        --history="${GREP_HISTORY}" \
        --bind "enter:become(${VIM_CMD} {1} +{2})" \
        --bind "alt-J:jump,jump:become(${VIM_CMD} {1} +{2})" \
        --bind "ctrl-v:execute(${VIM_CMD} -R {1} +{2})" \
        --bind "f4:toggle-preview" \
        --bind "${GREP_BIND_HIDDEN}" \
        --bind "${GREP_BIND_IGNORE}"
}

fzf_kit() {
    _check_commands

    test -d ${RUNTIME_DIR} || mkdir -p ${RUNTIME_DIR}

    declare -A fzf_actions
    fzf_actions=(
        ["file-vim"]="_fzf_file_vim_action"
        ["grep-vim"]="_fzf_grep_vim_action"
    )

    __options=$(printf "%s\n" "${!fzf_actions[@]}" | sort)

    __choice=$(echo -e "$__options" | ${FZF_CMD} \
        --layout=reverse \
        --height=~50% \
        --tmux center,50% \
        --cycle \
        --prompt="Actions > ")

    if [[ -n "$__choice" ]]; then
        "${fzf_actions[$__choice]}"
    fi
}

if (( BASH_VERSINFO[0] < 4 )); then
    # TODO: Compatible with lower 'bash' version
    false
else
    bind -m emacs-standard -x '"\ej": fzf_kit'
    bind -m vi-command -x '"\ej": fzf_kit'
    bind -m vi-insert -x '"\ej": fzf_kit'
fi
