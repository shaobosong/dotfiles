#!/usr/bin/env bash
set -u

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "${BASH_SOURCE[0]}")"
readonly TMUX_PANE_SEARCH_LIB="${SCRIPT_DIR}/../rc/tmux-pane-search-lib"

readonly PICKER_PROMPT="Search Current Pane> "
readonly PICKER_GHOST="<enter>: Jump to line  <f2>: Toggle fullscreen  <f4>: Toggle preview  <C-r>: Refresh"
readonly POPUP_SIZE_NORMAL="85%,85%"
readonly POPUP_SIZE_FULLSCREEN="100%,100%"
readonly PREVIEW_WINDOW="down,30%,wrap,border-top"

pane_id=
fzf_query=
popup_size="${POPUP_SIZE_NORMAL}"
preview_cmd=
resize_token=
toggle_fullscreen_token=
resize_bind=
toggle_fullscreen_bind=
toggle_preview_bind=
selected_line=

declare -a fzf_bin_base=()

show_tmux_message() {
    local message="${1}"

    tmux display-message "${message}"
}

load_tmux_pane_search_lib() {
    if [[ ! -r "${TMUX_PANE_SEARCH_LIB}" ]]; then
        show_tmux_message "tmux-copy-fzf-search: missing tmux-pane-search-lib"
        return 1
    fi

    # shellcheck disable=SC1090
    . "${TMUX_PANE_SEARCH_LIB}"
}

resolve_pane_id() {
    pane_id="${1:-}"

    if [[ -z "${pane_id}" ]]; then
        pane_id="$(tmux display-message -p '#{pane_id}' 2>/dev/null)" || return 1
    fi

    [[ -n "${pane_id}" ]]
}

enter_copy_mode() {
    tmux select-pane -t "${pane_id}" || return 1
    tmux copy-mode -t "${pane_id}" || return 1
}

init_fzf_backend() {
    if command -v fzf-tmux >/dev/null 2>&1; then
        fzf_bin_base=(fzf-tmux -p)
        return 0
    fi

    if command -v fzf >/dev/null 2>&1; then
        fzf_bin_base=(fzf --tmux)
        return 0
    fi

    show_tmux_message "Failed to find fzf or fzf-tmux"
    return 1
}

init_picker_state() {
    resize_token="0:__FZF_TMUX_PANE_RESIZE__:${pane_id#%}:$$"
    toggle_fullscreen_token="0:__FZF_TMUX_PANE_FULLSCREEN__:${pane_id#%}:$$"
    resize_bind="resize:print(${resize_token})+accept,ctrl-r:print(${resize_token})+accept"
    toggle_fullscreen_bind="f2:print(${toggle_fullscreen_token})+accept"
    toggle_preview_bind="f4:toggle-preview"
    popup_size="${POPUP_SIZE_NORMAL}"
    fzf_query=
    preview_cmd='printf "%s" {2..}'
}

toggle_popup_size() {
    if [[ "${popup_size}" == "${POPUP_SIZE_NORMAL}" ]]; then
        popup_size="${POPUP_SIZE_FULLSCREEN}"
        return 0
    fi

    popup_size="${POPUP_SIZE_NORMAL}"
}

picker_header() {
    printf 'tmux capture-pane -p -J -N -t %s -S - (line no from -T -N)' "${pane_id}"
}

run_picker() {
    local -a picker_cmd=(
        "${fzf_bin_base[@]}"
        "${popup_size}"
        --no-sort
        --bind=change:first
        --color
        dark
        --print-query
        --delimiter=:
        --nth=2..
        --query="${fzf_query}"
        --prompt="${PICKER_PROMPT}"
        --header="$(picker_header)"
        --ghost="${PICKER_GHOST}"
        --preview="${preview_cmd}"
        --preview-window="${PREVIEW_WINDOW}"
        --bind
        "${resize_bind}"
        --bind
        "${toggle_fullscreen_bind}"
        --bind
        "${toggle_preview_bind}"
    )

    tmux_pane_search_build_lines "${pane_id}" | "${picker_cmd[@]}"
}

extract_picker_selection() {
    local picker_output="${1}"
    local picker_payload=

    if [[ "${picker_output}" == *$'\n'* ]]; then
        fzf_query="${picker_output%%$'\n'*}"
        picker_payload="${picker_output#*$'\n'}"
    else
        fzf_query="${picker_output}"
        picker_payload=
    fi

    selected_line="${picker_payload%%$'\n'*}"
}

handle_picker_action() {
    case "${selected_line}" in
        "${resize_token}")
            return 1
            ;;
        "${toggle_fullscreen_token}")
            toggle_popup_size
            return 1
            ;;
    esac

    return 0
}

pick_line() {
    local picker_output=
    local picker_status=0

    while true; do
        picker_output="$(run_picker)"
        picker_status=$?
        (( picker_status == 0 )) || return 1

        extract_picker_selection "${picker_output}"
        handle_picker_action && return 0
    done
}

exit_copy_mode() {
    tmux send-keys -t "${pane_id}" -X cancel
    return 1
}

parse_selected_line_num() {
    local line_num="${selected_line%%:*}"

    if ! [[ "${line_num}" =~ ^[0-9]+$ ]]; then
        show_tmux_message "tmux-copy-fzf-search: failed to parse selected line"
        return 1
    fi

    printf '%s\n' "${line_num}"
}

jump_to_line() {
    local line_num="${1}"

    tmux send-keys -t "${pane_id}" -X history-top || return 1
    tmux send-keys -t "${pane_id}" -X top-line || return 1

    if (( line_num > 1 )); then
        tmux send-keys -N "$((line_num - 1))" -t "${pane_id}" -X cursor-down || return 1
    fi
}

main() {
    local line_num=

    command -v tmux >/dev/null 2>&1 || return 0
    load_tmux_pane_search_lib || return 1
    resolve_pane_id "${1:-}" || return 0
    enter_copy_mode || return 1
    init_fzf_backend || return 0
    init_picker_state
    pick_line || exit_copy_mode || return 0

    line_num="$(parse_selected_line_num)" || return 1
    jump_to_line "${line_num}"
}

main "$@"
