#!/usr/bin/env bash

TMUX_PANE_SEARCH_LAST_ERROR=
TMUX_PANE_SEARCH_LINES=()

tmux_pane_search_build_lines() {
    local pane_id="${1-}"
    local -a pane_lines_raw=()
    local -a pane_lines_joined=()
    local pane_joined_line=
    local pane_raw_cursor=
    local pane_raw_match_cursor=
    local pane_line_mapped=
    local pane_joined_pos=
    local pane_joined_len=
    local pane_raw_line=
    local pane_raw_len=

    TMUX_PANE_SEARCH_LAST_ERROR=
    TMUX_PANE_SEARCH_LINES=()

    [[ -n "${pane_id}" ]] || {
        TMUX_PANE_SEARCH_LAST_ERROR="empty pane id"
        return 1
    }

    mapfile -t pane_lines_raw < <(tmux capture-pane -p -T -N -t "${pane_id}" -S -) || {
        TMUX_PANE_SEARCH_LAST_ERROR="failed to capture raw pane lines"
        return 1
    }
    mapfile -t pane_lines_joined < <(tmux capture-pane -p -J -N -t "${pane_id}" -S -) || {
        TMUX_PANE_SEARCH_LAST_ERROR="failed to capture joined pane lines"
        return 1
    }

    (( ${#pane_lines_raw[@]} > 0 )) || return 0

    pane_raw_cursor=0
    for pane_joined_line in "${pane_lines_joined[@]}"; do
        (( pane_raw_cursor < ${#pane_lines_raw[@]} )) || break

        pane_line_mapped=0
        pane_joined_pos=0
        pane_joined_len=${#pane_joined_line}
        pane_raw_match_cursor=${pane_raw_cursor}
        while (( pane_raw_match_cursor < ${#pane_lines_raw[@]} )); do
            pane_raw_line="${pane_lines_raw[pane_raw_match_cursor]}"
            pane_raw_len=${#pane_raw_line}

            (( pane_joined_pos + pane_raw_len <= pane_joined_len )) || break
            [[ "${pane_joined_line:pane_joined_pos:pane_raw_len}" == "${pane_raw_line}" ]] || break

            pane_joined_pos=$((pane_joined_pos + pane_raw_len))
            if (( pane_joined_pos == pane_joined_len )); then
                TMUX_PANE_SEARCH_LINES+=("$((pane_raw_cursor + 1)):${pane_joined_line}")
                pane_raw_cursor=$((pane_raw_match_cursor + 1))
                pane_line_mapped=1
                break
            fi
            ((pane_raw_match_cursor++))
        done

        if (( ! pane_line_mapped )); then
            TMUX_PANE_SEARCH_LAST_ERROR="failed to map joined pane line to raw line index"
            return 1
        fi
    done

    return 0
}
