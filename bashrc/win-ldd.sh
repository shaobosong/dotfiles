#!/usr/bin/env bash
# ldd
#
# Based on
# https://github.com/shiluotang/ldd-light/blob/master/ldd-light
#
# Example:
# ./ldd.sh --dir=path1 --dir=path2 *.dll *.exe
#

PROGNAME=$(basename $0)
DIRS=("$PWD")
OBJDUMP=
XXD=

panic ()
{
    1>&2 echo "Error: $@"
    exit 1
}

while test $# -gt 0; do
    optarg=`expr "x$1" : 'x[^=]*=\(.*\)'`
    case $1 in
        -\? | -h | --h | --he | --hel | --help)
            echo $"Usage: $PROGNAME [options] file
  --help              Print this message
  --dir=<directory>   Append a search directory. Default '.'"
            exit 0
            ;;
        --dir=*)
            newpath=$(realpath $optarg)
            DIRS=("${DIRS[@]%$newpath}" "$newpath")
            shift
            ;;
        -*)
            panic "Unknown option '$1', see --help for list of valid ones."
            ;;
        *)
            break
            ;;
    esac
done

case $# in
    0)
        echo >&2 $PROGNAME $"missing file arguments"
        echo >&2 $"Try \`$PROGNAME --help' for more information."
        exit 1
        ;;
    1)
        single_file=t
        ;;
    *)
        single_file=f
        ;;
esac

OBJDUMP=$(which objdump)
case $? in
    1)
        echo $"command 'objdump' not found" >&2
        exit 1
        ;;
esac

XXD=$(which xxd)
case $? in
    1)
        echo $"command 'xxd' not found" >&2
        exit 1
        ;;
esac

result=0
for file do
    # We don't list the file name when there is only one.
    test $single_file = t || printf $"%s:\n" $file
    case $file in
        */*) :
            ;;
        *) file=./$file
            ;;
    esac
    if test ! -e "$file"; then
        echo "$PROGNAME: ${file}:" $"No such file or directory" >&2
        result=1; break
    elif test ! -f "$file"; then
        echo "$PROGNAME: ${file}:" $"not regular file" >&2
        result=1; break
    elif test ! -r "$file"; then
        echo "$PROGNAME: ${file}:" $"not readable file" >&2
        result=1; break
    fi

    # Validate that the given file is a PE file
    dos_e_magic=$($XXD -ps -l 2 $file) # 0x5a4d ("MZ")
    if test $dos_e_magic != "4d5a"; then
        echo "$PROGNAME: ${file}:" $"File format not recognized" >&2
        result=1; break
    fi

    # Determine whether it's a PE32 or PE32+ file
    dos_e_lfanew=$($XXD -e -s 0x3c -l 4 $file | tr -s " " | cut -d' ' -f2)
    nt_signature=$($XXD -ps -s 0x$dos_e_lfanew -l 4 $file) # 0x00004550 ("PE\0\0")
    if test $nt_signature != "50450000"; then
        echo "$PROGNAME: ${file}:" $"PE file's NT_HEADER_SIGNATURE parse error" >&2
        result=1; break
    fi
    optional_magic=$($XXD -ps -s $(( 0x$dos_e_lfanew + 0x18 )) -l 2 $file)
    case $optional_magic in
        "0b01" | "0b02" | "0701")
            ;;
        *)
            echo "$PROGNAME: ${file}:" $"PE file's OPTIONAL_HEADER_MAGIC parse error" >&2
            result=1; break
            ;;
    esac

    # Check dependencies
    deps=($(\
        $OBJDUMP -p $file |\
        grep -E -e '^[[:space:]]+DLL Name: ' |\
        sed -e 's/.*DLL Name: //g'\
        ))
    if test ${#deps[@]} -eq 0; then
        echo "$PROGNAME: ${file}:" $"not a dynamic executable" >&2
        result=1; break
    fi

    for dep in ${deps[@]}; do
        found=no
        for dir in ${DIRS[@]}; do
            if test -f "$dir/$dep"; then
                test x$found = xno \
                    && printf $"\t%s => %s\n" $dep $dir && found=yes \
                    || printf $"\t%${#dep}s => %s\n" '' $dir
            fi
        done
        test x$found = xno \
            && printf $"\t%s => Not found\n" $dep
    done
done

exit $result
