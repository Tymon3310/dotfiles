alias c='clear'
alias ls='lsd'
alias ll='lsd -la'
alias lt='lsd --tree --ignore-glob .venv'
alias vi='$EDITOR'
alias vim='$EDITOR'
alias icat='kitten icat'
alias matrix='unimatrix -a -f -s 95'
alias shutdown='systemctl poweroff'

alias update='python3 ~/.config/hypr/scripts/update.py'
alias pacunl='sh ~/.config/hypr/scripts/unlock-pacman.sh'

alias venvon='_makevenv'
alias venvoff='deactivate'
alias vsc='code-insiders'
alias code='code-insiders'

hyexec() {
    [[ $# -gt 0 ]] || return 0
    local cmd="$*"
    cmd=${cmd//\\/\\\\}
    cmd=${cmd//\"/\\\"}
    hyprctl eval "hl.dispatch(hl.dsp.exec_cmd(\"$cmd\"))"
}
