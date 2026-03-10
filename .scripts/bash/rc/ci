#!/bin/bash
# Usage:
#   source ci.sh [INDEX]
# Example:
#   $ echo 'source /path/ci.sh' >> ~/.bashrc
#   $ source ~/.bashrc
#   $ ci
#   /home/user/some/path
#   ----3----2----1----0
#   2 (input a index)
#   /home/user
#   $

ci() {
    dir=$PWD
    dirs=($dir)
    line=""
    sign='-'

    for optarg do
        case $optarg in
            --help)
                echo $"Usage: source cd-index.sh [INDEX]
Display current directory with index number, and change directory by index if need
Options:
  --help    print this message
  INDEX     index of directory"
            ;;
            -*)
                echo $"Unknown option '$1', see --help for list of valid ones" 1>&2
                ;;
            *)
                break
                ;;
        esac
    done

    while test "$dir" != "/"; do
        dir=$(dirname $dir)
        dirs+=($dir)
    done

    id=
    if test x"${1+set}" = x; then
        echo "$PWD"
        line=$(printf "%${#dirs[0]}s" "" | tr ' ' $sign)
        for i in "${!dirs[@]}"; do
            test $i -ge 100 && break
            test $i -lt $((${#dirs[@]}-1)) \
                && line="${line:0:$((${#dirs[$i]}-${#i}))}$i${line:${#dirs[$i]}}"
        done
        echo "$line"
        read -e id
    else
        id=$1
    fi

    id=$(expr x"$id" : x"\([0-9]*$\)")
    test -n "$id" && test $id -lt ${#dirs[@]} \
        && cd ${dirs[$id]} && echo ${dirs[$id]}
}
