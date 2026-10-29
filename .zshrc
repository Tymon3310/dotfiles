
# tty8 starts Hyprland straight away, before any plugins or fastfetch load
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty 2>/dev/null)" = "/dev/tty8" ]; then
	exec start-hyprland
fi

# Keep PATH clean and deduplicated
typeset -U path PATH

_zsh_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d $_zsh_cache ]] || mkdir -p "$_zsh_cache"

# Tools like zoxide and fzf print the same init script on every start.
# Cache it and regenerate only when the tool itself is updated.
#   _cached_init <name> <command> [args...]
_cached_init() {
    local name=$1 bin=${commands[$2]}
    [[ -n $bin ]] || return 0
    local cache=$_zsh_cache/init-$name.zsh
    if [[ ! -s $cache || $bin -nt $cache ]]; then
        "${@:2}" >| $cache 2>/dev/null || { rm -f $cache; return 0 }
    fi
    source $cache
}

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="" # Prompt handled by Oh-My-Posh below
plugins=(
    git
    sudo
    web-search
    archlinux
    zsh-autosuggestions
    fast-syntax-highlighting
    copyfile
    copybuffer
    zsh-autocomplete
    vscode
)
autoload -Uz add-zsh-hook
autoload -U colors && colors
fpath=($HOME/.zfunc $fpath)
export ZSH_COMPDUMP="$_zsh_cache/.zcompdump-$HOST-$ZSH_VERSION"
# install.sh updates Oh My Zsh, so skip its own update check, and skip the
# completion-dir permission audit (single-user machine).
zstyle ':omz:update' mode disabled
ZSH_DISABLE_COMPFIX=true
source $ZSH/oh-my-zsh.sh

[[ -t 0 ]] && _cached_init fzf fzf --zsh

# History: large, shared live between terminals, no duplicates.
# A command starting with a space is not saved.
HISTFILE=~/.zsh_history
HISTSIZE=200000
SAVEHIST=100000
setopt extended_history share_history hist_ignore_all_dups hist_save_no_dups \
    hist_ignore_space hist_reduce_blanks hist_verify hist_expire_dups_first

eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/EDM115-newline.omp.json)"


# Private exports (if present)
[ -f ~/.env ] && source ~/.env

export EDITOR=nvim

# Core path directories
path=(
    $HOME/.local/bin
    /usr/lib/ccache/bin
    $path
)

export PNPM_HOME="$HOME/.local/share/pnpm"
[[ ":$PATH:" != *":$PNPM_HOME:"* ]] && path=($PNPM_HOME $path)

# nvm costs ~80 ms to load and node comes from the system, so nvm loads the
# first time it is run.
export NVM_DIR="$HOME/.nvm"
if [[ -s $NVM_DIR/nvm.sh ]]; then
    nvm() {
        unfunction nvm
        source "$NVM_DIR/nvm.sh"
        [[ -s $NVM_DIR/bash_completion ]] && source "$NVM_DIR/bash_completion"
        nvm "$@"
    }
fi

export GOROOT=/usr/local/go
export GOPATH=$HOME/go
path=($path $GOROOT/bin $GOPATH/bin)
export LD_LIBRARY_PATH=/usr/local/lib

path=($path "$HOME/.wakatime")


_cached_init zoxide zoxide init zsh

zle -N accept-line _emptyenter

_emptyenter() {
    if [[ -z "$BUFFER" ]]; then
        zle redisplay
    else
        zle .accept-line
    fi
}


source ~/.config/zshrc/aliases.zsh
if [ -f "$HOME/custom-commands" ]; then
    source "$HOME/custom-commands"
fi

for f in ~/.config/zshrc/functions/*.zsh; do
    [ -f "$f" ] && source "$f"
done


# Don't run fastfetch in VSCode integrated terminal
if [[ -z $VSCODE_INJECTION ]]; then
    fastfetch -c ~/.config/fastfetch/arch
fi

printf -v SUDO_PROMPT '\x1b[38;2;255;255;255m╭─\x1b[38;2;0;43;84m\x1b[48;2;0;43;84m\x1b[38;2;230;240;255m%s\x1b[0m\x1b[48;2;30;80;128m\x1b[38;2;0;43;84m\x1b[38;2;255;0;0m \x1b[0m\x1b[48;2;0;92;179m\x1b[38;2;30;80;128m\x1b[38;2;230;240;255m enter password for %s:\x1b[0m\x1b[38;2;0;92;179m\x1b[0m\n\x1b[38;2;255;255;255m╰─❯ \x1b[0m' "sudo" "$USER"
export SUDO_PROMPT

if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

_cached_init wakatime terminal-wakatime init

