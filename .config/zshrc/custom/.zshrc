# -----------------------------------------------------
# Exports
# -----------------------------------------------------
export EDITOR=code-insiders
export PATH="/usr/lib/ccache/bin/:$PATH"
export ZSH="$HOME/.oh-my-zsh"

#nodejs
export PNPM_HOME="/home/tymon/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end


#spicetify
export PATH=$PATH:/home/tymon/.spicetify


# pipx
export PATH="$PATH:/home/tymon/.local/bin"

# Golang environment variables
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin

# Update PATH to include GOPATH and GOROOT binaries
export PATH=$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$PATH

#pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"


eval $(thefuck --alias)

#aliases
source ~/.config/zshrc/10-aliases

#OH-MY-ZSH
#--------------------------------
ZSH_THEME=xiong-chiamiov-plus
plugins=(
    git
    sudo
    web-search
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
    fast-syntax-highlighting
    copyfile
    copybuffer
    dirhistory
    vscode
)
source $ZSH/oh-my-zsh.sh
source <(fzf --zsh)

# zsh history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

eval "$(oh-my-posh init zsh --config /usr/share/oh-my-posh/themes/kushal.omp.json)"
#--------------------------------

#AUTOSTART
fastfetch --config examples/17