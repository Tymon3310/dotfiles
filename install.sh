#!/usr/bin/env bash
# ==============================================================================
# Dotfiles Installation & Setup Script
# ==============================================================================

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="${DOTFILES_DIR}/packages"
BACKUP_DIR="${HOME}/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

msg() { echo -e "${BLUE}==>${NC} $1"; }
ok()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn(){ echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1" >&2; }

if [ "$EUID" -eq 0 ]; then
    err "Please run this script as a normal user, not root. Sudo will be prompted when needed."
    exit 1
fi

# Request sudo upfront
sudo -v

# 1. Configure pacman
if [ -f /etc/pacman.conf ]; then
    msg "Configuring /etc/pacman.conf..."
    sudo sed -i -E '
        s/^#?\s*(Color)$/\1/;
        s/^#?\s*(VerbosePkgLists)$/\1/;
        s/^#?\s*(ParallelDownloads)\s*=.*/\1 = 10/
    ' /etc/pacman.conf
    grep -q "^ParallelDownloads" /etc/pacman.conf || sudo sed -i '/^\[options\]/a ParallelDownloads = 10' /etc/pacman.conf
    grep -q "^ILoveCandy" /etc/pacman.conf || sudo sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
    ok "Pacman configured."
fi

# 2. Check / install yay (AUR helper)
if ! command -v yay &>/dev/null; then
    msg "Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "yay installed."
else
    ok "yay is already installed."
fi

# 3. Install & update packages
if [ -f "$PACKAGES_FILE" ]; then
    msg "Installing and updating packages from $PACKAGES_FILE..."
    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$PACKAGES_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [ ${#pkgs[@]} -gt 0 ]; then
        yay -Syu --needed --noconfirm "${pkgs[@]}"
        ok "Packages up to date."
    fi
else
    warn "Package file not found at $PACKAGES_FILE, skipping package installation."
fi

# 4. Symlink dotfiles
msg "Symlinking dotfiles..."
link_file() {
    local src="$1"
    local dst="$2"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$(readlink -f "$dst")" = "$src" ]; then
            return
        fi
        local rel="${dst#$HOME/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        mv "$dst" "$BACKUP_DIR/$rel"
        warn "Existing file backed up to $BACKUP_DIR/$rel"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    ok "Linked $dst -> $src"
}

# Symlink .config subdirectories
for item in "$DOTFILES_DIR/.config"/*; do
    [ -e "$item" ] || continue
    link_file "$item" "$HOME/.config/$(basename "$item")"
done

# Symlink root dotfiles
for file in .zshrc .bashrc .tmux.conf .tmux.conf.local .gtkrc-2.0 .Xresources; do
    [ -f "$DOTFILES_DIR/$file" ] || continue
    link_file "$DOTFILES_DIR/$file" "$HOME/$file"
done

# 5. Install / update Oh My Zsh and plugins (official online method)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    msg "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    ok "Oh My Zsh installed."
else
    msg "Updating Oh My Zsh..."
    git -C "$HOME/.oh-my-zsh" pull --quiet || true
    ok "Oh My Zsh up to date."
fi

msg "Installing / updating Zsh custom plugins..."
mkdir -p "$ZSH_CUSTOM/plugins"
declare -A PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    ["fast-syntax-highlighting"]="https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
    ["zsh-autocomplete"]="https://github.com/marlonrichert/zsh-autocomplete.git"
)

for plugin in "${!PLUGINS[@]}"; do
    target="$ZSH_CUSTOM/plugins/$plugin"
    if [ ! -d "$target" ]; then
        msg "Cloning $plugin..."
        git clone --depth=1 "${PLUGINS[$plugin]}" "$target"
        ok "Installed $plugin"
    else
        git -C "$target" pull --quiet || true
        ok "Updated $plugin"
    fi
done

# 6. Set default shell to zsh
zsh_bin="$(command -v zsh || echo "/bin/zsh")"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$current_shell" != "$zsh_bin" ]; then
    msg "Setting default shell to $zsh_bin..."
    chsh -s "$zsh_bin" || sudo chsh -s "$zsh_bin" "$USER" || warn "Could not set default shell automatically. Run: chsh -s $zsh_bin"
    ok "Default shell set to $zsh_bin."
else
    ok "Zsh is already the default shell."
fi

echo -e "\n${GREEN}==> Dotfiles setup completed successfully!${NC}\n"
