#!/usr/bin/env bash

TMUX_PANE_SEARCH_LAST_ERROR=
TMUX_PANE_SEARCH_LAST_CODE=0

tmux_pane_search_build_lines() {
    local pane_id="${1-}"
    local joined_line=
    local raw_line=
    local line_start_no=
    local raw_line_no=
    local joined_len=
    local joined_pos=
    local raw_len=
    local raw_fd=
    local raw_capture_pid=
    local joined_fd=
    local joined_capture_pid=
    local raw_capture_status=
    local joined_capture_status=
    local failed=0
    local output_closed=0

    TMUX_PANE_SEARCH_LAST_ERROR=
    TMUX_PANE_SEARCH_LAST_CODE=0

    [[ -n "${pane_id}" ]] || {
        TMUX_PANE_SEARCH_LAST_ERROR="empty pane id"
        TMUX_PANE_SEARCH_LAST_CODE=10
        return 10
    }

    exec {raw_fd}< <(tmux capture-pane -p -T -N -t "${pane_id}" -S -) || {
        TMUX_PANE_SEARCH_LAST_ERROR="failed to start raw pane capture"
        TMUX_PANE_SEARCH_LAST_CODE=11
        return 11
    }
    raw_capture_pid=$!

    exec {joined_fd}< <(tmux capture-pane -p -J -N -t "${pane_id}" -S -) || {
        exec {raw_fd}<&-
        wait "${raw_capture_pid}" >/dev/null 2>&1 || true
        TMUX_PANE_SEARCH_LAST_ERROR="failed to start joined pane capture"
        TMUX_PANE_SEARCH_LAST_CODE=12
        return 12
    }
    joined_capture_pid=$!

    raw_line_no=1

    while IFS= read -r -u "${joined_fd}" joined_line; do
        line_start_no=${raw_line_no}
        joined_len=${#joined_line}

        if (( joined_len == 0 )); then
            # Empty joined line must map to one empty raw line.
            if ! IFS= read -r -u "${raw_fd}" raw_line; then
                failed=1
                break
            fi
            [[ -z "${raw_line}" ]] || {
                failed=1
                break
            }
            ((raw_line_no++))
        else
            joined_pos=0
            while (( joined_pos < joined_len )); do
                if ! IFS= read -r -u "${raw_fd}" raw_line; then
                    failed=1
                    break 2
                fi

                raw_len=${#raw_line}
                (( joined_pos + raw_len <= joined_len )) || {
                    failed=1
                    break 2
                }

                [[ "${joined_line:joined_pos:raw_len}" == "${raw_line}" ]] || {
                    failed=1
                    break 2
                }

                joined_pos=$((joined_pos + raw_len))
                ((raw_line_no++))
            done
        fi

        printf '%s:%s\n' "${line_start_no}" "${joined_line}" || {
            output_closed=1
            break
        }
    done

    if (( ! failed && ! output_closed )) && IFS= read -r -u "${raw_fd}" raw_line; then
        failed=1
    fi

    exec {joined_fd}<&-
    exec {raw_fd}<&-

    if (( output_closed )); then
        kill "${joined_capture_pid}" "${raw_capture_pid}" >/dev/null 2>&1 || true
    fi

    wait "${joined_capture_pid}"
    joined_capture_status=$?
    wait "${raw_capture_pid}"
    raw_capture_status=$?

    if (( failed )); then
        TMUX_PANE_SEARCH_LAST_ERROR="failed to map joined pane line to raw line index"
        TMUX_PANE_SEARCH_LAST_CODE=13
        return 13
    fi

    if (( output_closed )); then
        return 0
    fi

    (( joined_capture_status == 0 )) || {
        TMUX_PANE_SEARCH_LAST_ERROR="failed to capture joined pane lines"
        TMUX_PANE_SEARCH_LAST_CODE=14
        return 14
    }
    (( raw_capture_status == 0 )) || {
        TMUX_PANE_SEARCH_LAST_ERROR="failed to capture raw pane lines"
        TMUX_PANE_SEARCH_LAST_CODE=15
        return 15
    }

    return 0
}
