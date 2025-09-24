#!/usr/bin/env bash

FIND_FILES_CMD= # fd
FIND_DIRS_CMD= # fd
GREP_CMD= # rg
GREP_HIDDEN_OPT=
GREP_IGNORE_OPT=
VIM_CMD= # nvim
CAT_CMD= # bat
CAT_HIGHLIGHT_LINE_OPT=

FZF_CMD="fzf --bind=change:first"

_check_commands() {
    if command -v fd &> /dev/null; then
        FIND_FILES_CMD="fd -t f -H"
        FIND_DIRS_CMD="fd -t d -H"
    elif command -v find &> /dev/null; then
        FIND_FILES_CMD="find . -type f"
        FIND_DIRS_CMD="find . -mindepth 1 -type d"
    else
        echo "Error: Failed to find 'fd' or 'find'" >&2
        exit 1
    fi

    if command -v rg &> /dev/null; then
        GREP_CMD="rg --line-number --color=always --no-heading --follow --no-binary --no-config"
        GREP_HIDDEN_OPT="--hidden"
        GREP_IGNORE_OPT="--no-ignore"
    elif command -v grep &> /dev/null; then
        GREP_CMD="grep --line-number --color=always --dereference-recursive --binary-files=without-match"
        GREP_HIDDEN_OPT=""
        GREP_IGNORE_OPT=""
    else
        echo "Error: Failed to find 'rg' or 'grep'" >&2
        exit 1
    fi

    if command -v nvim &> /dev/null; then
        VIM_CMD="nvim"
    elif command -v vim &> /dev/null; then
        VIM_CMD="vim"
    else
        echo "Error: Failed to find 'neovim' or 'vim'" >&2
        exit 1
    fi

    if command -v bat &> /dev/null; then
        CAT_CMD="bat -n --decorations=always --color=never"
        CAT_HIGHLIGHT_LINE_OPT="--highlight-line"
    elif command -v cat &> /dev/null; then
        CAT_CMD="cat -n"
        CAT_HIGHLIGHT_LINE_OPT="||:"
    else
        echo "Error: Failed to find 'bat' or 'cat'" >&2
        exit 1
    fi
}

_fzf_file_vim_action() {
    ${FIND_FILES_CMD} | ${FZF_CMD} \
        --prompt="File> " \
        --preview "${CAT_CMD} {}" \
        --bind "enter:become(${VIM_CMD} {})" \
        --bind "alt-J:jump,jump:become(${VIM_CMD} {})" \
        --bind "ctrl-v:execute(${VIM_CMD} -R {})"
}

_fzf_grep_vim_action() {
    # Note: exclusive
    __flag_hidden="(+hidden)"
    __flag_ignore="(+ignore)"

    FZF_DEFAULT_COMMAND="${GREP_CMD} ''" ${FZF_CMD} \
        --ansi \
        --delimiter=: \
        --nth=3.. \
        --prompt="Grep> " \
        --header="${GREP_CMD}" \
        --ghost="<enter>: Vim | <ctrl-v>: View | <alt-i>: Ignore | <alt-h>: Hidden" \
        --preview "${CAT_CMD} {1} ${CAT_HIGHLIGHT_LINE_OPT} {2}" \
        --preview-window 'up,50%,border-down,+{2}/2' \
        --bind "enter:become(${VIM_CMD} {1} +{2})" \
        --bind "alt-J:jump,jump:become(${VIM_CMD} {1} +{2})" \
        --bind "ctrl-v:execute(${VIM_CMD} -R {1} +{2})" \
        --bind "alt-h:transform:
            [[ \"\${FZF_PROMPT}\" == *\"${__flag_hidden}\"* ]] &&
                new_prompt=\${FZF_PROMPT/\"${__flag_hidden}\"/} ||
                new_prompt=\${FZF_PROMPT/>/\"${__flag_hidden}\">}
            final_opts=\"\"
            [[ \"\${new_prompt}\" == *\"${__flag_ignore}\"* ]] && final_opts+=\"${GREP_IGNORE_OPT} \"
            [[ \"\${new_prompt}\" == *\"${__flag_hidden}\"* ]] && final_opts+=\"${GREP_HIDDEN_OPT} \"
            echo \"change-prompt(\${new_prompt})+change-header(${GREP_CMD} \${final_opts})+reload:${GREP_CMD} \${final_opts} ''\"" \
        --bind "alt-i:transform:
            [[ \"\${FZF_PROMPT}\" == *\"${__flag_ignore}\"* ]] &&
                new_prompt=\${FZF_PROMPT/\"${__flag_ignore}\"/} ||
                new_prompt=\${FZF_PROMPT/>/\"${__flag_ignore}\">}
            final_opts=\"\"
            [[ \"\${new_prompt}\" == *\"${__flag_hidden}\"* ]] && final_opts+=\"${GREP_HIDDEN_OPT} \"
            [[ \"\${new_prompt}\" == *\"${__flag_ignore}\"* ]] && final_opts+=\"${GREP_IGNORE_OPT} \"
            echo \"change-prompt(\${new_prompt})+change-header(${GREP_CMD} \${final_opts})+reload:${GREP_CMD} \${final_opts} ''\""
}

fzf_kit() {
    _check_commands

    declare -A fzf_actions
    fzf_actions=(
        ["file_vim"]="_fzf_file_vim_action"
        ["grep_vim"]="_fzf_grep_vim_action"
    )

    if test -f /usr/share/fzf/key-bindings.bash; then
        source /usr/share/fzf/key-bindings.bash
        fzf_actions+=(
            ["file"]="fzf-file-widget"
            ["history"]="__fzf_history__"
        )
    fi

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
