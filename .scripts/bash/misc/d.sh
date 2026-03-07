# ██████╗
# ██╔══██╗
# ██║  ██║
# ██║  ██║
# ██████╔╝
# ╚═════╝ d: Interactively change directory
#
# Usage:
#   1. Add a source to "d.sh" in ~/.bashrc
#   2. (Optional) Set keymap before sourcing: export D_KEYMAP="emacs"
#   3. Run `source ~/.bashrc` or open a new terminal
#
# Configuration:
#   - D_KEYMAP: Set to "vim" (default) or "emacs" to change key bindings.
#

__d_term_cols__() {
    local cols

    cols=$(tput cols 2>/dev/null) || cols=80
    case "$cols" in
        ''|*[!0-9]*|0) cols=80 ;;
    esac

    printf '%s\n' "$cols"
}

__d_line_count__() {
    local text=${1-}
    local cols=${2-}
    local text_len=0
    local width=0
    local i
    local char
    local code
    local char_width

    case "$cols" in
        ''|*[!0-9]*|0) cols=$(__d_term_cols__) ;;
    esac

    text_len=${#text}
    if (( text_len == 0 )); then
        printf '1\n'
        return 0
    fi

    for (( i = 0; i < text_len; i++ )); do
        char=${text:i:1}
        printf -v code '%d' "'$char"
        char_width=1

        if ((
            code == 0x200D ||
            code == 0xFEFF ||
            (code >= 0x0300 && code <= 0x036F) ||
            (code >= 0x1AB0 && code <= 0x1AFF) ||
            (code >= 0x1DC0 && code <= 0x1DFF) ||
            (code >= 0x20D0 && code <= 0x20FF) ||
            (code >= 0xFE00 && code <= 0xFE0F) ||
            (code >= 0xFE20 && code <= 0xFE2F) ||
            (code >= 0x1F3FB && code <= 0x1F3FF) ||
            (code >= 0xE0020 && code <= 0xE007F)
        )); then
            char_width=0
        elif ((
            code >= 0x1100 && (
                code <= 0x115F ||
                code == 0x2329 ||
                code == 0x232A ||
                (code >= 0x2E80 && code <= 0xA4CF && code != 0x303F) ||
                (code >= 0xAC00 && code <= 0xD7A3) ||
                (code >= 0xF900 && code <= 0xFAFF) ||
                (code >= 0xFE10 && code <= 0xFE19) ||
                (code >= 0xFE30 && code <= 0xFE6F) ||
                (code >= 0xFF00 && code <= 0xFF60) ||
                (code >= 0xFFE0 && code <= 0xFFE6) ||
                (code >= 0x1F000 && code <= 0x1FAFF) ||
                (code >= 0x20000 && code <= 0x2FFFD) ||
                (code >= 0x30000 && code <= 0x3FFFD)
            )
        )); then
            char_width=2
        fi

        (( width += char_width ))
    done

    if (( width == 0 )); then
        printf '1\n'
    else
        printf '%s\n' $(( (width - 1) / cols + 1 ))
    fi
}

__d_clear_render__() {
    local lines=${1:-0}
    local i

    (( lines > 0 )) || return 0

    printf '\r' >&2
    for (( i = 1; i < lines; i++ )); do
        tput cuu1 >&2 2>/dev/null || true
    done
    printf '\r' >&2

    for (( i = 1; i <= lines; i++ )); do
        tput el >&2 2>/dev/null || true
        if (( i < lines )); then
            printf '\n' >&2
        fi
    done

    for (( i = 1; i < lines; i++ )); do
        tput cuu1 >&2 2>/dev/null || true
    done
    printf '\r' >&2
}

__d_or_err__() {
    # Set default keymap if not configured by the user
    : "${D_KEYMAP:=vim}"

    # ANSI escape codes for TUI rendering
    local HL_START=$({ tput smso >/dev/null 2>&1 && tput smso; } || { tput setaf 3 >/dev/null 2>&1 && tput setaf 3; } || echo '**') # Highlight start (standout mode)
    local HL_END=$({ tput rmso >/dev/null 2>&1 && tput rmso; } || { tput sgr0 >/dev/null 2>&1 && tput sgr0; } || echo '**')         # Highlight end (exit standout mode)
    local CURSOR_HIDE=$({ tput civis 2>/dev/null || true; }) # Hide cursor
    local CURSOR_SHOW=$({ tput cnorm 2>/dev/null || true; }) # Show cursor

    # Split path into an array: /a/b/c -> (a b c)
    local path=${GHOST_VIRTUAL_PATH:-$PWD}
    local path_parts=(${path//\//\/ })
    local real_path_parts=(${PWD//\//\/ })
    local num_parts=${#path_parts[@]}
    local current_index=$((${#real_path_parts[@]} - 1))
    local cnt_act=""
    local last_cnt_act=""
    local last_act=""
    local rendered_lines=0
    local rendered_path=""
    local rendered_cols=0
    local resize_pending=0
    local cursor_hidden=0
    local signal_status=0

    # Key press down event handlers
    __move_reset() {
        last_act="$1"
        last_cnt_act="$cnt_act"
        cnt_act=""
    }
    __move_by() {
        local step=$1
        cnt_act=${cnt_act:-1}
        (( current_index += step * cnt_act))
        (( current_index = (current_index < 0) ? 0 : current_index ))
        (( current_index = (current_index >= num_parts) ? num_parts - 1 : current_index ))
    }
    _move_left() {
        __move_by -1
        __move_reset "_move_left"
    }
    _move_right() {
        __move_by 1
        __move_reset "_move_right"
    }
    _move_start() {
        current_index=0
        __move_reset "_move_start"
    }
    _move_middle() {
        current_index=$((num_parts / 2))
        __move_reset "_move_middle"
    }
    _move_end() {
        current_index=$((num_parts - 1))
        __move_reset "_move_end"
    }
    _move_last() {
        cnt_act="$last_cnt_act"
        declare -F "$last_act" > /dev/null && "$last_act"
    }
    _move_count() { [[ -z "$cnt_act" && "$1" == "0" ]] && _move_start || cnt_act+="$1"; }
    _new_dir() {
        # Build the target path from the selected index
        local target_dir=""
        local i
        for i in $(seq 0 $current_index); do
            target_dir+="${path_parts[i]}"
        done
        printf '%s\n' "${target_dir}"
    }
    _yank() {
        local target_dir=""
        local clipboard_cmd=""
        local i
        if [ -n "$TMUX" ]; then
            clipboard_cmd='tmux load-buffer -w -'
        elif command -v wl-copy >/dev/null 2>&1; then
            clipboard_cmd='wl-copy'
        elif command -v xclip >/dev/null 2>&1; then
            clipboard_cmd='xclip -selection clipboard'
        elif command -v pbcopy >/dev/null 2>&1; then
            clipboard_cmd='pbcopy'
        elif command -v putclip >/dev/null 2>&1; then
            clipboard_cmd='putclip'
        fi
        for i in $(seq 0 $current_index); do
            target_dir+="${path_parts[i]}"
        done
        printf '%s' "${target_dir}" | eval "$clipboard_cmd"
    }

    _cleanup_render() {
        local term_cols

        if [ -n "$rendered_path" ]; then
            term_cols=$(__d_term_cols__)
            if (( rendered_cols != term_cols )); then
                rendered_cols=$term_cols
            fi
            rendered_lines=$(__d_line_count__ "$rendered_path" "$term_cols")
        fi
        __d_clear_render__ "$rendered_lines"
        rendered_lines=0
        rendered_path=""
        rendered_cols=0
        resize_pending=0
        if (( cursor_hidden )); then
            printf '%s' "$CURSOR_SHOW" >&2
            cursor_hidden=0
        fi
    }

    _handle_winch() {
        resize_pending=1
    }

    _restore_traps() {
        trap - EXIT HUP INT QUIT TERM WINCH
    }

    # Renders the interactive path string
    _render() {
        local display_path=""
        local plain_path=""
        local term_cols
        local i

        term_cols=$(__d_term_cols__)
        if [ -n "$rendered_path" ] && (( rendered_cols != term_cols )); then
            rendered_cols=$term_cols
            rendered_lines=$(__d_line_count__ "$rendered_path" "$term_cols")
        fi
        __d_clear_render__ "$rendered_lines"
        for i in "${!path_parts[@]}"; do
            plain_path+="${path_parts[i]}"
            if [[ $i -eq $current_index ]]; then
                display_path+="${HL_START}${path_parts[i]}${HL_END}"
            else
                display_path+="${path_parts[i]}"
            fi
        done

        printf '%s' "$display_path" >&2
        rendered_path="$plain_path"
        rendered_cols=$term_cols
        rendered_lines=$(__d_line_count__ "$plain_path" "$term_cols")
    }

    _loop() {
        trap '_cleanup_render' EXIT
        trap '_cleanup_render; _restore_traps; signal_status=129; return 129' HUP
        trap '_cleanup_render; _restore_traps; signal_status=130; return 130' INT
        trap '_cleanup_render; _restore_traps; signal_status=131; return 131' QUIT
        trap '_cleanup_render; _restore_traps; signal_status=143; return 143' TERM
        trap '_handle_winch' WINCH

        if [ -n "$CURSOR_HIDE" ]; then
            printf '%s' "$CURSOR_HIDE" >&2
            cursor_hidden=1
        fi

        while true; do
            if (( signal_status )); then
                _restore_traps
                return "$signal_status"
            fi

            # Read a single character (-s: silent, -n 1: one char)
            _render
            if (( signal_status )); then
                _restore_traps
                return "$signal_status"
            fi
            if ! read -rsn1 key; then
                if (( resize_pending )); then
                    resize_pending=0
                    continue
                fi
                _cleanup_render
                _restore_traps
                return 1
            fi

            # Handle multi-byte sequences for Alt keys and arrows
            if [[ "$key" == $'\x1b' ]]; then # ESC character
                # Read next chars with a tiny timeout to see if it's a sequence
                read -rsn1 -t 0.01 next_key
                key+="$next_key"
                read -rsn1 -t 0.01 next_key
                key+="$next_key"
            fi

            # Key dispatcher based on the configured keymap
            if [[ "$D_KEYMAP" == "emacs" ]]; then
                case "$key" in
                    $'\x02' | $'\x1b[D' | $'\x1bb') _move_left ;;  # C-b, Left Arrow, Alt-b
                    $'\x06' | $'\x1b[C' | $'\x1bf') _move_right ;; # C-f, Right Arrow, Alt-f
                    $'\x01' | $'\x1b[H' | $'\x1b[1') _move_start ;; # C-a, Home
                    $'\x05' | $'\x1b[F' | $'\x1b[4') _move_end ;;   # C-e, End
                    $'\x15') _cleanup_render; _restore_traps; _yank; return 2 ;;
                esac
            else # Default to "vim" keymap
                case "$key" in
                    'h' | 'k' | 'b' | $'\x1b[D') _move_left ;;        # h, b, k, Left Arrow
                    'l' | 'j' | 'w' | 'e' | $'\x1b[C') _move_right ;; # l, w, j, e, Right Arrow
                    'H' | '^' | $'\x1b[H' | $'\x1b[1') _move_start ;; # H, ^, Home
                    'L' | '$' | $'\x1b[F' | $'\x1b[4') _move_end ;;   # L, $, End
                    'M') _move_middle ;;
                    ';') _move_last ;; # ;
                    [0-9]) _move_count "$key" ;;
                    'y') _cleanup_render; _restore_traps; _yank; return 2 ;;
                esac
            fi
            case "$key" in
                # FIXME: Tab key triggering issue
                '') _cleanup_render; _restore_traps; _new_dir; return 0 ;; # Enter, C-m, C-j
                'q' | $'\x1b') _cleanup_render; _restore_traps; return 1 ;; # q, or ESC
            esac
        done
    }

    _loop
}

__d_widget__() {
    local clear_line=$(tput el) # Clear line from cursor to end
    local navigator ret retcode selected error
    if command -v pd >/dev/null; then
        # https://github.com/shaobosong/pd
        navigator="$(command -v pd)"
    else
        navigator="__d_or_err__"
    fi
    ret="$(${navigator})"; retcode=$?
    printf "\r${clear_line}"
    if test "$retcode" -eq 0; then
        selected="$ret"
        READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$selected${READLINE_LINE:$READLINE_POINT}"
        READLINE_POINT=$(( READLINE_POINT + ${#selected} ))
    fi
    return "$retcode"
}

gd() {
    local clear_line=$(tput el) # Clear line from cursor to end
    local navigator ret retcode target_dir error
    navigator="__d_or_err__"
    ret="$(${navigator})"; retcode=$?
    if test "$retcode" -ne 0; then
        error="$ret"
        test -n "$error" &&
            printf "\r${clear_line}%s" "${error}" >&2 ||
            printf "\r${clear_line}"
    else
        target_dir="$ret"
        printf "\r${clear_line}%s\n" "${target_dir}"
        cd "$target_dir"
    fi
    return "$retcode"
}

if (( BASH_VERSINFO[0] < 4 )); then
    # TODO: Compatible with lower 'bash' version
    false
else
    bind -m emacs-standard -x '"\ep": __d_widget__'
    bind -m vi-command -x '"\ep": __d_widget__'
    bind -m vi-insert -x '"\ep": __d_widget__'
    :
fi
