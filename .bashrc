[[ $- != *i* ]] && return

export EDITOR=nvim
export PATH="/usr/lib/ccache/bin/:$PATH"

eval "$(oh-my-posh init bash --config ~/.config/ohmyposh/kushal.omp.json)"

fastfetch -c ~/.config/fastfetch/arch

echo "YOU ARE IN BASH, TYPE ZSH FOR MORE FULL FEATURED SHELL"


[ -f ~/.config/zshrc/aliases.zsh ] && source ~/.config/zshrc/aliases.zsh
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"


export PATH="$HOME/.local/bin:$HOME/.wakatime:$PATH"
command -v terminal-wakatime >/dev/null 2>&1 && eval "$(terminal-wakatime init)"
