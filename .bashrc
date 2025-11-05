# -----------------------------------------------------
# Exports
# -----------------------------------------------------
export EDITOR=nvim
export PATH="/usr/lib/ccache/bin/:$PATH"

eval "$(oh-my-posh init bash --config ~/.config/ohmyposh/kushal.omp.json)"

fastfetch -c arch

echo "YOU ARE IN BASH, TYPE FISH (or) ZSH FOR MORE FULL FEATURED SHELL"

# -----------------------------------------------------
#aliases
# -----------------------------------------------------

source ~/.config/zshrc/aliases.zsh
source "$HOME/.cargo/env"
