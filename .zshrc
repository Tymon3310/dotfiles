# -----------------------------------------------------
#aliases
# -----------------------------------------------------

source ~/.config/zshrc/aliases

# -----------------------------------------------------
#OH-MY-ZSH
# -----------------------------------------------------

export ZSH="$HOME/.oh-my-zsh"
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

eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/kushal.omp.json)"

# -----------------------------------------------------
#AUTOSTART
# -----------------------------------------------------

#fastfetch --config examples/17
fastfetch -c groups

# -----------------------------------------------------
# Exports
# -----------------------------------------------------

export EDITOR=nvim
export PATH="/usr/lib/ccache/bin/:$PATH"


#nodejs
export PNPM_HOME="/home/tymon/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# python things
export PATH="$PATH:/home/tymon/.local/bin"
#pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Golang environment variables
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin

# Update PATH to include GOPATH and GOROOT binaries
export PATH=$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$PATH


eval $(thefuck --alias)

export PATH=$PATH:/home/tymon/.spicetify
bindkey '^X' create_completion
