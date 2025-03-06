# -----------------------------------------------------
# NAVIGATION FUNCTIONS
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

# Make directory and change to it
function mkcd
    mkdir -p $argv && cd $argv
end

# -----------------------------------------------------
# UTILITY FUNCTIONS
# -----------------------------------------------------

# Enhanced fastfetch with options
function fastfetch
    if test "$argv[1]" = --full
        command fastfetch -c ~/.config/fastfetch/config-full.jsonc $argv[2..-1]
    else
        command fastfetch $argv
    end
end

# Allow using vanilla ls command (bypassing alias)
function lsv
    command ls $argv
end

# Allow using vanilla cat command (bypassing alias)
function catv
    command cat $argv
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

# -----------------------------------------------------
# SPINNER FUNCTIONS
# -----------------------------------------------------

function show_spinner
    # Check if gum is available
    if not command -v gum &>/dev/null
        echo $argv
        return 1
    end

    # Run the command with gum spinner
    set -l cmd $argv[2..-1]
    gum spin --spinner dot --title "$argv[1]" -- bash -c "$cmd"
    return $status
end

# -----------------------------------------------------
# SYSTEM FUNCTIONS
# -----------------------------------------------------

# Update system packages
function update
    # Parse arguments
    set -l update_browsers false

    # Check for -b flag
    for arg in $argv
        switch $arg
            case -b --browser --browsers
                set update_browsers true
        end
    end

    # Check if gum is installed
    set -l has_gum false
    if command -v gum &>/dev/null
        set has_gum true
        echo (gum style --foreground 212 "System Update Process")
        echo ""
    end

    # Ask for sudo password upfront
    if test "$has_gum" = true
        echo (gum style --foreground 220 "Please enter your sudo password:")
    else
        echo "Please enter your sudo password:"
    end

    # This will cache the sudo credentials
    sudo -v

    # When browser update mode is active, we don't need to check for regular updates
    if test "$update_browsers" = false
        # Only check for updates when not in browser update mode
        echo ""
        if test "$has_gum" = true
            echo (gum style --foreground 111 "Checking for available updates...")
        else
            echo "Checking for available updates..."
        end

        # Check for updates - separately check pacman and AUR
        set -l pacman_updates ""
        set -l aur_updates ""

        # Check official pacman updates 
        if command -v checkupdates &>/dev/null
            # Use checkupdates which is more reliable for official repos
            set pacman_updates (checkupdates 2>/dev/null)
        else if command -v pacman &>/dev/null
            # Fallback method
            set pacman_updates (pacman -Qu 2>/dev/null)
        end

        # Check AUR updates separately
        if command -v yay &>/dev/null
            set aur_updates (yay -Qua 2>/dev/null)
        end

        # Check for flatpak updates
        set -l flatpak_updates ""
        if command -v flatpak &>/dev/null
            set flatpak_updates (flatpak remote-ls --updates 2>/dev/null)
        end

        # Display update information
        echo ""
        # Show pacman updates
        if test -n "$pacman_updates"
            if test "$has_gum" = true
                echo (gum style --foreground 39 "Pacman Updates:")
            else
                echo "Pacman Updates:"
            end

            # Count updates
            set -l update_count (count $pacman_updates)
            echo "$update_count package(s) can be updated"

            # Show all updates
            for pkg in $pacman_updates
                echo " - $pkg"
            end
            echo ""
        else
            if test "$has_gum" = true
                echo (gum style --foreground 39 "Pacman Updates:") "None available"
            else
                echo "Pacman Updates: None available"
            end
            echo ""
        end

        # Show AUR updates
        if test -n "$aur_updates"
            if test "$has_gum" = true
                echo (gum style --foreground 202 "AUR Updates:")
            else
                echo "AUR Updates:"
            end

            # Count updates
            set -l update_count (count $aur_updates)
            echo "$update_count package(s) can be updated"

            # Show all updates
            for pkg in $aur_updates
                echo " - $pkg"
            end
            echo ""
        else
            if test "$has_gum" = true
                echo (gum style --foreground 202 "AUR Updates:") "None available"
            else
                echo "AUR Updates: None available"
            end
            echo ""
        end

        if test -n "$flatpak_updates"
            if test "$has_gum" = true
                echo (gum style --foreground 33 "Flatpak Updates:")
            else
                echo "Flatpak Updates:"
            end

            # Count updates
            set -l update_count (count $flatpak_updates)
            echo "$update_count app(s) can be updated"

            # Show all updates
            for pkg in $flatpak_updates
                echo " - $pkg"
            end
            echo ""
        else
            if test "$has_gum" = true
                echo (gum style --foreground 33 "Flatpak Updates:") "None available"
            else
                echo "Flatpak Updates: None available"
            end
            echo ""
        end

        # Change the proceed logic to check both types of updates
        set -l proceed true
        if test -z "$pacman_updates" -a -z "$aur_updates" -a -z "$flatpak_updates"
            echo "No updates available."
            set proceed false
        else
            if test "$has_gum" = true
                gum confirm "Do you want to proceed with the updates?" || set proceed false
            else
                read -l -P "Do you want to proceed with the updates? [y/N] " confirm
                if test "$confirm" != Y -a "$confirm" != y
                    set proceed false
                end
            end
        end

        # Exit if user doesn't want to proceed with system updates
        if test "$proceed" = false
            echo "Update canceled."
            return 0
        end
    else
        # In browser update mode, we always proceed
        if test "$has_gum" = true
            echo (gum style --foreground 212 "Browser Update Process")
        else
            echo "Starting browser update process..."
        end
        echo ""
    end

    # Regular system updates (only if not in browser mode)
    if test "$update_browsers" = false
        echo ""
        if test "$has_gum" = true
            echo (gum style --foreground 212 "Starting update process...")
        else
            echo "Starting update process..."
        end
        echo ""

        # Update system packages
        if command -v yay &>/dev/null
            if test "$has_gum" = true
                show_spinner "Updating Pacman and AUR packages..." "yay -Syu --noconfirm"
            else
                echo "Updating Pacman and AUR packages..."
                yay -Syu
            end
        else if command -v pacman &>/dev/null
            if test "$has_gum" = true
                show_spinner "Updating Pacman packages..." "sudo pacman -Syu --noconfirm"
            else
                echo "Updating Pacman packages..."
                sudo pacman -Syu
            end
        end

        # Update Flatpak packages
        if command -v flatpak &>/dev/null
            if test "$has_gum" = true
                show_spinner "Updating Flatpak packages..." "flatpak update -y"
            else
                echo "Updating Flatpak packages..."
                flatpak update -y
            end
        end
    end

    # Browser-specific updates (including Zen Twilight)
    if test "$update_browsers" = true
        # Update Zen Twilight only in browser mode
        if command -v yay &>/dev/null
            if pacman -Q zen-twilight-bin &>/dev/null
                if test "$has_gum" = true
                    # Remove the old package
                    show_spinner "Removing old Zen Twilight..." "yay -R zen-twilight-bin --noconfirm"

                    # Clean cache directory
                    if test -d ~/.cache/yay/zen-twilight-bin
                        show_spinner "Cleaning Zen Twilight cache..." "rm -rf ~/.cache/yay/zen-twilight-bin"
                    end

                    # Install updated package
                    show_spinner "Installing new Zen Twilight..." "yay -S zen-twilight-bin --noconfirm --redownload --rebuild --cleanafter"
                else
                    echo "Updating Zen Twilight..."
                    # First remove the old package if installed
                    yay -R zen-twilight-bin --noconfirm

                    # Clean the cache directory for zen-twilight-bin
                    if test -d ~/.cache/yay/zen-twilight-bin
                        rm -rf ~/.cache/yay/zen-twilight-bin
                    end

                    # Install the package with force rebuild options
                    yay -S zen-twilight-bin --noconfirm --redownload --rebuild --cleanafter
                    echo "Zen Twilight updated successfully!"
                end
            else
                echo "Zen Twilight not installed, skipping update."
            end
        end
    end

    # Show completion message
    if test "$has_gum" = true
        echo ""
        echo (gum style --foreground 121 "✓ System update complete!")
    else
        echo "System update complete!"
    end
end

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

# -----------------------------------------------------
# PYTHON VIRTUAL ENVIRONMENT
# -----------------------------------------------------

# Activate or create Python virtual environment
function venvon
    if test -d .venv
        echo "Virtual environment found, activating..."
    else
        echo "Creating new virtual environment in .venv..."
        python -m venv .venv

        if test $status -ne 0
            echo "Failed to create virtual environment. Make sure python and venv are installed."
            return 1
        end

        echo "Virtual environment created successfully."
    end

    # Activate the virtual environment
    source .venv/bin/activate.fish

    if test $status -eq 0
        echo "Virtual environment activated. Use 'venvoff' to deactivate."
        echo "Python: "(which python)
        echo "Pip: "(which pip)
    else
        echo "Failed to activate virtual environment."
        return 1
    end
end

# Deactivate Python virtual environment
function venvoff
    if set -q VIRTUAL_ENV
        deactivate
        echo "Virtual environment deactivated."
    else
        echo "No active virtual environment."
    end
end

# -----------------------------------------------------
# GREETING
# -----------------------------------------------------

function fish_greeting
    echo ""
    echo "Hi!, $USER!"
    echo "Today is "(date '+%A, %B %d')
    echo ""
end
