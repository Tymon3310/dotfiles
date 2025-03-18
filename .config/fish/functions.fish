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

# -----------------------------------------------------
# SYSTEM FUNCTIONS
# -----------------------------------------------------

# Update system packages
function update
    # Parse arguments
    set -l update_browsers false
    set -l verbose false
    set -l skip_confirm false
    set -l update_summary ""
    set -l update_errors ""
    set -l start_time (date +%s)
    set -l clean_cache false # Default to not cleaning cache

    # Process command line arguments
    for arg in $argv
        switch $arg
            case -b --browser --browsers
                set update_browsers true
            case -v --verbose
                set verbose true
            case -y --yes
                set skip_confirm true
            case -c --clean
                set clean_cache true # Only clean when explicitly requested
            case -h --help
                echo "Usage: update [options]"
                echo "Options:"
                echo "  -b, --browser, --browsers  Update Zen Twilight only"
                echo "  -v, --verbose              Show detailed output"
                echo "  -y, --yes                  Skip confirmation prompts"
                echo "  -c, --clean                Clean package caches after update"
                echo "  -h, --help                 Show this help message"
                return 0
        end
    end

    # Check if gum is installed for better UI
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

    # Cache sudo credentials
    sudo -v || begin
        echo "Failed to authenticate. Update canceled."
        return 1
    end

    # Start a background process to keep sudo credentials alive
    set -g sudo_keeper_pid 0

    # Define a function to kill the sudo keeper
    function kill_sudo_keeper
        if test -n "$sudo_keeper_pid" && test "$sudo_keeper_pid" -ne 0
            kill $sudo_keeper_pid 2>/dev/null
        end
    end

    # Start the background process to keep sudo alive
    fish -c "while true; sudo -v; sleep 50; end" &
    set sudo_keeper_pid $last_pid

    # Make sure we clean up the background process when this function exits
    function on_exit --on-process-exit %self
        kill_sudo_keeper
    end

    # Function to add to summary
    function add_to_summary
        set update_summary $update_summary "$argv"
    end

    # Function to add to errors
    function add_to_errors
        set update_errors $update_errors "$argv"
    end

    # Function to run a command with error handling
    function run_command
        set -l title $argv[1]
        set -l cmd $argv[2..-1]

        if test "$has_gum" = true -a "$verbose" = false
            gum spin --spinner dot --title "$title" -- fish -c "$cmd"
        else
            echo "• $title"
            eval $cmd
        end

        set -l status_code $status
        if test $status_code -ne 0
            add_to_errors "❌ $title failed with status $status_code"
            return $status_code
        else
            add_to_summary "✓ $title completed successfully"
            return 0
        end
    end

    # When browser update mode is active, we don't need to check for regular updates
    if test "$update_browsers" = false
        # Only check for updates when not in browser update mode
        echo ""
        if test "$has_gum" = true
            echo (gum style --foreground 111 "Checking for available updates...")
        else
            echo "Checking for available updates..."
        end

        # Function to display update information with proper formatting
        function display_updates
            set -l type $argv[1]
            set -l color $argv[2]
            set -l updates $argv[3..-1] # Get all remaining arguments as updates

            # Header
            if test "$has_gum" = true
                echo (gum style --foreground $color --bold "$type Updates:")
            else
                echo "=== $type Updates ==="
            end

            # Process updates
            if test (count $updates) -gt 0
                # Count non-empty updates
                set -l update_count 0
                for pkg in $updates
                    if test -n "$pkg"
                        set update_count (math $update_count + 1)
                    end
                end

                # Format the update count
                if test "$has_gum" = true
                    echo (gum style --bold "$update_count") "package(s) can be updated"
                else
                    echo "$update_count package(s) can be updated"
                end
                echo ""

                # Calculate starting index for reverse numbering
                set -l start_index (math $total_updates)

                # Process each package on its own line with reversed numbers
                for pkg in $updates
                    if test -n "$pkg"
                        if test "$has_gum" = true
                            echo " " (gum style --foreground $color --bold "$start_index") "  " (gum style --foreground $color "•") " $pkg"
                        else
                            echo " $start_index  • $pkg"
                        end
                        set start_index (math $start_index - 1)
                        set -g pkg_index (math $pkg_index + 1)
                    end
                end

                echo ""
                return $update_count
            else
                # No updates
                if test "$has_gum" = true
                    echo (gum style --italic "None available")
                else
                    echo "None available"
                end
                echo ""
                return 0
            end
        end

        # Check and display updates for each type and count total
        set -l total_updates 0
        set -l count 0
        set -g all_packages
        set -g pkg_index 1

        # Function to check updates and add them to the global list
        function check_and_display_updates
            set -l type $argv[1]
            set -l color $argv[2]
            set -l cmd $argv[3..-1]

            # Run the command and get the output
            set -l output (eval $cmd 2>/dev/null)

            # If there's output, display it and add to all_packages
            if test -n "$output"
                # Split the output into lines
                set -l lines (string split "\n" $output)

                # Add to total updates first
                set -g total_updates (math $total_updates + (count $lines))

                # Display the updates
                display_updates $type $color $lines

                # Add packages to the global list
                for pkg in $lines
                    if test -n "$pkg"
                        # Extract package name and version info like yay format
                        set -l pkg_parts (string split " " $pkg)
                        if test "$type" = AUR
                            set -g all_packages $all_packages "$pkg_parts[1]"
                        else
                            # For non-AUR packages, just use the package name without repo prefix
                            set -g all_packages $all_packages "$pkg_parts[1]"
                        end
                    end
                end

                return (count $lines)
            else
                # No updates
                display_updates $type $color
                return 0
            end
        end

        # Check and display Pacman updates
        if command -v checkupdates &>/dev/null
            check_and_display_updates Pacman 39 checkupdates
        else if command -v pacman &>/dev/null
            check_and_display_updates Pacman 39 "pacman -Qu"
        end
        set count $status
        set total_updates (math $total_updates + $count)

        # Check and display AUR updates
        if command -v yay &>/dev/null
            check_and_display_updates AUR 202 "yay -Qua"
        end
        set count $status
        set total_updates (math $total_updates + $count)

        # Check and display Flatpak updates
        if command -v flatpak &>/dev/null
            check_and_display_updates Flatpak 33 "flatpak remote-ls --updates"
        end
        set count $status
        set total_updates (math $total_updates + $count)

        # Check and display Snap updates
        if command -v snap &>/dev/null
            check_and_display_updates Snap 226 "snap refresh --list | tail -n +2"
        end
        set count $status
        set total_updates (math $total_updates + $count)

        # Check and display Homebrew updates
        if command -v brew &>/dev/null
            check_and_display_updates Homebrew 208 "brew outdated"
        end
        set count $status
        set total_updates (math $total_updates + $count)

        # Change the proceed logic to check all types of updates
        set -l proceed true
        set -l excluded_packages ""

        if test $total_updates -eq 0
            echo "No updates available."
            set proceed false
        else if test "$skip_confirm" = true
            echo "Proceeding with updates (--yes flag provided)..."
        else
            # Ask if user wants to exclude any packages
            if test "$has_gum" = true
                echo (gum style --foreground 220 "Packages to exclude: (eg: \"1 2 3\", \"1-3\", \"^4\" or repo name)")
                echo (gum style --italic "--" "Excluding packages may cause partial upgrades and break systems")
                set excluded_packages (gum input --placeholder "Enter package numbers to exclude (leave empty for none)")
            else
                echo "Packages to exclude: (eg: \"1 2 3\", \"1-3\", \"^4\" or repo name)"
                echo "-- Excluding packages may cause partial upgrades and break systems"
                read -l -P "Enter package numbers to exclude (leave empty for none): " excluded_packages
            end

            # Process excluded packages to show their names
            if test -n "$excluded_packages"
                echo ""
                echo "Excluding packages:"

                # Parse the excluded packages string
                # Handle ranges like "1-3"
                set -l expanded_exclusions

                # Process each part of the exclusion string
                for part in (string split " " $excluded_packages)
                    if string match -qr '^[0-9]+-[0-9]+$' $part
                        # Handle range (e.g., "1-3")
                        set -l range_parts (string split "-" $part)
                        set -l start $range_parts[1]
                        set -l end $range_parts[2]

                        for i in (seq $start $end)
                            set -a expanded_exclusions $i
                        end
                    else if string match -qr '^[0-9]+$' $part
                        # Handle single number
                        set -a expanded_exclusions $part
                    else
                        # Handle repo/package name exclusion
                        echo "  • Excluding by name: $part"
                    end
                end

                # Display each excluded package by number
                for num in $expanded_exclusions
                    if string match -qr '^[0-9]+$' $num
                        # Convert display number to internal index
                        set -l internal_index (math $total_updates - $num + 1)
                        if test $internal_index -ge 1 -a $internal_index -le (count $all_packages)
                            if test "$has_gum" = true
                                echo "  " (gum style --foreground 220 "•") " $num: $all_packages[$internal_index]"
                            else
                                echo "  • $num: $all_packages[$internal_index]"
                            end
                        end
                    end
                end
                echo ""
            end

            # Ask if user wants to proceed with updates
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
            # Kill the sudo keeper process
            kill_sudo_keeper
            return 0
        end

        # Regular system updates
        echo ""
        if test "$has_gum" = true
            echo (gum style --foreground 212 "Starting update process...")
        else
            echo "Starting update process..."
        end
        echo ""

        # Update system packages with exclusions
        if command -v yay &>/dev/null
            if test -n "$excluded_packages"
                # Convert numbers to package names
                set -l ignore_args ""
                set -g updated_packages "" # Create a list of actually updated packages

                # Parse the excluded packages string
                # Handle ranges like "1-3"
                set -l expanded_exclusions

                # Process each part of the exclusion string
                for part in (string split " " $excluded_packages)
                    if string match -qr '^[0-9]+-[0-9]+$' $part
                        # Handle range (e.g., "1-3")
                        set -l range_parts (string split "-" $part)
                        set -l start $range_parts[1]
                        set -l end $range_parts[2]

                        for i in (seq $start $end)
                            set -a expanded_exclusions $i
                        end
                    else if string match -qr '^[0-9]+$' $part
                        # Handle single number
                        set -a expanded_exclusions $part
                    else
                        # Handle direct package name
                        set ignore_args "$ignore_args --ignore $part"
                    end
                end

                # Convert numbers to package names
                for num in $expanded_exclusions
                    if string match -qr '^[0-9]+$' $num
                        # Calculate internal index: displayed_number = total_updates - internal_index + 1
                        # So internal_index = total_updates - displayed_number + 1
                        set -l internal_index (math $total_updates - $num + 1)
                        if test $internal_index -ge 1 -a $internal_index -le (count $all_packages)
                            # Use just the package name without repo prefix for exclusions
                            set -l pkg_name $all_packages[$internal_index]
                            # Remove any repo prefix if present (like "aur/")
                            set pkg_name (string replace -r '^[^/]+/' '' $pkg_name)
                            set ignore_args "$ignore_args --ignore $pkg_name"
                        end
                    end
                end

                # Run yay with ignore flags
                echo "Running: yay -Syu --noconfirm $ignore_args"

                # Capture the output of yay to identify updated packages
                set -l update_output (yay -Syu --noconfirm $ignore_args 2>&1)
                run_command "Updating Pacman and AUR packages" "echo \"$update_output\""

                # Extract updated packages from the output
                for line in $update_output
                    if string match -q "*installed*" $line; or string match -q "*upgraded*" $line
                        # Extract package name from the output line
                        set -l pkg_name (string match -r "([^ ]+)" $line)
                        if test -n "$pkg_name"
                            set -g updated_packages $updated_packages $pkg_name
                        end
                    end
                end
            else
                # Capture the output of yay to identify updated packages
                set -l update_output (yay -Syu --noconfirm 2>&1)
                run_command "Updating Pacman and AUR packages" "echo \"$update_output\""

                # Extract updated packages from the output
                set -g updated_packages ""
                for line in $update_output
                    if string match -q "*installed*" $line; or string match -q "*upgraded*" $line
                        # Extract package name from the output line
                        set -l pkg_name (string match -r "([^ ]+)" $line)
                        if test -n "$pkg_name"
                            set -g updated_packages $updated_packages $pkg_name
                        end
                    end
                end
            end
        else if command -v pacman &>/dev/null
            # Capture the output of pacman to identify updated packages
            set -l update_output (sudo pacman -Syu --noconfirm 2>&1)
            run_command "Updating Pacman packages" "echo \"$update_output\""

            # Extract updated packages from the output
            set -g updated_packages ""
            for line in $update_output
                if string match -q "*installed*" $line; or string match -q "*upgraded*" $line
                    # Extract package name from the output line
                    set -l pkg_name (string match -r "([^ ]+)" $line)
                    if test -n "$pkg_name"
                        set -g updated_packages $updated_packages $pkg_name
                    end
                end
            end
        end

        # Update Flatpak packages
        if command -v flatpak &>/dev/null
            run_command "Updating Flatpak packages" "flatpak update -y"
        end

        # Clean package caches (only if explicitly requested)
        if test "$clean_cache" = true && command -v paccache &>/dev/null
            run_command "Cleaning pacman cache" "sudo paccache -r"
        end
    else
        # Zen Twilight update only
        echo ""
        if test "$has_gum" = true
            echo (gum style --foreground 212 "Starting Zen Twilight update...")
        else
            echo "Starting Zen Twilight update..."
        end
        echo ""

        # Update Zen Twilight
        if command -v yay &>/dev/null
            if pacman -Q zen-twilight-bin &>/dev/null
                # Remove the old package
                run_command "Removing old Zen Twilight" "sudo pacman -R zen-twilight-bin --noconfirm"

                # Clean cache directory
                if test -d ~/.cache/yay/zen-twilight-bin
                    run_command "Cleaning Zen Twilight cache" "rm -rf ~/.cache/yay/zen-twilight-bin"
                end

                # Install updated package
                run_command "Installing new Zen Twilight" "yay -S zen-twilight-bin --noconfirm --redownload --rebuild --cleanafter"

                # Prompt to restart the browser
                echo ""
                if test "$has_gum" = true
                    echo (gum style --foreground 220 "⚠ Zen Twilight has been updated! Please restart your browser to apply the changes.")

                    # Ask if user wants to restart the browser now
                    if gum confirm "Do you want to restart Zen Twilight now?"
                        # Check if Zen Twilight is running
                        if pgrep -f zen-twilight >/dev/null
                            echo "Restarting Zen Twilight..."
                            pkill -f zen-twilight
                            sleep 1
                            hyprctl dispatch exec [workspace 11 silent] zen-twilight
                            echo "Zen Twilight has been restarted."
                        else
                            echo "Zen Twilight is not currently running."
                            echo "Starting Zen Twilight..."
                            hyprctl dispatch exec [workspace 11 silent] zen-twilight
                            echo "Zen Twilight has been started."
                        end
                    end
                else
                    echo "⚠ Zen Twilight has been updated! Please restart your browser to apply the changes."

                    # Ask if user wants to restart the browser now
                    read -l -P "Do you want to restart Zen Twilight now? [y/N] " confirm
                    if test "$confirm" = Y -o "$confirm" = y
                        # Check if Zen Twilight is running
                        if pgrep -f zen-twilight >/dev/null
                            echo "Restarting Zen Twilight..."
                            pkill -f zen-twilight
                            sleep 1
                            hyprctl dispatch exec [workspace 11 silent] zen-twilight
                            echo "Zen Twilight has been restarted."
                        else
                            echo "Zen Twilight is not currently running."
                            echo "Starting Zen Twilight..."
                            hyprctl dispatch exec [workspace 11 silent] zen-twilight
                            echo "Zen Twilight has been started."
                        end
                    end
                end
            else
                echo "Zen Twilight not installed, skipping update."
            end
        end
    end

    # Kill the sudo keeper process
    kill_sudo_keeper

    # Calculate elapsed time
    set -l end_time (date +%s)
    set -l elapsed_time (math $end_time - $start_time)
    set -l minutes (math "floor($elapsed_time / 60)")
    set -l seconds (math "$elapsed_time % 60")
    set -l time_str ""

    if test $minutes -gt 0
        set time_str "$minutes minutes and $seconds seconds"
    else
        set time_str "$seconds seconds"
    end

    # Show completion message with summary
    echo ""
    if test "$has_gum" = true
        echo (gum style --foreground 121 "✓ System update complete!")
        echo (gum style --foreground 111 "Time elapsed: $time_str")

        if test -n "$update_summary"
            echo ""
            echo (gum style --foreground 121 "Summary:")
            for line in $update_summary
                echo " $line"
            end
        end

        if test -n "$update_errors"
            echo ""
            echo (gum style --foreground 196 "Errors:")
            for line in $update_errors
                echo " $line"
            end
        end
    else
        echo "✓ System update complete!"
        echo "Time elapsed: $time_str"

        if test -n "$update_summary"
            echo ""
            echo "Summary:"
            for line in $update_summary
                echo " $line"
            end
        end

        if test -n "$update_errors"
            echo ""
            echo "Errors:"
            for line in $update_errors
                echo " $line"
            end
        end
    end

    # Remind about system restart if kernel was updated
    set -l kernel_updated false

    # Check if updated_packages is defined before using it
    if set -q updated_packages
        for pkg in $updated_packages
            # More specific kernel package patterns
            if string match -q linux $pkg; or string match -q "linux-*" $pkg; or string match -q kernel $pkg; or string match -q "*-lts" $pkg; or string match -q "*-zen" $pkg; or string match -q "*-hardened" $pkg
                # Extra check to avoid false positives
                if not string match -q "*-firmware" $pkg; and not string match -q "*-headers" $pkg; and not string match -q "*-tools*" $pkg; and not string match -q "*-docs" $pkg; and not string match -q "linux-api-*" $pkg
                    set kernel_updated true
                    break
                end
            end
        end
    end

    if test "$kernel_updated" = true
        echo ""
        if test "$has_gum" = true
            echo (gum style --foreground 220 "⚠ Kernel update detected! A system restart is recommended.")
        else
            echo "⚠ Kernel update detected! A system restart is recommended."
        end
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
