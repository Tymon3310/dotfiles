if status is-interactive
    # -----------------------------------------------------
    # AUTOSTART
    # -----------------------------------------------------

    fastfetch

    # -----------------------------------------------------
    # KEY BINDINGS
    # -----------------------------------------------------

    function fish_user_key_bindings
        bind --preset up history-search-backward
        bind --preset down history-search-forward
        bind --preset ctrl-e edit_command_buffer
        bind --preset ctrl-l "ls -la"
        bind --preset escape 'for cmd in sudo doas please; if command -q $cmd; fish_commandline_prepend $cmd; break; end; end'
    end
    
    # Enable fzf integration
    if command -v fzf &>/dev/null
        fzf_key_bindings
    end
    
    set -g async_prompt_functions _tide_item_git
    
    # -----------------------------------------------------
    # ABBREVIATIONS
    # -----------------------------------------------------

    # General
    abbr -a c 'clear'
    abbr -a nf 'fastfetch'
    abbr -a pf 'fastfetch'
    abbr -a ff 'fastfetch'
    abbr -a ls 'eza -a --icons'
    abbr -a ll 'eza -al --icons'
    abbr -a lt 'eza -a --tree --level=1 --icons'
    abbr -a sd 'systemctl poweroff'
    abbr -a v '$EDITOR'
    abbr -a vi '$EDITOR'
    abbr -a vim '$EDITOR'
    abbr -a icat 'kitten icat'
    abbr -a cat 'bat'
    
    # -----------------------------------------------------
    # CUSTOM CD COMMAND
    # -----------------------------------------------------
    
    function cd
        # Handle special patterns
        switch $argv[1]
            case '...'
                builtin cd ../..
            case '....'
                builtin cd ../../..
            case '.....'
                builtin cd ../../../..
            case '......'
                builtin cd ../../../../..
            case '*'
                builtin cd $argv
        end
    end
    
    # -----------------------------------------------------
    # GIT ABBREVIATIONS
    # -----------------------------------------------------

    abbr -a gs 'git status'
    abbr -a ga 'git add'
    abbr -a gc 'git commit -m'
    abbr -a gp 'git push'
    abbr -a gpl 'git pull'
    abbr -a gst 'git stash'
    abbr -a gsp 'git stash; git pull'
    abbr -a gcheck 'git checkout'
    abbr -a gcred 'git config credential.helper store'
    abbr -a gfo 'git fetch origin'
    abbr -a guncommit 'git reset --soft HEAD~1'
    
    function gaa
        git add .
        git commit -m "$argv"
        git push
    end
    
    # -----------------------------------------------------
    # SCRIPT ABBREVIATIONS
    # -----------------------------------------------------

    abbr -a ascii '~/.config/hypr/scripts/ascii-text.sh'
    abbr -a matrix 'unimatrix -a -f -s 95'
    
    # -----------------------------------------------------
    # SYSTEM ABBREVIATIONS
    # -----------------------------------------------------
    
    # System
    abbr -a update-grub 'sudo grub-mkconfig -o /boot/grub/grub.cfg'
    abbr -a pacunl 'sh ~/.config/hypr/scripts/unlock-pacman.sh'
    abbr -a dg 'sudo downgrade'
    
    
    # Pacman
    abbr -a pacupg 'sudo pacman -Syu'
    abbr -a pacin 'sudo pacman -S'
    abbr -a paclean 'sudo pacman -Sc'
    abbr -a pacins 'sudo pacman -U'
    abbr -a paclr 'sudo pacman -Scc'
    abbr -a pacre 'sudo pacman -R'
    abbr -a pacrem 'sudo pacman -Rns'
    abbr -a pacrep 'pacman -Si'
    abbr -a pacreps 'pacman -Ss'
    abbr -a pacloc 'pacman -Qi'
    abbr -a paclocs 'pacman -Qs'
    abbr -a pacinsd 'sudo pacman -S --asdeps'
    abbr -a pacmir 'sudo pacman -Syy'
    abbr -a paclsorphans 'sudo pacman -Qdt'
    abbr -a pacfileupg 'sudo pacman -Fy'
    abbr -a pacfiles 'pacman -F'
    abbr -a pacls 'pacman -Ql'
    abbr -a pacown 'pacman -Qo'
    abbr -a pacupd 'sudo pacman -Sy'
    
    function pacrmorphans
        sudo pacman -Rs (pacman -Qtdq)
    end
    
    
    # Yay
    if command -v yay &>/dev/null
        abbr -a yaconf 'yay -Pg'
        abbr -a yaclean 'yay -Sc'
        abbr -a yaclr 'yay -Scc'
        abbr -a yaupg 'yay -Syu'
        abbr -a yasu 'yay -Syu --noconfirm'
        abbr -a yain 'yay -S'
        abbr -a yains 'yay -U'
        abbr -a yare 'yay -R'
        abbr -a yarem 'yay -Rns'
        abbr -a yarep 'yay -Si'
        abbr -a yareps 'yay -Ss'
        abbr -a yaloc 'yay -Qi'
        abbr -a yalocs 'yay -Qs'
        abbr -a yalst 'yay -Qe'
        abbr -a yaorph 'yay -Qtd'
        abbr -a yainsd 'yay -S --asdeps'
        abbr -a yamir 'yay -Syy'
        abbr -a yaupd 'yay -Sy'
    end
    
    # Flatpak
    if command -v flatpak &>/dev/null
        abbr -a fpk 'flatpak'
        abbr -a fpkin 'flatpak install'
        abbr -a fpkup 'flatpak update'
        abbr -a fpkupg 'flatpak update -y'
        abbr -a fpkls 'flatpak list'
        abbr -a fpkre 'flatpak uninstall'
        abbr -a fpkrem 'flatpak uninstall --delete-data'
        abbr -a fpkinfo 'flatpak info'
        abbr -a fpkrun 'flatpak run'
        abbr -a fpkrps 'flatpak search'
        abbr -a fpkrmu 'flatpak uninstall --unused -y'
        abbr -a fpkrpo 'flatpak remote-list'
        abbr -a fpkhis 'flatpak history'
        abbr -a fpkover 'flatpak override'
        abbr -a fpkrpa 'flatpak remote-add'
        abbr -a fpkrpr 'flatpak remote-remove'
        abbr -a fpkreps 'flatpak search'
        abbr -a fpkclean 'flatpak uninstall --unused -y'
    end

    # -----------------------------------------------------
    # SETTINGS
    # -----------------------------------------------------

    set -g fish_history_path ~/.local/share/fish/fish_history
    set -g fish_history_max_age 3650
    
    set -gx GREP_OPTIONS "--color=auto"
    
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
    set -gx SSH_AUTH_SOCK /home/tymon/.bitwarden-ssh-agent.sock

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

    # -----------------------------------------------------
    # FUNCTIONS
    # -----------------------------------------------------

    # Make directory and change to it
    function mkcd
        mkdir -p $argv && cd $argv
    end

    # Extract various archive formats
    function extract
        if test -f $argv[1]
            switch $argv[1]
                case '*.tar.bz2' tar xjf $argv[1]
                case '*.tar.gz' tar xzf $argv[1]
                case '*.bz2' bunzip2 $argv[1]
                case '*.rar' unrar x $argv[1]
                case '*.gz' gunzip $argv[1]
                case '*.tar' tar xf $argv[1]
                case '*.tbz2' tar xjf $argv[1]
                case '*.tgz' tar xzf $argv[1]
                case '*.zip' unzip $argv[1]
                case '*.Z' uncompress $argv[1]
                case '*.7z' 7z x $argv[1]
                case '*' echo "'$argv[1]' cannot be extracted"
            end
        else
            echo "'$argv[1]' is not a valid file"
        end
    end

     # Update system packages
    function update
        echo "Updating Pacman packages..."
        sudo pacman -Syu
        
        if command -v yay &>/dev/null
            echo "Updating AUR packages..."
            yay -Syu
            
      echo "Updating Zen Twilight..."
            # Only update Zen Twilight if it's already installed
            if pacman -Q zen-twilight-bin &>/dev/null
                # First remove the old package if installed
                yay -R zen-twilight-bin --noconfirm
                
                # Clean the cache directory for zen-twilight-bin
                if test -d ~/.cache/yay/zen-twilight-bin
                    rm -rf ~/.cache/yay/zen-twilight-bin
                end
                
                # Install the package with force rebuild options
                yay -S zen-twilight-bin --noconfirm --redownload --rebuild --cleanafter
                echo "Zen Twilight updated successfully!"
            else
                echo "Zen Twilight not installed, skipping update."
            end
        end
        
        if command -v flatpak &>/dev/null
            echo "Updating Flatpak packages..."
            flatpak update -y
        end
        
        echo "System update complete!"
    end


    # -----------------------------------------------------
    # GREETING
    # -----------------------------------------------------

    function fish_greeting
        echo ""
        echo "Hi!, $USER!"
        echo "Today is $(date '+%A, %B %d')"
        echo ""
    end
end