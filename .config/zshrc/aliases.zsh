# -----------------------------------------------------
# ALIASES
# -----------------------------------------------------

# -----------------------------------------------------
# General
# -----------------------------------------------------
alias c='clear'
alias nf='fastfetch'
alias pf='fastfetch'
alias ff='fastfetch'
alias ls='lsd'
alias ll='lsd -la'
alias lt='lsd --tree --ignore-glob .venv'
alias shutdown='systemctl poweroff'
alias v='$EDITOR'
alias vi='$EDITOR'
alias vim='$EDITOR'
alias icat='kitten icat'
alias cat='bat'

# -----------------------------------------------------
# Git
# -----------------------------------------------------
alias gs="git status"
alias ga="git add"
# alias gaa="git add . && git commit -m"
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gst="git stash"
alias gsp="git stash; git pull"
alias gcheck="git checkout"
alias gcredential="git config credential.helper store"
alias gfo="git fetch origin"
alias guncommit='git reset --soft HEAD~1'



# -----------------------------------------------------
# Scripts
# -----------------------------------------------------
alias ascii='~/.config/hypr/scripts/ascii-text.sh'
alias matrix='unimatrix -a -f -s 95'

# -----------------------------------------------------
# System
# -----------------------------------------------------
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'


alias pacunl='sh ~/.config/hypr/scripts/unlock-pacman.sh'
alias dg='sudo downgrade'

alias update="python3 ~/.config/hypr/scripts/update.py"

# Dev aliases
alias 'venvon'='_makevenv'
alias 'venvoff'='deactivate'
alias 'vsc'='code-insiders'
alias 'code'='code-insiders'

alias 'hyexec'="hyprctl dispatch exec"