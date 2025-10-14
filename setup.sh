#!/bin/sh

set -e

ROOT=$(dirname "$(readlink -f "${0}")")

backup() {
    if test -L "${1}"; then
        rm -rvf "${1}"
    fi
    if test -e "${1}"; then
        mv --backup=numbered -Tv "${1}" "${1}.bak"
    fi
}

# version 0.1
# # export -f backup

# mkdir -p "${HOME}/.config"
# # find -L "${ROOT}/.config" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" |\
# #     xargs -I {} backup ${HOME}/.config/{}
# find -L "${ROOT}/.config" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" |\
#     while read -r file; do
#         backup "${HOME}/.config/${file}"
#     done
# find -L "${ROOT}/.config" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" |\
#     xargs -I {} ln -nsTv "${ROOT}/.config/{}" "${HOME}/.config/{}"

# version 0.2
set -- \
    ".bashrc" \
    ".config/alacritty" \
    ".config/fd" \
    ".config/gdb" \
    ".config/git" \
    ".config/nvim" \
    ".config/ripgrep" \
    ".config/tmux" \
    ".profile" \
    ".scripts" \
    ".ssh/config" \
    ".tmux.conf" \
    ".vimrc"

mkdir -pv "${HOME}/.config"
mkdir -pv "${HOME}/.ssh"

for file in "${@}"; do
    backup "${HOME}/${file}"
    ln -nsTv "${ROOT}/${file}" "${HOME}/${file}"
done

mkdir -pv "${ROOT}/.scripts/bash/link"
cd "${ROOT}/.scripts/bash/link"

set -- \
    "../generic/cmake-build" \
    "../generic/configure-build" \
    "../generic/meson-build" \
    "../misc/make-image.sh" \
    "../misc/scp-tar.sh" \
    "../misc/win-ldd.sh"

for file in "${@}"; do
    basename=${file##*/}
    prefix=${basename%.*}
    ln -fnsTv "${file}" "${prefix}"
done

echo "Succeed"
exit 0
