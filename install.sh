#!/usr/bin/env bash
# ==============================================================================
# Dotfiles Installation & Configuration Script
# ==============================================================================
# 0. Check / Install yay (AUR helper)
# 1. Backup existing configurations
# 2. Install packages from 'install' file
# 3. Symlink all folders from .config, plus .zshrc and .bashrc
# 4. Setup pacman (10 parallel downloads, Color, VerbosePkgLists, ILoveCandy)
# 5. Setup Zsh (Oh-My-Zsh, plugins, default shell)
# 6. Verification & Health Check
# ==============================================================================

set -eo pipefail

# ------------------------------------------------------------------------------
# Colors & Helpers
# ------------------------------------------------------------------------------
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_RED="\033[1;31m"
CLR_GREEN="\033[1;32m"
CLR_YELLOW="\033[1;33m"
CLR_BLUE="\033[1;34m"
CLR_CYAN="\033[1;36m"

print_header() {
    echo -e "\n${CLR_BLUE}==============================================================================${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}  $1${CLR_RESET}"
    echo -e "${CLR_BLUE}==============================================================================${CLR_RESET}\n"
}

print_info() {
    echo -e "${CLR_CYAN}[i]${CLR_RESET} $1"
}

print_success() {
    echo -e "${CLR_GREEN}[✓]${CLR_RESET} $1"
}

print_warning() {
    echo -e "${CLR_YELLOW}[!]${CLR_RESET} $1"
}

print_error() {
    echo -e "${CLR_RED}[✗]${CLR_RESET} $1"
}

# ------------------------------------------------------------------------------
# Paths & Variables
# ------------------------------------------------------------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="${DOTFILES_DIR}/install"
BACKUP_DIR="${HOME}/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
ZSH_CUSTOM_DIR="${HOME}/.oh-my-zsh/custom"

# Ensure script is not run directly as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root / with sudo. Sudo privileges will be requested when needed."
    exit 1
fi

# Ask for sudo upfront and keep-alive
print_info "Requesting sudo permissions for system setup..."
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# ------------------------------------------------------------------------------
# Step 0: Ensure yay (AUR helper) is installed
# ------------------------------------------------------------------------------
print_header "Step 0: Checking AUR Helper (yay)"

if command -v yay &>/dev/null; then
    print_success "yay is already installed: $(yay --version | head -n 1)"
else
    print_info "yay is not installed. Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git

    TMP_YAY_DIR="$(mktemp -d)"
    print_info "Cloning yay into temporary directory: ${TMP_YAY_DIR}..."
    git clone https://aur.archlinux.org/yay.git "${TMP_YAY_DIR}/yay"
    
    (
        cd "${TMP_YAY_DIR}/yay"
        makepkg -si --noconfirm
    )
    
    rm -rf "${TMP_YAY_DIR}"

    if command -v yay &>/dev/null; then
        print_success "yay installed successfully!"
    else
        print_error "Failed to install yay. Exiting."
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# Step 1: Backup Existing Configurations
# ------------------------------------------------------------------------------
print_header "Step 1: Backing up Existing Configurations"

mkdir -p "${BACKUP_DIR}/.config"
backup_count=0

# Backup shell configuration files
for rcfile in .zshrc .bashrc .tmux.conf .gtkrc-2.0 .Xresources; do
    target="${HOME}/${rcfile}"
    if [ -e "${target}" ] || [ -L "${target}" ]; then
        print_info "Backing up ${target} -> ${BACKUP_DIR}/${rcfile}"
        mv "${target}" "${BACKUP_DIR}/${rcfile}"
        ((backup_count++))
    fi
done

# Backup .config directories matching dotfiles .config
if [ -d "${DOTFILES_DIR}/.config" ]; then
    for item in "${DOTFILES_DIR}/.config"/*; do
        [ -e "${item}" ] || continue
        name="$(basename "${item}")"
        target="${HOME}/.config/${name}"
        if [ -e "${target}" ] || [ -L "${target}" ]; then
            print_info "Backing up ${target} -> ${BACKUP_DIR}/.config/${name}"
            mv "${target}" "${BACKUP_DIR}/.config/${name}"
            ((backup_count++))
        fi
    done
fi

if [ "${backup_count}" -gt 0 ]; then
    print_success "Backed up ${backup_count} item(s) to ${BACKUP_DIR}"
else
    print_info "No conflicting configuration files found to backup."
    rm -rf "${BACKUP_DIR}"
fi

# ------------------------------------------------------------------------------
# Step 2: Install Packages from 'install' file
# ------------------------------------------------------------------------------
print_header "Step 2: Installing Packages"

if [ -f "${PACKAGES_FILE}" ]; then
    # Read packages, stripping comments and blank lines
    mapfile -t PACKAGES < <(grep -v '^[[:space:]]*#' "${PACKAGES_FILE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$')
    
    print_info "Found ${#PACKAGES[@]} packages listed in ${PACKAGES_FILE}."
    
    # Update system package database first
    yay -Sy

    # Install packages
    print_info "Installing packages via yay..."
    if yay -S --needed --noconfirm "${PACKAGES[@]}"; then
        print_success "All packages installed or already up to date!"
    else
        print_warning "Some packages may have failed to install. Continuing with setup..."
    fi
else
    print_error "Package list file '${PACKAGES_FILE}' not found. Skipping package installation."
fi

# ------------------------------------------------------------------------------
# Step 3: Symlink Configurations
# ------------------------------------------------------------------------------
print_header "Step 3: Creating Symlinks"

mkdir -p "${HOME}/.config"

# Symlink .config subdirectories
if [ -d "${DOTFILES_DIR}/.config" ]; then
    for item in "${DOTFILES_DIR}/.config"/*; do
        [ -e "${item}" ] || continue
        name="$(basename "${item}")"
        target="${HOME}/.config/${name}"
        
        # Ensure any leftover file/directory at target is removed before linking
        rm -rf "${target}"
        ln -sfn "${item}" "${target}"
        print_success "Symlinked: ${target} -> ${item}"
    done
fi

# Symlink individual dotfiles
for file in .zshrc .bashrc; do
    src="${DOTFILES_DIR}/${file}"
    target="${HOME}/${file}"
    if [ -f "${src}" ]; then
        rm -f "${target}"
        ln -sf "${src}" "${target}"
        print_success "Symlinked: ${target} -> ${src}"
    fi
done

# ------------------------------------------------------------------------------
# Step 4: Configure Pacman (Parallel = 10, Color, VerbosePkgLists, ILoveCandy)
# ------------------------------------------------------------------------------
print_header "Step 4: Configuring Pacman (/etc/pacman.conf)"

PACMAN_CONF="/etc/pacman.conf"

if [ -f "${PACMAN_CONF}" ]; then
    print_info "Updating ${PACMAN_CONF}..."

    # Enable Color
    sudo sed -i 's/^#\?Color/Color/' "${PACMAN_CONF}"
    
    # Enable VerbosePkgLists
    sudo sed -i 's/^#\?VerbosePkgLists/VerbosePkgLists/' "${PACMAN_CONF}"
    
    # Set ParallelDownloads = 10
    if grep -q "^#\?ParallelDownloads" "${PACMAN_CONF}"; then
        sudo sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 10/' "${PACMAN_CONF}"
    else
        # If ParallelDownloads is not present, add it under [options]
        sudo sed -i '/^\[options\]/a ParallelDownloads = 10' "${PACMAN_CONF}"
    fi

    # Add ILoveCandy under Color if not already present
    if ! grep -q "^ILoveCandy" "${PACMAN_CONF}"; then
        sudo sed -i '/^Color/a ILoveCandy' "${PACMAN_CONF}"
    fi

    print_success "Pacman configured with: Color, VerbosePkgLists, ParallelDownloads = 10, ILoveCandy"
else
    print_error "${PACMAN_CONF} not found!"
fi

# ------------------------------------------------------------------------------
# Step 5: Setup Zsh
# ------------------------------------------------------------------------------
print_header "Step 5: Setting Up Zsh"

# 1. Install Oh-My-Zsh if not already present
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    print_info "Installing Oh-My-Zsh..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "${HOME}/.oh-my-zsh"
    print_success "Oh-My-Zsh installed."
else
    print_success "Oh-My-Zsh is already installed."
fi

# 2. Install Zsh Custom Plugins
mkdir -p "${ZSH_CUSTOM_DIR}/plugins"

declare -A PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    ["fast-syntax-highlighting"]="https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
    ["zsh-autocomplete"]="https://github.com/marlonrichert/zsh-autocomplete.git"
)

for plugin in "${!PLUGINS[@]}"; do
    plugin_path="${ZSH_CUSTOM_DIR}/plugins/${plugin}"
    if [ ! -d "${plugin_path}" ]; then
        print_info "Cloning plugin: ${plugin}..."
        git clone --depth=1 "${PLUGINS[$plugin]}" "${plugin_path}"
        print_success "Installed plugin: ${plugin}"
    else
        print_success "Plugin already present: ${plugin}"
    fi
done

# 3. Set Zsh as default shell
ZSH_BIN="$(command -v zsh || which zsh || echo "/bin/zsh")"
CURRENT_SHELL="$(getent passwd "${USER}" | cut -d: -f7)"

if [ "${CURRENT_SHELL}" != "${ZSH_BIN}" ]; then
    print_info "Changing default shell to ${ZSH_BIN}..."
    if sudo chsh -s "${ZSH_BIN}" "${USER}"; then
        print_success "Default shell changed to ${ZSH_BIN}."
    else
        print_warning "Could not change default shell automatically. Please run 'chsh -s ${ZSH_BIN}' manually."
    fi
else
    print_success "Zsh is already the default shell (${CURRENT_SHELL})."
fi

# ------------------------------------------------------------------------------
# Step 6: Verification & Health Check
# ------------------------------------------------------------------------------
print_header "Step 6: Verification & Health Check"

total_checks=0
passed_checks=0

check_status() {
    local label="$1"
    local condition="$2"
    ((total_checks++))
    if eval "${condition}"; then
        print_success "${label}"
        ((passed_checks++))
    else
        print_error "${label}"
    fi
}

echo -e "${CLR_BOLD}Checking Core Dependencies:${CLR_RESET}"
check_status "AUR Helper (yay) installed" "command -v yay &>/dev/null"
check_status "Zsh shell binary installed" "command -v zsh &>/dev/null"
check_status "Oh-My-Zsh directory exists" "[ -d '${HOME}/.oh-my-zsh' ]"

echo -e "\n${CLR_BOLD}Checking Zsh Plugins:${CLR_RESET}"
for plugin in "${!PLUGINS[@]}"; do
    check_status "Plugin '${plugin}' installed" "[ -d '${ZSH_CUSTOM_DIR}/plugins/${plugin}' ]"
done

echo -e "\n${CLR_BOLD}Checking Symlinks:${CLR_RESET}"
check_status "~/.zshrc symlink points to dotfiles" "[ -L '${HOME}/.zshrc' ] && [ '$(readlink -f "${HOME}/.zshrc")' = '${DOTFILES_DIR}/.zshrc' ]"
check_status "~/.bashrc symlink points to dotfiles" "[ -L '${HOME}/.bashrc' ] && [ '$(readlink -f "${HOME}/.bashrc")' = '${DOTFILES_DIR}/.bashrc' ]"

if [ -d "${DOTFILES_DIR}/.config" ]; then
    for item in "${DOTFILES_DIR}/.config"/*; do
        [ -e "${item}" ] || continue
        name="$(basename "${item}")"
        target="${HOME}/.config/${name}"
        check_status "~/.config/${name} symlink valid" "[ -L '${target}' ] && [ '$(readlink -f "${target}")' = '${item}' ]"
    done
fi

echo -e "\n${CLR_BOLD}Checking Pacman Configuration (/etc/pacman.conf):${CLR_RESET}"
check_status "ParallelDownloads = 10 set" "grep -q '^ParallelDownloads = 10' '${PACMAN_CONF}'"
check_status "Color option enabled" "grep -q '^Color' '${PACMAN_CONF}'"
check_status "VerbosePkgLists enabled" "grep -q '^VerbosePkgLists' '${PACMAN_CONF}'"
check_status "ILoveCandy enabled" "grep -q '^ILoveCandy' '${PACMAN_CONF}'"

echo -e "\n${CLR_BOLD}Checking Package Installation Progress:${CLR_RESET}"
if [ -f "${PACKAGES_FILE}" ]; then
    missing_pkgs=()
    for pkg in "${PACKAGES[@]}"; do
        if ! pacman -Q "${pkg}" &>/dev/null; then
            missing_pkgs+=("${pkg}")
        fi
    done

    installed_count=$(( ${#PACKAGES[@]} - ${#missing_pkgs[@]} ))
    print_info "${installed_count}/${#PACKAGES[@]} packages from install file are currently installed on the system."
    if [ ${#missing_pkgs[@]} -eq 0 ]; then
        print_success "All packages from '${PACKAGES_FILE}' are installed!"
    else
        print_warning "${#missing_pkgs[@]} packages are not currently installed: ${missing_pkgs[*]:0:10}$([ ${#missing_pkgs[@]} -gt 10 ] && echo '...')"
    fi
fi

# ------------------------------------------------------------------------------
# Final Summary
# ------------------------------------------------------------------------------
print_header "Installation Summary"
echo -e "Checks Passed: ${CLR_BOLD}${passed_checks}/${total_checks}${CLR_RESET}"

if [ "${passed_checks}" -eq "${total_checks}" ]; then
    echo -e "\n${CLR_GREEN}${CLR_BOLD}✨ Installation & Configuration completed successfully! ✨${CLR_RESET}"
    echo -e "You can now start a new terminal session or run ${CLR_CYAN}zsh${CLR_RESET} to enjoy your setup.\n"
else
    echo -e "\n${CLR_YELLOW}${CLR_BOLD}⚠️  Installation completed with some warnings/checks failing. Review the logs above. ⚠️${CLR_RESET}\n"
fi
