# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi



# -----------------------------------------------------
#OH-MY-ZSH
# -----------------------------------------------------

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=xiong-chiamiov-plus
# ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
    aliases
    git gh 
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
    fzf
    pip python
 

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

fastfetch -c groups
# fastfetch -c arch

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

# -----------------------------------------------------
#aliases
# -----------------------------------------------------

source ~/.config/zshrc/aliases

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
