if status is-interactive
    # -----------------------------------------------------
    # LOADING EXTERNAL FILES
    # -----------------------------------------------------

    # Load functions from separate file
    source ~/.config/fish/functions.fish

    # Load abbreviations and aliases from separate file
    source ~/.config/fish/aliases.fish

    # -----------------------------------------------------
    # AUTOSTART
    # -----------------------------------------------------

    fastfetch -c ~/.config/fastfetch/config-full
    # -----------------------------------------------------
    # SETTINGS
    # -----------------------------------------------------

    set -g fish_history_path ~/.local/share/fish/fish_history
    set -g fish_history_max_age 3650

    set -gx GREP_OPTIONS "--color=auto"

    set -g async_prompt_functions _tide_item_git

    # FZF settings
    set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border --inline-info"
    set -gx FZF_DEFAULT_COMMAND "fd --type f --hidden --follow --exclude .git"
    set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
    set -gx FZF_ALT_C_COMMAND "fd --type d --hidden --follow --exclude .git"

    # -----------------------------------------------------
    # EXPORTS
    # -----------------------------------------------------

    # Private exports
    source ~/.env

    # Editor
    set -gx EDITOR nvim

    # PATH modifications
    fish_add_path /usr/lib/ccache/bin/
    fish_add_path $HOME/.local/bin

    # SSH agent
    set -gx SSH_AUTH_SOCK ~/.bitwarden-ssh-agent.sock

    # Node.js setup
    set -gx PNPM_HOME "$HOME/.local/share/pnpm"
    fish_add_path $PNPM_HOME

    # NVM setup
    set -gx NVM_DIR "$HOME/.nvm"

    # Golang environment
    set -gx GOROOT /usr/local/go
    set -gx GOPATH $HOME/go
    fish_add_path $GOPATH/bin $GOROOT/bin

    # Spicetify
    fish_add_path $HOME/.spicetify

    # LM Studio
    fish_add_path $HOME/.lmstudio/bin

    # TheFuck
    if command -v thefuck &>/dev/null
        thefuck --alias | source
    end

    # Enable fzf integration
    if command -v fzf &>/dev/null
        fzf_key_bindings
    end

    #VSCode
    string match -q "$TERM_PROGRAM" vscode
    and . (code-insiders --locate-shell-integration-path fish)
end
