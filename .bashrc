# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

_dotfiles_root=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
_scripts="${_dotfiles_root}/.scripts/bash"

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
# A value of 'erasedups' causes all previous lines matching the current
# line to be removed from the history list before that line is saved.
HISTCONTROL=ignoreboth:erasedups

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=20000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    # red:yellow
    PS1='\033[01;31m\u@\h\033[00m:\033[01;33m\w\033[00m ($?)\n\$ '
    # green:blue
    PS1='\033[01;32m\u@\h\033[00m:\033[01;34m\w\033[00m ($?)\n\$ '
else
    PS1='\u@\h:\w ($?)\n\$ '
fi
unset color_prompt force_color_prompt

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# aliases
alias ci="source ${_scripts}/misc/cd-index.sh"

alias cls='printf "\033[2J\033[3J\033[1;1H"'
alias 2hex='printf %x\\n'
alias 2dec='printf %d\\n'

alias lg='\lazygit'
alias curls5='\curl -x socks5h://$(\awk '\''$2 == "00000000" {print strtonum("0x" substr($3,7,2)) "." strtonum("0x" substr($3,5,2)) "." strtonum("0x" substr($3,3,2)) "." strtonum("0x" substr($3,1,2))}'\'' /proc/net/route):2208'
alias nf='fzf --bind "enter:become(nvim {})" --bind "alt-J:jump,jump:become(nvim {})" --bind "ctrl-v:execute(nvim -R {})"'
alias ng='\grep -rRnI "" | fzf --delimiter=: --nth=3 --tiebreak=index --bind "enter:become(nvim {1} +{2})" --bind "ctrl-v:execute(nvim -R {1} +{2})"'

# exports
export EDITOR=/usr/bin/nano
export PROMPT_COMMAND="history -a; #history -n"
export FZF_DEFAULT_OPTS="--bind=tab:down,btab:up,alt-j:down,alt-k:up,alt-l:abort,ctrl-alt-h:backward-kill-word,change:first --cycle"
export DELTA_FEATURES='+side-by-side'
export RIPGREP_CONFIG_PATH=${_dotfiles_root}/.config/ripgrep/config
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export GOMODCACHE=$HOME/.cache/go/pkg/mod
export GOPATH=$HOME/.go
export GOPROXY=https://goproxy.cn
export PATH=$_scripts/link:$PATH
export PATH=$HOME/.cargo/bin:$PATH

# sources
if test -f /usr/share/fzf/completion.bash; then
    source /usr/share/fzf/completion.bash
fi
if test -f /usr/share/fzf/key-bindings.bash; then
    source /usr/share/fzf/key-bindings.bash
fi
