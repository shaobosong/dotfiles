#!/usr/bin/env bash

FIND_FILES_CMD= # fd
FIND_DIRS_CMD= # fd
GREP_CMD= # rg
VIM_CMD= # nvim
CAT_CMD= # bat
CAT_CMD_EXTRA=

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
        GREP_CMD="rg --line-number --no-heading --color=always --follow"
    elif command -v grep &> /dev/null; then
        GREP_CMD="grep -rnRI --color=always"
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
        CAT_CMD_EXTRA="--highlight-line"
    elif command -v cat &> /dev/null; then
        CAT_CMD="cat -n"
        CAT_CMD_EXTRA="||: "
    else
        echo "Error: Failed to find 'bat' or 'cat'" >&2
        exit 1
    fi
}

_fzf_files_action() {
    ${FIND_FILES_CMD} | ${FZF_CMD} \
        --prompt="Files > " \
        --preview "${CAT_CMD} {}" \
        --bind "enter:become(${VIM_CMD} {})" \
        --bind "alt-J:jump,jump:become(${VIM_CMD} {})" \
        --bind "ctrl-v:execute(${VIM_CMD} -R {})"
}

_fzf_grep_action() {
    FZF_DEFAULT_COMMAND="$GREP_CMD ''" ${FZF_CMD} \
        --ansi \
        --delimiter=: \
        --nth=3.. \
        --prompt="Grep > " \
        --preview "${CAT_CMD} {1} ${CAT_CMD_EXTRA} {2}" \
        --preview-window 'up,50%,border-down,+{2}/2' \
        --bind "enter:become(${VIM_CMD} {1} +{2})" \
        --bind "alt-J:jump,jump:become(${VIM_CMD} {1} +{2})" \
        --bind "ctrl-v:execute(${VIM_CMD} -R {1} +{2})"
}

fzf_kit() {
    _check_commands

    declare -A fzf_actions
    fzf_actions=(
        ["📁 files"]="_fzf_files_action"
        ["🔍 grep"]="_fzf_grep_action"
    )

    local options
    options=$(printf "%s\n" "${!fzf_actions[@]}" | sort)

    local choice
    choice=$(echo -e "$options" | ${FZF_CMD} \
        --cycle \
        --prompt="Actions > ")

    if [[ -n "$choice" ]]; then
        local func_to_run="${fzf_actions[$choice]}"
        "$func_to_run"
    fi
}

fzf_kit "$@"
