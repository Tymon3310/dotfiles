
# Keep PATH clean and deduplicated
typeset -U path PATH

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
export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-$HOST-$ZSH_VERSION"
mkdir -p "${ZSH_COMPDUMP:h}"
source $ZSH/oh-my-zsh.sh

if [[ -o interactive && -t 0 ]] && command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

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

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

export GOROOT=/usr/local/go
export GOPATH=$HOME/go
path=($path $GOROOT/bin $GOPATH/bin)
export LD_LIBRARY_PATH=/usr/local/lib

path=($path "$HOME/.spicetify" "$HOME/.wakatime")


if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

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

export SUDO_PROMPT=$(printf '\x1b[38;2;255;255;255m╭─\x1b[38;2;0;43;84m\x1b[48;2;0;43;84m\x1b[38;2;230;240;255m%s\x1b[0m\x1b[48;2;30;80;128m\x1b[38;2;0;43;84m\x1b[38;2;255;0;0m \x1b[0m\x1b[48;2;0;92;179m\x1b[38;2;30;80;128m\x1b[38;2;230;240;255m enter password for %s:\x1b[0m\x1b[38;2;0;92;179m\x1b[0m\n\x1b[38;2;255;255;255m╰─❯ \x1b[0m' "sudo" "$(whoami)")

if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

if command -v terminal-wakatime >/dev/null 2>&1; then
    eval "$(terminal-wakatime init)"
fi

if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty 2>/dev/null)" = "/dev/tty8" ]; then
	exec start-hyprland
fi
