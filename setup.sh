#!/bin/sh

set -e

ROOT=$(dirname "$(readlink -f "${0}")")

file_is_exist() {
    # don't ignore broken link type file
    test -e "${1}" -o -L "${1}"
}

backup() {
    if test -L "${1}"; then
        rm -rf "${1}"
    else
        mv --backup=numbered -Tv "${1}" "${1}.bak"
    fi
}

# version 0.1
# # export -f file_is_exist
# # export -f backup

# if file_is_exist "${HOME}/.bashrc"; then
#     backup "${HOME}/.bashrc"
# fi
# ln -nsTv "${ROOT}/.bashrc" "${HOME}/.bashrc"

# if file_is_exist "${HOME}/.bash.d"; then
#     backup "${HOME}/.bash.d"
# fi
# ln -nsTv "${ROOT}/.bash.d" "${HOME}/.bash.d"

# mkdir -p "${HOME}/.config"
# # find -L "${ROOT}/.config" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" |\
# #     xargs -I {} bash -c "file_is_exist ${HOME}/.config/{} && backup ${HOME}/.config/{} || true"
# find -L "${ROOT}/.config" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" |\
#     while read -r file; do
#         if file_is_exist "${HOME}/.config/${file}"; then
#             backup "${HOME}/.config/${file}"
#         fi
#     done
# find -L "${ROOT}/.config" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" |\
#     xargs -I {} ln -nsTv "${ROOT}/.config/{}" "${HOME}/.config/{}"

# if file_is_exist "${HOME}/.profile"; then
#     backup "${HOME}/.profile"
# fi
# ln -nsTv "${ROOT}/.bashrc" "${HOME}/.profile"

# mkdir -p "${HOME}/.ssh"
# if file_is_exist "${HOME}/.ssh/config"; then
#     backup "${HOME}/.ssh/config"
# fi
# ln -nsTv "${ROOT}/.ssh/config" "${HOME}/.ssh/config"

# if file_is_exist "${HOME}/.tmux.conf"; then
#     backup "${HOME}/.tmux.conf"
# fi
# ln -nsTv "${ROOT}/.tmux.conf" "${HOME}/.tmux.conf"

# version 0.2
set -- \
    ".bashrc" \
    ".bash.d" \
    ".config/fd" \
    ".config/nvim" \
    ".config/ripgrep" \
    ".profile" \
    ".ssh/config" \
    ".tmux.conf" \

for file in "${@}"; do
    if file_is_exist "${HOME}/${file}"; then
        backup "${HOME}/${file}"
    fi
    ln -nsTv "${ROOT}/${file}" "${HOME}/${file}"
done

echo "Success"
exit 0
