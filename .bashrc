# Do nothing for non-interactive shells (scp, scripts, ...)
[[ $- != *i* ]] && return

# -----------------------------------------------------
# Exports
# -----------------------------------------------------
export EDITOR=nvim
export PATH="/usr/lib/ccache/bin/:$PATH"

eval "$(oh-my-posh init bash --config ~/.config/ohmyposh/kushal.omp.json)"

fastfetch -c arch

echo "YOU ARE IN BASH, TYPE ZSH FOR MORE FULL FEATURED SHELL"

# -----------------------------------------------------
#aliases
# -----------------------------------------------------

[ -f ~/.config/zshrc/aliases.zsh ] && source ~/.config/zshrc/aliases.zsh
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

# terminal-wakatime setup
export PATH="$HOME/.wakatime:$PATH"
eval "$(terminal-wakatime init)"

if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty 2>/dev/null)" = "/dev/tty8" ]; then
	exec start-hyprland
fi
