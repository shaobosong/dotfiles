#!/usr/bin/env bash
set -u

if ! command -v tmux >/dev/null 2>&1; then
    exit 0
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tmux_pane_search_lib="${script_dir}/../rc/tmux-pane-search-lib"
if [[ ! -r "${tmux_pane_search_lib}" ]]; then
    tmux display-message "tmux-copy-fzf-search: missing tmux-pane-search-lib.sh"
    exit 1
fi
. "${tmux_pane_search_lib}"

pane_id="${1:-}"
if [[ -z "${pane_id}" ]]; then
    pane_id="$(tmux display-message -p '#{pane_id}' 2>/dev/null)" || exit 0
fi
[[ -n "${pane_id}" ]] || exit 0

if command -v fzf-tmux >/dev/null 2>&1; then
    fzf_bin=(fzf-tmux -p 85%,85%)
elif command -v fzf >/dev/null 2>&1; then
    fzf_bin=(fzf --tmux 85%,85%)
else
    tmux display-message "Failed to find fzf or fzf-tmux"
    exit 0
fi

resize_token="0:__FZF_TMUX_PANE_RESIZE__:${pane_id#%}:$$"
resize_bind="resize:print(${resize_token})+accept"
fzf_query=

while true; do
    fzf_output=$(tmux_pane_search_build_lines "${pane_id}" | "${fzf_bin[@]}" \
        --no-sort \
        --bind=change:first \
        --color dark \
        --print-query \
        --delimiter=: \
        --nth=2.. \
        --query="${fzf_query}" \
        --prompt="Search Current Pane> " \
        --header="tmux capture-pane -p -J -N -t ${pane_id} -S - (line no from -T -N)" \
        --ghost="<enter>: Jump to line" \
        --bind "${resize_bind}")
    fzf_status=$?

    (( fzf_status == 0 )) || exit 0

    if [[ "${fzf_output}" == *$'\n'* ]]; then
        fzf_query="${fzf_output%%$'\n'*}"
        fzf_payload="${fzf_output#*$'\n'}"
    else
        fzf_query="${fzf_output}"
        fzf_payload=
    fi

    fzf_payload_first_line="${fzf_payload%%$'\n'*}"
    [[ "${fzf_payload_first_line}" == "${resize_token}" ]] && continue
    fzf_output="${fzf_payload_first_line}"
    break
done

line_num="${fzf_output%%:*}"
if ! [[ "${line_num}" =~ ^[0-9]+$ ]]; then
    tmux display-message "tmux-copy-fzf-search: failed to parse selected line"
    exit 1
fi

tmux select-pane -t "${pane_id}" || exit 1
tmux copy-mode -t "${pane_id}" || exit 1
tmux send-keys -t "${pane_id}" -X history-top || exit 1
tmux send-keys -t "${pane_id}" -X top-line || exit 1
if (( line_num > 1 )); then
    tmux send-keys -N "$((line_num - 1))" -t "${pane_id}" -X cursor-down || exit 1
fi
