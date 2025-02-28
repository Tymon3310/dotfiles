# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

if uwsm check may-start && uwsm select; then
	exec systemd-cat -t uwsm_start uwsm start default
fi

# -----------------------------------------------------
#OH-MY-ZSH
# -----------------------------------------------------

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=xiong-chiamiov-plus
# ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
    # Core functionality
    aliases
    sudo
    copyfile
    copybuffer
    # dirhistory
    
    # Development tools
    git
    gh
    vscode
    pip
    python
    
    # System tools
    archlinux
    web-search
    rbw
    
    # UI/UX improvements

    zsh-autosuggestions
    # zsh-autocomplete
    zsh-syntax-highlighting
    fast-syntax-highlighting
    fzf
)
source $ZSH/oh-my-zsh.sh

# Only source fzf if it exists
if command -v fzf &> /dev/null; then
    source <(fzf --zsh)
fi

# zsh history - improved settings
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt appendhistory
setopt inc_append_history  # Add commands as they are typed, don't wait until shell exit
setopt hist_expire_dups_first # Delete duplicates first when HISTFILE size exceeds HISTSIZE
# setopt hist_ignore_dups   # Don't record if same as previous command
setopt hist_find_no_dups  # Ignore duplicates when searching
setopt hist_reduce_blanks # Remove unnecessary blanks

# ZSH-specific optimizations
# Configure zsh-autosuggestions
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_USE_ASYNC=true

eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/kushal.omp.json)"

# -----------------------------------------------------
#AUTOSTART
# -----------------------------------------------------

fastfetch 

# -----------------------------------------------------
# Exports
# -----------------------------------------------------

#Private exports
source ~/.env

export EDITOR=nvim
# Optimize PATH exports
export PATH="/usr/lib/ccache/bin/:$HOME/.local/bin:$PATH"
export SSH_AUTH_SOCK=/home/tymon/.bitwarden-ssh-agent.sock

#nodejs
export PNPM_HOME="/home/tymon/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# python things
#pyenv
# export PYENV_ROOT="$HOME/.pyenv"
# [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
# eval "$(pyenv init -)"

# Golang environment variables
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin

# Update PATH to include GOPATH and GOROOT binaries
export PATH=$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$PATH

eval $(thefuck --alias)

export PATH=$PATH:/home/tymon/.spicetify
bindkey '^X' create_completion

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/tymon/.lmstudio/bin"

# -----------------------------------------------------
#aliases
# -----------------------------------------------------

source ~/.config/zshrc/aliases