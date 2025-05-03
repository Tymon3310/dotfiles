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
# SYSTEM FUNCTIONS
# -----------------------------------------------------

# Update system packages
function update
    # Set up signal handler for SIGINT (Ctrl+C)
    function __update_cleanup --on-signal INT
        echo ""
        echo "Update canceled by user."
        # Clean up any temporary files or processes if needed

        # Reset the handler
        functions -e __update_cleanup
        exit 1
    end

    # Parse arguments
    set -l update_browsers false
    set -l skip_confirm false
    set -l clean_cache false
    set -l filter ""
    set -l start_time (date +%s)

    for arg in $argv
        switch $arg
            case -b --browser --browsers
                set update_browsers true
            case -y --yes
                set skip_confirm true
            case -c --clean
                set clean_cache true
            case -f --filter
                # Next argument is the filter
                set next_is_filter true
            case -h --help
                echo "Usage: update [options]"
                echo "Options:"
                echo "  -b, --browser      Update Zen Twilight browser only"
                echo "  -y, --yes          Skip confirmation prompts"
                echo "  -c, --clean        Clean package caches after update"
                echo "  -f, --filter STR   Only show packages containing STR"
                echo "  -h, --help         Show this help message"
                return 0
            case '*'
                if set -q next_is_filter
                    set filter $arg
                    set -e next_is_filter
                end
        end
    end

    # Handle browser-only update
    if test "$update_browsers" = true
        echo "Updating Zen Twilight browser..."

        # Check if zen-twilight-bin is installed
        if pacman -Q zen-twilight-bin &>/dev/null
            # Remove the old package
            sudo pacman -R zen-twilight-bin --noconfirm

            # Clean cache
            if test -d ~/.cache/yay/zen-twilight-bin
                rm -rf ~/.cache/yay/zen-twilight-bin
            end

            # Install the new package
            gum style --foreground "#00AFFF" --bold "Updating Zen Twilight browser..."
            yay -S zen-twilight-bin --noconfirm --redownload --rebuild --cleanafter

            # Ask to restart the browser
            echo ""
            echo "Zen Twilight has been updated!"
            # Prompt to restart browser with a styled border
            echo (gum style --border rounded --border-foreground "#00AFFF" --foreground "#00AFFF" --bold "Restart browser now?")
            set -l restart_response (gum choose --cursor.foreground "#00AFFF" Yes No)
            if test "$restart_response" = Yes
                if pgrep -f zen-twilight >/dev/null
                    echo "Restarting Zen Twilight..."
                    pkill -f zen-twilight
                    sleep 1
                    hyprctl dispatch exec [workspace 11 silent] zen-twilight
                else
                    echo "Starting Zen Twilight..."
                    hyprctl dispatch exec [workspace 11 silent] zen-twilight
                end
            end
        else
            echo "Zen Twilight not installed."
        end

        return 0
    end

    # Main update process
    # Animated Checking for updates header
    printf (gum style --foreground "#00AFFF" --bold "Checking for updates")
    for i in (seq 1 4)
        sleep 0.3
        printf '.'
    end
    echo ''

    # Check for gum for prettier output
    set -l has_gum false
    if command -v gum >/dev/null 2>&1
        set has_gum true
    end

    # Get updates
    set -l pacman_updates ""
    if command -v checkupdates >/dev/null 2>&1
        set pacman_updates (checkupdates 2>/dev/null | grep -i "$filter")
    else if command -v pacman >/dev/null 2>&1
        set pacman_updates (pacman -Qu 2>/dev/null | grep -i "$filter")
    end

    set -l aur_updates ""
    if command -v yay >/dev/null 2>&1
        set aur_updates (yay -Qua 2>/dev/null | grep -i "$filter")
    end

    set -l flatpak_updates ""
    if command -v flatpak >/dev/null 2>&1
        set flatpak_updates (flatpak remote-ls --updates 2>/dev/null | grep -i "$filter")
    end

    # Get counts
    set -l pacman_count (count $pacman_updates)
    set -l aur_count (count $aur_updates)
    set -l flatpak_count (count $flatpak_updates)
    set -l total_count (math $pacman_count + $aur_count + $flatpak_count)

    # Show summary
    if test "$has_gum" = true
        gum style --border rounded --border-foreground "#00FFFF" --foreground "#00FFFF" --bold "Found $total_count updates:" --padding "0 1" --margin 0
        if test $pacman_count -gt 0
            echo (gum style --foreground "#00AFFF" "• Pacman: $pacman_count")
        end
        if test $aur_count -gt 0
            echo (gum style --foreground "#FF8700" "• AUR: $aur_count")
        end
        if test $flatpak_count -gt 0
            echo (gum style --foreground "#00FF00" "• Flatpak: $flatpak_count")
        end
    else
        echo "Found $total_count updates:"
        if test $pacman_count -gt 0
            echo "• Pacman: $pacman_count"
        end
        if test $aur_count -gt 0
            echo "• AUR: $aur_count"
        end
        if test $flatpak_count -gt 0
            echo "• Flatpak: $flatpak_count"
        end
    end
    echo ""

    # No updates case
    if test $total_count -eq 0
        echo "No updates available."
        return 0
    end

    # Create numbered list for ALL packages (simpler approach)
    set -l all_updates
    set -g display_list ""

    # Add a header for pacman
    if test $pacman_count -gt 0
        if test "$has_gum" = true
            set -a display_list (gum style --foreground "#00AFFF" --bold "== Pacman Updates ==")
        else
            set -a display_list "== Pacman Updates =="
        end
        set -a display_list ""
    end

    # Add pacman packages
    for pkg in $pacman_updates
        set -a all_updates "pacman:$pkg"
        set -l idx (count $all_updates)

        # Extract package name for repository lookup
        set -l pkg_name (string split " " $pkg)[1]
        if string match -q "*/*" $pkg_name
            set pkg_name (string split "/" $pkg_name)[2]
        end

        # Get repository info and color
        set -l repo_info (get_package_repo_info $pkg_name)
        set -l repo (string split " " $repo_info)[1]
        set -l repo_color (string split " " $repo_info)[2]

        if test "$has_gum" = true
            # Fix: Combine everything into a single string to prevent line breaks
            set -l styled_idx (gum style --foreground "#00AFFF" --bold "[$idx]")
            set -l styled_repo (gum style --foreground "$repo_color" "$repo")
            set -a display_list (printf "%s %-15s %s" $styled_idx $styled_repo "$pkg")
        else
            # Fix: Format as a single line with proper padding
            set -a display_list (printf "%-5s %-12s %s" "[$idx]" "$repo" "$pkg")
        end
    end

    # Add a separator after pacman
    if test $pacman_count -gt 0
        set -a display_list ""
    end

    # Add a header for AUR
    if test $aur_count -gt 0
        if test "$has_gum" = true
            set -a display_list (gum style --foreground "#FF8700" --bold "== AUR Updates ==")
        else
            set -a display_list "== AUR Updates =="
        end
        set -a display_list ""
    end

    # Add AUR packages
    for pkg in $aur_updates
        set -a all_updates "aur:$pkg"
        set -l idx (count $all_updates)

        if test "$has_gum" = true
            # Format AUR packages similar to pacman packages
            set -l styled_idx (gum style --foreground "#FF8700" --bold "[$idx]")
            set -l styled_repo (gum style --foreground "#FF8700" "aur")
            set -a display_list (printf "%s %-15s %s" $styled_idx $styled_repo "$pkg")
        else
            # Format with proper padding
            set -a display_list (printf "%-5s %-12s %s" "[$idx]" "aur" "$pkg")
        end
    end

    # Add a separator after AUR
    if test $aur_count -gt 0
        set -a display_list ""
    end

    # Add a header for flatpak
    if test $flatpak_count -gt 0
        if test "$has_gum" = true
            set -a display_list (gum style --foreground "#00FF00" --bold "== Flatpak Updates ==")
        else
            set -a display_list "== Flatpak Updates =="
        end
        set -a display_list ""
    end

    # Add flatpak packages
    for pkg in $flatpak_updates
        set -a all_updates "flatpak:$pkg"
        set -l idx (count $all_updates)

        if test "$has_gum" = true
            # Format Flatpak packages similar to pacman packages
            set -l styled_idx (gum style --foreground "#00FF00" --bold "[$idx]")
            set -l styled_repo (gum style --foreground "#00FF00" "flatpak")
            set -a display_list (printf "%s %-15s %s" $styled_idx $styled_repo "$pkg")
        else
            # Format with proper padding
            set -a display_list (printf "%-5s %-12s %s" "[$idx]" "flatpak" "$pkg")
        end
    end

    # Show all packages
    echo "Available updates:"
    echo ""
    for line in $display_list
        echo $line
    end
    echo ""

    # Skip if no confirmation needed
    if test "$skip_confirm" = false
        set -l exclude_input (gum input --placeholder "Exclude numbers (e.g., 1 2 3 or 1-3)")

        set -l excluded_indices

        # Parse exclusion input
        if test -n "$exclude_input"
            for part in (string split " " $exclude_input)
                if string match -qr '^[0-9]+-[0-9]+$' $part
                    # Handle range (e.g., "1-3")
                    set -l range (string split "-" $part)
                    for i in (seq $range[1] $range[2])
                        set -a excluded_indices $i
                    end
                else if string match -qr '^[0-9]+$' $part
                    # Handle single number
                    set -a excluded_indices $part
                end
            end
        end

        # Prepare exclude lists
        set -l pacman_excludes
        set -l aur_excludes
        set -l flatpak_excludes

        # Process exclusions
        if test (count $excluded_indices) -gt 0
            echo ""
            echo "Excluding packages:"

            set -l has_flatpak_exclusions false

            for idx in $excluded_indices
                if test $idx -ge 1 -a $idx -le (count $all_updates)
                    set -l pkg_info $all_updates[$idx]
                    set -l pkg_type (string split ":" $pkg_info)[1]
                    set -l pkg_line (string replace "$pkg_type:" "" $pkg_info)

                    # Extract package name based on type
                    switch $pkg_type
                        case pacman
                            set -l pkg_name (string split " " $pkg_line)[1]
                            if string match -q "*/*" $pkg_name
                                set pkg_name (string split "/" $pkg_name)[2]
                            end
                            set -a pacman_excludes $pkg_name
                            echo "• [$idx] $pkg_name (Pacman)"

                        case aur
                            set -l pkg_name (string split " " $pkg_line)[1]
                            set -a aur_excludes $pkg_name
                            echo "• [$idx] $pkg_name (AUR)"

                        case flatpak
                            set -l pkg_name (string split " " $pkg_line)[1]
                            # Note that Flatpak exclusions are attempted but not supported
                            set has_flatpak_exclusions true
                            echo "• [$idx] $pkg_name (Flatpak) - Note: Flatpak exclusions are not supported"
                    end
                end
            end

            if test "$has_flatpak_exclusions" = true
                echo ""
                echo "⚠️ Note: Exclusions for Flatpak packages are not supported. All Flatpak packages will be updated."
            end
        end

        # Ask for confirmation with a styled border
        gum style --border rounded --border-foreground "#00AFFF" --foreground "#00AFFF" --bold "Proceed with update?"
        if not gum confirm \
                --prompt.foreground "#00AFFF" \
                --selected.foreground "#000000" \
                --selected.background "#00AFFF" \
                --unselected.foreground D0D0D0 \
                --unselected.background "#2d2d2d" \
                ""
            echo "Update canceled."
            return 0
        end
    end

    # Run updates with exclusions
    echo ""
    echo "Starting update process..."

    # Update pacman/AUR packages
    if test $pacman_count -gt 0 -o $aur_count -gt 0
        gum style --foreground "#00AFFF" --bold "Updating system packages..."

        set -l ignore_args
        for pkg in $pacman_excludes $aur_excludes
            set -a ignore_args --ignore $pkg
        end

        if test (count $ignore_args) -gt 0
            if test "$skip_confirm" = false
                set -l sudo_pass (gum input --password --placeholder "Sudo password")
                printf "%s\n" $sudo_pass | sudo -S -v
            else
                sudo -v
            end
            gum style --foreground "#00AFFF" --bold "Updating system packages..."
            yay -Syu --noconfirm $ignore_args
        else
            if test "$skip_confirm" = false
                set -l sudo_pass (gum input --password --placeholder "Sudo password")
                printf "%s\n" $sudo_pass | sudo -S -v
            else
                sudo -v
            end
            gum style --foreground "#00AFFF" --bold "Updating system packages..."
            yay -Syu --noconfirm
        end
    end

    if test $flatpak_count -gt 0
        gum style --foreground "#00AFFF" --bold "Updating Flatpak packages..."
        flatpak update --noninteractive
    end

    # Clean package caches if requested
    if test "$clean_cache" = true
        echo "Cleaning package caches..."
        if command -v paccache &>/dev/null
            sudo paccache -r
        end
        if command -v flatpak &>/dev/null
            flatpak uninstall --unused
        end
    end

    # Calculate elapsed time
    set -l end_time (date +%s)
    set -l elapsed (math $end_time - $start_time)
    set -l minutes (math "floor($elapsed / 60)")
    set -l seconds (math "$elapsed % 60")

    echo ""
    echo "Update completed in $minutes minutes and $seconds."

    # Check for kernel updates with more precise detection
    set -l kernel_updated false
    set -l current_kernel (pacman -Q linux | awk '{print $2}')
    set -l kernel_packages linux linux-lts linux-zen linux-hardened

    for pkg in $pacman_updates
        set -l pkg_name (string split " " $pkg)[1]
        # Check if it's one of the main kernel packages (exact match)
        if contains $pkg_name $kernel_packages
            set kernel_updated true
            echo ""
            echo "⚠ Kernel update detected: $pkg_name from version $current_kernel"
            echo "A system restart is recommended after updating."
            break
        end
    end

    # Only use the old detection method as fallback if no exact match was found
    if test "$kernel_updated" = false
        for pkg in $pacman_updates $aur_updates
            set -l pkg_name (string split " " $pkg)[1]
            if string match -q "*linux*" $pkg_name
                if not string match -q "*firmware*" $pkg_name; and not string match -q "*headers*" $pkg_name; and not string match -q "*virtualbox*" $pkg_name
                    set kernel_updated true
                    echo ""
                    echo "⚠ Possible kernel-related update detected: $pkg_name"
                    echo "A system restart may be recommended."
                    break
                end
            end
        end
    end

    # At the end of the function, remove the signal handler
    functions -e __update_cleanup
end

# Function to get repository for a package and its color
function get_package_repo_info
    set -l pkg_name $argv[1]

    # Check if package name is empty
    if test -z "$pkg_name"
        echo "unknown #BFBFBF"
        return 1
    end

    # Query pacman database for repository info
    set -l repo_info (pacman -Si $pkg_name 2>/dev/null | grep "Repository" | awk '{print $3}')

    # Set default color for unknown repos
    set -l color "#FFFFFF"

    # If not found in standard repos, check if it's from a custom repo
    if test -z "$repo_info"
        # Check if installed and get info
        set -l db_info (pacman -Qi $pkg_name 2>/dev/null | grep "Repository" | awk '{print $3}')
        if test -n "$db_info"
            set repo_info $db_info
        else
            # Try to get info from pacman -Ss as a fallback
            set -l ss_info (pacman -Ss "^$pkg_name\$" 2>/dev/null | head -n1 | awk -F/ '{print $1}')
            if test -n "$ss_info"
                set repo_info $ss_info
            else
                # Assume AUR if not from a repo
                set repo_info aur
            end
        end
    end

    # Extract the first word as the repo name to prevent switch errors
    set -l repo_name (string split ' ' $repo_info)[1]

    # Set color based on repository
    switch "$repo_name"
        case core
            set color "#FF5555" # Red
        case core-testing
            set color "#FF79C6" # Pink
        case extra
            set color "#50FA7B" # Green
        case extra-testing
            set color "#8BE9FD" # Cyan
        case multilib
            set color "#FFB86C" # Orange
        case multilib-testing
            set color "#F1FA8C" # Yellow
        case aur
            set color "#FF8700" # AUR Orange
        case visual-studio-code-insiders
            set color "#3EA7FF" # VS Code Blue
        case '*'
            set color "#BFBFBF" # Light gray for other repos
    end

    echo "$repo_name $color"
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
