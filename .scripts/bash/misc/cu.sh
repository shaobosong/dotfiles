#  ██████╗██╗   ██╗
# ██╔════╝██║   ██║
# ██║     ██║   ██║
# ██║     ██║   ██║
# ╚██████╗╚██████╔╝
#  ╚═════╝ ╚═════╝  cu: Interactively change directory upwards
#
# Usage:
#   1. Add a source to "cu.sh" in ~/.bashrc
#   2. (Optional) Set keymap before sourcing: export CU_KEYMAP="emacs"
#   3. Run `source ~/.bashrc` or open a new terminal
#   4. Type `cu` in any nested directory
#
# Configuration:
#   - CU_KEYMAP: Set to "vim" (default) or "emacs" to change key bindings.
#

cu() {
    # Set default keymap if not configured by the user
    : "${CU_KEYMAP:=vim}"

    # Exit if in root directory
    [[ "$PWD" == "/" ]] && return 0

    # ANSI escape codes for TUI rendering
    local HL_START=$({ tput smso >/dev/null 2>&1 && tput smso; } || { tput setaf 3 >/dev/null 2>&1 && tput setaf 3; } || echo '**') # Highlight start (standout mode)
    local HL_END=$({ tput rmso >/dev/null 2>&1 && tput rmso; } || { tput sgr0 >/dev/null 2>&1 && tput sgr0; } || echo '**')         # Highlight end (exit standout mode)
    local CURSOR_HIDE=$(tput civis) # Hide cursor
    local CURSOR_SHOW=$(tput cnorm) # Show cursor
    local CLEAR_LINE=$(tput el)     # Clear line from cursor to end

    # Split path into an array: /a/b/c -> (a b c)
    local path_parts=(${PWD//\// })
    local num_parts=${#path_parts[@]}
    local current_index=$((num_parts - 1))
    local cnt_act=""
    local last_cnt_act=""
    local last_act=""

    # New line
    _newline() {
        printf "\r\n"
    }

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
    _change_dir() {
        # Build the target path from the selected index
        local target_dir="/"
        for i in $(seq 0 $current_index); do
            target_dir+="${path_parts[i]}/"
        done
        printf "\r${target_dir}${CLEAR_LINE}\n"
        cd "$target_dir"
    }

    # Renders the interactive path string
    _render() {
        local display_path="/"
        for i in "${!path_parts[@]}"; do
            if [[ $i -eq $current_index ]]; then
                display_path+="${HL_START}${path_parts[i]}${HL_END}/"
            else
                display_path+="${path_parts[i]}/"
            fi
        done
        # \r moves cursor to line start, then we print and clear extra chars
        printf "\r${display_path}${CLEAR_LINE}"
    }

    _loop() {
        while true; do
            _render
            # Read a single character (-s: silent, -n 1: one char)
            # Using $'' syntax for control characters
            read -rsn1 key

            # Handle multi-byte sequences for Alt keys and arrows
            if [[ "$key" == $'\x1b' ]]; then # ESC character
                # Read next chars with a tiny timeout to see if it's a sequence
                read -rsn1 -t 0.01 next_key
                key+="$next_key"
                read -rsn1 -t 0.01 next_key
                key+="$next_key"
            fi

            # Key dispatcher based on the configured keymap
            if [[ "$CU_KEYMAP" == "emacs" ]]; then
                case "$key" in
                    $'\x02' | $'\x1b[D' | $'\x1bb') _move_left ;;  # C-b, Left Arrow, Alt-b
                    $'\x06' | $'\x1b[C' | $'\x1bf') _move_right ;; # C-f, Right Arrow, Alt-f
                    $'\x01' | $'\x1b[H' | $'\x1b[1') _move_start ;; # C-a, Home
                    $'\x05' | $'\x1b[F' | $'\x1b[4') _move_end ;;   # C-e, End
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
                esac
            fi
            case "$key" in
                # FIXME: Tab key triggering issue
                '') _change_dir; return 0 ;; # Enter, C-m, C-j
                'q' | $'\x1b') _newline; return 0 ;; # q, or ESC
            esac
        done
    }

    _loop
}
