# dotfiles

Personal dotfiles for Arch Linux (Hyprland + Quickshell). Tested on an all-AMD system (CPU & GPU).

Looking for NixOS? Check out my (WIP) [flakes.nix](https://github.com/tymon3310/flakes.nix).

![showcase](https://github.com/user-attachments/assets/eb968fa3-8b55-4cac-b497-8034809f8776)

## Components

- **WM:** [Hyprland](https://hyprland.org/) (Lua)
- **Bar & Overlays:** [Quickshell](https://quickshell.outfoxxed.me/) (QML)
- **Terminal:** Kitty
- **Shell:** Zsh + Oh My Zsh + Oh-My-Posh
- **Launcher & Clipboard:** Vicinae
- **Display Manager:** SDDM (custom *Impasto* theme with biopass face unlock)
- **File Manager:** Dolphin (GUI) / Yazi (TUI)
- **Editor:** Neovim

## Installation

Clone and run the installer as your regular user (not root):

```bash
git clone https://github.com/Tymon3310/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

The script will:
1. Configure `/etc/pacman.conf` (parallel downloads, color, ILoveCandy)
2. Install `yay` (if missing) and all packages from `./packages`
3. Back up existing configs to `~/.dotfiles_backup/<timestamp>` and create symlinks
4. Install Oh My Zsh, plugins, and set Zsh as default shell

### SDDM & Face Unlock (Optional)

To apply the custom Impasto SDDM theme, camera face unlock (`biopass`), and the UEFI reboot helper:

```bash
sudo ./install_sddm.sh
```

- Test the greeter: `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/impasto`
- Revert back anytime: `sudo ./system_backups/restore_sddm_backup.sh`

## Keybinds

Modifier: `SUPER` (Windows key)

- `SUPER + Return` — Terminal (Kitty)
- `SUPER + Space` — Launcher (Vicinae)
- `SUPER + B` — Browser (Zen)
- `SUPER + E` — File manager (Dolphin)
- `SUPER + V` — Clipboard history
- `SUPER + Q` — Close window
- `SUPER + Shift + Q` — Kill window
- `SUPER + F` — Toggle fullscreen
- `SUPER + T` — Toggle floating
- `SUPER + Shift + S` / `Print` — Screenshot (Quickshell)
- `SUPER + L` — Lock screen
- `SUPER + 1-9, 0` — Workspaces (per-monitor)