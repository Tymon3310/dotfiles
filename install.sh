#!/usr/bin/env bash
# Dotfiles installer
#
#   ./install.sh                     run every step
#   ./install.sh --only agents       run just the named steps (comma-separated)
#   ./install.sh --skip packages     run everything except the named steps
#   ./install.sh --help
#
# Every step is safe to re-run: it only changes what is missing or different.
# Anything a link would replace is moved to ~/.dotfiles_backup/<timestamp>/.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$DOTFILES_DIR/packages"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Order matters: links before zsh (zsh needs the linked .zshrc kept).
ALL_STEPS=(pacman yay packages links zsh shell agents)

declare -A STEP_INFO=(
    [pacman]="pacman.conf: colour, parallel downloads, ILoveCandy"
    [yay]="install the yay AUR helper if missing"
    [packages]="install / update everything listed in ./packages"
    [links]="symlink .config/* and the root dotfiles into \$HOME"
    [zsh]="install / update Oh My Zsh and its plugins"
    [shell]="make zsh the login shell"
    [agents]="Claude Code hooks + OpenCode plugin for the island's agent status"
)


if [[ -t 1 ]]; then
    GREEN=$'\e[0;32m' BLUE=$'\e[0;34m' YELLOW=$'\e[1;33m' RED=$'\e[0;31m' BOLD=$'\e[1m' NC=$'\e[0m'
else
    GREEN="" BLUE="" YELLOW="" RED="" BOLD="" NC=""
fi

WARNINGS=()
step() { printf '\n%s==>%s %s%s%s\n' "$BLUE" "$NC" "$BOLD" "$1" "$NC"; }
ok()   { printf '%s[✓]%s %s\n' "$GREEN" "$NC" "$1"; }
warn() { printf '%s[!]%s %s\n' "$YELLOW" "$NC" "$1"; WARNINGS+=("$1"); }
die()  { printf '%s[✗]%s %s\n' "$RED" "$NC" "$1" >&2; exit 1; }

usage() {
    printf 'Usage: %s [--only STEPS] [--skip STEPS]\n\nSteps (run in this order):\n' "$0"
    for s in "${ALL_STEPS[@]}"; do printf '  %-9s %s\n' "$s" "${STEP_INFO[$s]}"; done
    printf '\nSTEPS is a comma-separated list, e.g. --only links,agents\n'
}


ONLY="" SKIP=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --only) ONLY="${2:-}"; shift 2 ;;
        --only=*) ONLY="${1#*=}"; shift ;;
        --skip) SKIP="${2:-}"; shift 2 ;;
        --skip=*) SKIP="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown option: $1" ;;
    esac
done

for s in ${ONLY//,/ } ${SKIP//,/ }; do
    [[ -n "${STEP_INFO[$s]:-}" ]] || die "Unknown step: $s (see --help)"
done

wanted() {
    local s="$1"
    if [[ -n "$ONLY" ]]; then [[ ",$ONLY," == *",$s,"* ]]; return; fi
    [[ ",$SKIP," != *",$s,"* ]]
}

[[ $EUID -ne 0 ]] || die "Run this as your normal user; sudo is asked for when needed."


SUDO_KEEPALIVE=""
need_sudo() {
    if [[ -n "$SUDO_KEEPALIVE" ]]; then return; fi
    sudo -v || die "sudo is needed for this step."
    # Keep the ticket fresh through long package installs.
    while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
    SUDO_KEEPALIVE=$!
}
trap '[[ -n "$SUDO_KEEPALIVE" ]] && kill "$SUDO_KEEPALIVE" 2>/dev/null; true' EXIT

is_arch() { command -v pacman >/dev/null 2>&1; }


step_pacman() {
    is_arch || { warn "pacman not found, skipping pacman.conf"; return; }
    need_sudo
    sudo sed -i -E '
        s/^#?\s*(Color)$/\1/;
        s/^#?\s*(VerbosePkgLists)$/\1/;
        s/^#?\s*(ParallelDownloads)\s*=.*/\1 = 10/
    ' /etc/pacman.conf
    grep -q '^ParallelDownloads' /etc/pacman.conf || sudo sed -i '/^\[options\]/a ParallelDownloads = 10' /etc/pacman.conf
    grep -q '^ILoveCandy' /etc/pacman.conf || sudo sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
    ok "pacman.conf configured"
}

step_yay() {
    is_arch || { warn "pacman not found, skipping yay"; return; }
    if command -v yay >/dev/null 2>&1; then ok "yay already installed"; return; fi
    need_sudo
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "yay installed"
}

step_packages() {
    is_arch || { warn "pacman not found, skipping packages"; return; }
    command -v yay >/dev/null 2>&1 || { warn "yay missing (run the yay step), skipping packages"; return; }
    [[ -f "$PACKAGES_FILE" ]] || { warn "No packages file at $PACKAGES_FILE"; return; }
    local pkgs
    mapfile -t pkgs < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$PACKAGES_FILE" | grep -v '^$')
    [[ ${#pkgs[@]} -gt 0 ]] || { ok "packages file is empty"; return; }
    need_sudo
    yay -Syu --needed --noconfirm "${pkgs[@]}"
    ok "${#pkgs[@]} packages installed / up to date"
}

LINKED=0
link() {
    local src="$1" dst="$2"
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        return
    fi
    if [[ -e "$dst" || -L "$dst" ]]; then
        local rel="${dst#"$HOME"/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        mv "$dst" "$BACKUP_DIR/$rel"
        warn "Moved existing ~/$rel to $BACKUP_DIR/$rel"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    LINKED=$((LINKED + 1))
    ok "~/${dst#"$HOME"/} -> ${src#"$DOTFILES_DIR"/}"
}

step_links() {
    local item file
    for item in "$DOTFILES_DIR/.config"/*; do
        if [[ -e "$item" ]]; then link "$item" "$HOME/.config/$(basename "$item")"; fi
    done
    for file in .zshrc .bashrc .tmux.conf .tmux.conf.local .gtkrc-2.0 .Xresources; do
        if [[ -f "$DOTFILES_DIR/$file" ]]; then link "$DOTFILES_DIR/$file" "$HOME/$file"; fi
    done
    if [[ -f "$DOTFILES_DIR/.config/vim/vimrc" ]]; then
        link "$DOTFILES_DIR/.config/vim/vimrc" "$HOME/.vimrc"
    fi
    if [[ $LINKED -eq 0 ]]; then ok "all links already in place"; else ok "$LINKED links created"; fi
}

step_zsh() {
    command -v git >/dev/null 2>&1 || { warn "git not found, skipping Oh My Zsh"; return; }
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            "" --unattended --keep-zshrc
        ok "Oh My Zsh installed"
    else
        git -C "$HOME/.oh-my-zsh" pull --quiet --ff-only || warn "Could not update Oh My Zsh"
        ok "Oh My Zsh up to date"
    fi

    declare -A plugins=(
        [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions.git"
        [fast-syntax-highlighting]="https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
        [zsh-autocomplete]="https://github.com/marlonrichert/zsh-autocomplete.git"
    )
    mkdir -p "$ZSH_CUSTOM/plugins"
    local name target
    for name in "${!plugins[@]}"; do
        target="$ZSH_CUSTOM/plugins/$name"
        if [[ -d "$target/.git" ]]; then
            git -C "$target" pull --quiet --ff-only || warn "Could not update $name"
        else
            git clone --quiet --depth=1 "${plugins[$name]}" "$target"
        fi
        ok "$name"
    done
}

step_shell() {
    local zsh_bin current
    zsh_bin="$(command -v zsh || true)"
    [[ -n "$zsh_bin" ]] || { warn "zsh not installed, not changing the login shell"; return; }
    current="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current" == "$zsh_bin" ]]; then ok "zsh is already the login shell"; return; fi
    chsh -s "$zsh_bin" || { need_sudo; sudo chsh -s "$zsh_bin" "$USER"; } \
        || { warn "Could not change the shell; run: chsh -s $zsh_bin"; return; }
    ok "login shell set to $zsh_bin"
}

# Claude Code and OpenCode report each session's state for the island's agent
# indicator: Claude through hooks (parts/scripts/claude_status.sh), OpenCode
# through a TUI plugin (parts/scripts/opencode-agent-status/), which also lets
# the island switch an OpenCode window to the clicked session's tab.
step_agents() {
    agents_opencode
    agents_claude
}

agents_opencode() {
    if ! command -v opencode >/dev/null 2>&1 && [[ ! -d "$HOME/.config/opencode" ]]; then
        ok "OpenCode not installed, no plugin needed"
        return
    fi
    # Just the plugin folder: ~/.config/opencode also holds credentials, so
    # the folder itself is not part of the dotfiles. OpenCode v2 loads only
    # folders from plugins/; drop the old single-file plugin it would reject.
    rm -f "$HOME/.config/opencode/plugins/agent-status.js"
    link "$DOTFILES_DIR/.config/quickshell/parts/scripts/opencode-agent-status" \
         "$HOME/.config/opencode/plugins/agent-status"
    ok "OpenCode status plugin linked (restart OpenCode windows to load it)"
}

agents_claude() {
    command -v jq >/dev/null 2>&1 || { warn "jq not installed, skipping Claude Code hooks"; return; }
    local hook="~/.config/quickshell/parts/scripts/claude_status.sh"
    local events='{
        "UserPromptSubmit": "working",
        "PreToolUse": "working",
        "PostToolUse": "working",
        "PermissionRequest": "waiting",
        "Notification": "waiting",
        "Stop": "done",
        "StopFailure": "error",
        "SessionEnd": "end"
    }'

    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    local current='{}'
    if [[ -s "$CLAUDE_SETTINGS" ]]; then
        current="$(cat "$CLAUDE_SETTINGS")"
        jq empty <<<"$current" 2>/dev/null || { warn "$CLAUDE_SETTINGS is not valid JSON, left alone"; return; }
    fi

    # Add each hook unless that event already runs the same command; every
    # other setting and hook is kept as it is.
    local updated
    updated="$(jq --arg hook "$hook" --argjson events "$events" '
        .hooks = (.hooks // {})
        | reduce ($events | to_entries[]) as $e (.;
            ($hook + " " + $e.value) as $cmd
            | if any(.hooks[$e.key][]?.hooks[]?; .command == $cmd) then .
              else .hooks[$e.key] = ((.hooks[$e.key] // [])
                   + [{hooks: [{type: "command", command: $cmd, timeout: 5}]}])
              end)
    ' <<<"$current")"

    if [[ "$(jq -S . <<<"$current")" == "$(jq -S . <<<"$updated")" ]]; then
        ok "Claude Code hooks already in place"
        return
    fi
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        mkdir -p "$BACKUP_DIR/.claude"
        cp "$CLAUDE_SETTINGS" "$BACKUP_DIR/.claude/settings.json"
    fi
    local tmp; tmp="$(mktemp "$CLAUDE_SETTINGS.XXXXXX")"
    jq . <<<"$updated" >"$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
    ok "Claude Code hooks added (restart open sessions to pick them up)"
}


RAN=()
for s in "${ALL_STEPS[@]}"; do
    wanted "$s" || continue
    step "$s: ${STEP_INFO[$s]}"
    "step_$s"
    RAN+=("$s")
done

[[ ${#RAN[@]} -gt 0 ]] || die "No steps selected."

printf '\n%s==> Done:%s %s\n' "$GREEN" "$NC" "${RAN[*]}"
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    printf '%s%d warning(s):%s\n' "$YELLOW" "${#WARNINGS[@]}" "$NC"
    printf '  - %s\n' "${WARNINGS[@]}"
fi
if [[ -d "$BACKUP_DIR" ]]; then
    printf 'Replaced files were backed up to %s\n' "$BACKUP_DIR"
fi
