#!/usr/bin/env bash

set -e -o pipefail

ACTION=off

function parse_args () {
    while test $# -gt 0; do
        optarg="${1#*=}"
        case $1 in
            -\? | -h | --help)
                echo $"Usage: $PROGNAME [options] [configure options]
      --help                     Print this message
      --action=<on|off>          Build type (default: debug)"
                exit 0
                ;;
            --action=on | --action=off)
                ACTION=$optarg
                shift
                ;;
            *)
                echo $"Unknown option: ${1}" 2>&1
                exit 255
        esac
    done
}

parse_args ${@}

if test "$ACTION" = "on"; then
    printf '\033[?1000h' # X10
    printf '\033[?1002h' # VT200
    printf '\033[?1006h' # SGR
elif test "$ACTION" = "off"; then
    printf '\033[?1000l'
    printf '\033[?1002l'
    printf '\033[?1006l'
fi
