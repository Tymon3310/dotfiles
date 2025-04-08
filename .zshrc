

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
    # dirhistory
    vscode
)
source $ZSH/oh-my-zsh.sh
source <(fzf --zsh)

# zsh history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/EDM115-newline.omp.json)"

# -----------------------------------------------------
# Exports
# -----------------------------------------------------

# Private exports
source ~/.env
# SSH agent
export SSH_AUTH_SOCK=/home/tymon/.bitwarden-ssh-agent.sock

export EDITOR=nvim
export PATH="/usr/lib/ccache/bin/:$PATH"


# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
[[ ":$PATH:" != *":$PNPM_HOME:"* ]] && export PATH="$PNPM_HOME:$PATH"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"


# Python user base
export PATH="$PATH:$HOME/.local/bin"

# pyenv
# export PYENV_ROOT="$HOME/.pyenv"
# if [ -d "$PYENV_ROOT/bin" ]; then
#   export PATH="$PYENV_ROOT/bin:$PATH"
#   eval "$(pyenv init -)"
# fi

# Golang environment variables
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin

# Update PATH to include GOPATH and GOROOT binaries
export PATH=$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$PATH


eval $(thefuck --alias)

export PATH=$PATH:/home/tymon/.spicetify
bindkey '^X' create_completion

# -----------------------------------------------------
#aliases
# -----------------------------------------------------

source ~/.config/zshrc/aliases


# -----------------------------------------------------
#AUTOSTART
# -----------------------------------------------------

# Don't run fastfetch in VSCode integrated terminal
if [[ -z $VSCODE_INJECTION ]]; then
  fastfetch
fi
