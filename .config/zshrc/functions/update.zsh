#!/usr/bin/env zsh
# filepath: /home/tymon/dotfiles/.config/zshrc/functions/update.zsh

# Function to fix combined testing repository names (e.g., "core-testingcore" → "core-testing")
fix_repo_display() {
    sed -E 's/(core|extra|multilib)-testing\1/\1-testing/g'
}

# Function to get repository priority for sorting
# Lower number = higher priority
get_repo_priority() {
    local repo="$1"
    
    case "$repo" in
        core-testing)
            echo "1"
            ;;
        extra-testing)
            echo "2"
            ;;
        multilib-testing)
            echo "3"
            ;;
        core)
            echo "4"
            ;;
        extra)
            echo "4"
            ;;
        multilib)
            echo "5"
            ;;
        visual-studio-code-insiders)
            echo "9"
            ;;
        aur)
            echo "10"
            ;;
        *)
            echo "100"  # Custom repos get lowest priority
            ;;
    esac
}

# Function to get repository for a package and its color
get_package_repo_info() {
    local pkg_name_arg="$1" # Argument might be "repo/pkg" or just "pkg"
    local pkg_name="$pkg_name_arg"
    local repo_name="unknown" # Default repo name
    local color="#BFBFBF"    # Default color

    # Check if package name is empty
    if [[ -z "$pkg_name_arg" ]]; then
        echo "$repo_name $color"
        return 1
    fi

    # Handle packages with slash notation first (e.g., extra/btop from checkupdates)
    if [[ "$pkg_name_arg" == */* ]]; then
        repo_name=$(echo "$pkg_name_arg" | cut -d'/' -f1)
        pkg_name=$(echo "$pkg_name_arg" | cut -d'/' -f2)
        repo_name=$(echo "$repo_name" | fix_repo_display) # Fix display for testing repos
    elif [[ -n "${pkg_to_repo_map[$pkg_name_arg]}" ]]; then # Check our pre-fetched map
        repo_name="${pkg_to_repo_map[$pkg_name_arg]}"
        repo_name=$(echo "$repo_name" | fix_repo_display) # Fix display for testing repos
    else
        # If not in map or slash notation, try pacman -Qi for installed packages (often faster than -Si)
        local qi_repo_info=$(pacman -Qi "$pkg_name_arg" 2>/dev/null | grep "^Repository" | awk '{print $3}' | tr -d '[:space:]')
        if [[ -n "$qi_repo_info" ]]; then
            repo_name=$(echo "$qi_repo_info" | head -n1 | fix_repo_display)
        else
            # Fallback to pacman -Si (slowest)
            local si_repo_info=$(pacman -Si "$pkg_name_arg" 2>/dev/null | grep "^Repository" | awk '{print $3}' | tr -d '[:space:]')
            if [[ -n "$si_repo_info" ]]; then
                repo_name=$(echo "$si_repo_info" | head -n1 | fix_repo_display)
            fi
            # No need for pacman -Ss fallback here as pkg_to_repo_map should cover available packages
        fi
    fi

    # Set color based on repository if found, otherwise keep default
    if [[ -n "$repo_name" && "$repo_name" != "unknown" ]]; then
         case "$repo_name" in
            core)               color="#FF5555";; # Red
            core-testing)       color="#FF79C6";; # Pink
            extra)              color="#50FA7B";; # Green
            extra-testing)      color="#8BE9FD";; # Cyan
            multilib)           color="#FFB86C";; # Orange
            multilib-testing)   color="#F1FA8C";; # Yellow
            aur)                color="#FF8700";; # AUR Orange
            visual-studio-code-insiders) color="#3EA7FF";; # VS Code Blue
            *)                  color="#BFBFBF";; # Light gray for other repos
        esac
    else
        # If still unknown, set repo name explicitly
        repo_name="unknown"
    fi

    echo "$repo_name $color"
}

# Main update function
update() {
    # Create temporary files for update checks
    local pacman_tmp_file=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
    local aur_tmp_file=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
    local flatpak_tmp_file=$(mktemp -p /dev/shm 2>/dev/null || mktemp)

    # Set up signal handler for SIGINT (Ctrl+C) and EXIT
    # This trap will execute, print the message, clean up temp files, then remove the trap for INT, then return.
    trap 'echo ""; echo "Update canceled by user."; rm -f "$pacman_tmp_file" "$aur_tmp_file" "$flatpak_tmp_file"; trap - INT EXIT; return 1' INT
    trap 'rm -f "$pacman_tmp_file" "$aur_tmp_file" "$flatpak_tmp_file"; trap - EXIT' EXIT


    # Declare an associative array to store package to repository mappings
    typeset -A pkg_to_repo_map

    # Populate the map: pacman -Sl --color never output is "repo pkg version"
    # We want the *first* repo encountered for a package if listed multiple times,
    # assuming pacman.conf lists higher-priority repos first (e.g., testing before stable).
    typeset -A populated_pkgs_in_map # Helper to ensure we take the first entry from pacman -Sl

    while IFS=' ' read -r repo pkg_name version; do
        # Skip lines that don't conform to "repo pkg version" or are headers/empty
        if [[ -n "$repo" && -n "$pkg_name" && -n "$version" ]]; then
            if [[ -z "${populated_pkgs_in_map[$pkg_name]}" ]]; then # If this package name hasn't been added yet
                pkg_to_repo_map[$pkg_name]="$repo"
                populated_pkgs_in_map[$pkg_name]=1 # Mark as populated, subsequent entries for same pkg_name are ignored
            fi
        fi
    done < <(pacman -Sl --color never 2>/dev/null)

    # Parse arguments
    local update_browsers=false
    local skip_confirm=false
    local clean_cache=false
    local filter=""
    local start_time=$(date +%s)
    local next_is_filter=false

    # Process each argument
    for arg in "$@"; do
        case "$arg" in
            -b|--browser|--browsers)
                update_browsers=true
                ;;
            -y|--yes)
                skip_confirm=true
                ;;
            -c|--clean)
                clean_cache=true
                ;;
            -f|--filter)
                # Next argument is the filter
                next_is_filter=true
                ;;
            -h|--help)
                echo "Usage: update [options]"
                echo "Options:"
                echo "  -b, --browser      Update Zen Twilight browser only"
                echo "  -y, --yes          Skip confirmation prompts"
                echo "  -c, --clean        Clean package caches after update"
                echo "  -f, --filter STR   Only show packages containing STR"
                echo "  -h, --help         Show this help message"
                return 0
                ;;
            *)
                if [[ "$next_is_filter" = true ]]; then
                    filter="$arg"
                    next_is_filter=false
                fi
                ;;
        esac
    done

    # Handle browser-only update
    if [[ "$update_browsers" = true ]]; then
        echo "Updating Zen Twilight browser..."

        # Check if zen-twilight-bin is installed
        if pacman -Q zen-twilight-bin &>/dev/null; then
            # Remove the old package
            sudo pacman -R zen-twilight-bin --noconfirm

            # Clean cache
            if [[ -d ~/.cache/yay/zen-twilight-bin ]]; then
                rm -rf ~/.cache/yay/zen-twilight-bin
            fi

            # Install the new package
            gum style --foreground "#00AFFF" --bold "Updating Zen Twilight browser..."
            yay -S zen-twilight-bin --noconfirm --redownload --rebuild --cleanafter

            # Ask to restart the browser
            echo ""
            echo "Zen Twilight has been updated!"
            # Run gum choose and capture the output
            gum style --border rounded --border-foreground "#00AFFF" --foreground "#00AFFF" --bold "Restart browser now?"
            local restart_choice=$(gum choose --cursor.foreground "#00AFFF" Yes No)

            # Check the chosen string
            if [[ "$restart_choice" == "Yes" ]]; then
                # User chose Yes
                if pgrep -f zen-twilight > /dev/null; then
                    echo "Restarting Zen Twilight..."
                    pkill -f zen-twilight
                    sleep 1
                    hyprctl dispatch exec '[workspace 11 silent]' zen-twilight
                else
                    echo "Starting Zen Twilight..."
                    hyprctl dispatch exec '[workspace 11 silent]' zen-twilight
                fi
            else
                # User chose No or cancelled
                echo "Browser restart skipped."
            fi
        else
            echo "Zen Twilight not installed."
        fi

        trap - INT # Clear the main INT trap if we are exiting here
        return 0
    fi

    # Main update process
    # # Animated Checking for updates header
    # printf "$(gum style --foreground "#00AFFF" --bold "Checking for updates")"
    # for i in {1..4}; do
    #     sleep 0.3
    #     printf \' .\'
    # done
    # echo \'\'

    # Check for gum for prettier output
    local has_gum=false
    if command -v gum >/dev/null 2>&1; then
        has_gum=true
    fi

    # Get updates in parallel, within a subshell to suppress job control messages
    ( # Start subshell
        # Run checks concurrently with max efficiency
        command -v checkupdates >/dev/null 2>&1 && checkupdates 2>/dev/null > "$pacman_tmp_file" &
        command -v yay >/dev/null 2>&1 && yay -Qua 2>/dev/null > "$aur_tmp_file" &
        command -v flatpak >/dev/null 2>&1 && flatpak remote-ls --updates 2>/dev/null > "$flatpak_tmp_file" &
        wait
    ) # End subshell

    local pacman_updates=()
    local raw_updates="$(<$pacman_tmp_file)"
    if [[ -n "$raw_updates" && "$raw_updates" != *"error:"* ]]; then
            if [[ -n "$filter" ]]; then
                pacman_updates=("${(f)$(grep -i "$filter" <<< "$raw_updates")}")
            else
                pacman_updates=("${(f)raw_updates}")
            fi
        pacman_updates=("${pacman_updates[@]:#}")
    fi

    local aur_updates=()
    # Read from temp file for AUR updates
    local aur_raw_updates="$(<$aur_tmp_file)"
    if [[ -n "$aur_raw_updates" ]]; then
        if [[ -n "$filter" ]]; then
            aur_updates=("${(f)$(echo "$aur_raw_updates" | grep -i "$filter")}")
        else
            aur_updates=("${(f)aur_raw_updates}")
        fi
        aur_updates=("${aur_updates[@]:#}")
    fi

    local flatpak_updates=()
    # Read from temp file for Flatpak updates
    local flatpak_output="$(<$flatpak_tmp_file)"
    if [[ -n "$flatpak_output" && "$flatpak_output" != *"Nothing to do"* ]]; then
        flatpak_output=$(grep -v "^flatpak$" <<< "$flatpak_output" | grep -v "^$")
        if [[ -n "$flatpak_output" ]]; then
            if [[ -n "$filter" ]]; then
                flatpak_updates=("${(f)$(grep -i "$filter" <<< "$flatpak_output")}")
            else
                flatpak_updates=("${(f)flatpak_output}")
            fi
            flatpak_updates=("${flatpak_updates[@]:#}")
        fi
    fi

    # Remove temporary files now that we're done with them
    rm -f "$pacman_tmp_file" "$aur_tmp_file" "$flatpak_tmp_file"
    # Clear the EXIT trap as normal cleanup has occurred
    trap - EXIT

    # Get counts
    local pacman_count=${#pacman_updates[@]}
    local aur_count=${#aur_updates[@]} 
    local flatpak_count=${#flatpak_updates[@]}
    local total_count=$((pacman_count + aur_count + flatpak_count))

    # Show summary
    if [[ "$has_gum" = true ]]; then
        gum style --border rounded --border-foreground "#00FFFF" --foreground "#00FFFF" --bold "Found $total_count updates:" --padding "0 1" --margin 0
        if [[ $pacman_count -gt 0 ]]; then
            echo $(gum style --foreground "#00AFFF" "• Pacman: $pacman_count")
        fi
        if [[ $aur_count -gt 0 ]]; then
            echo $(gum style --foreground "#FF8700" "• AUR: $aur_count")
        fi
        if [[ $flatpak_count -gt 0 ]]; then
            echo $(gum style --foreground "#00FF00" "• Flatpak: $flatpak_count")
        fi
    else
        echo "Found $total_count updates:"
        if [[ $pacman_count -gt 0 ]]; then
            echo "• Pacman: $pacman_count"
        fi
        if [[ $aur_count -gt 0 ]]; then
            echo "• AUR: $aur_count"
        fi
        if [[ $flatpak_count -gt 0 ]]; then
            echo "• Flatpak: $flatpak_count"
        fi
    fi
    echo ""

    # No updates case
    if [[ $total_count -eq 0 ]]; then
        echo "No updates available."
        trap - INT # Clear the main INT trap as we are exiting normally
        return 0
    fi

    # Create numbered list for ALL packages
    local all_updates=()
    local display_list=()
    local item_idx_for_display=0 # Counter for displayed items for exclusion
    
    # Sort pacman updates by repository priority if there are any
    # Sorting logic is active and working.
    if [[ $pacman_count -gt 0 ]]; then
        # Create an array of "priority:repo:package" strings for sorting
        local sortable_pacman_updates=()
        
        for pkg in "${pacman_updates[@]}"; do
            # Extract repository from the package string
            local repo=""
            local pkg_name_for_sort="" # The part used for sorting key

            # Check if the line starts with repo/package format
            if [[ "$pkg" == */* ]]; then
                repo="${pkg%%/*}"
                pkg_name_for_sort="${pkg#*/}" 
                pkg_name_for_sort="${pkg_name_for_sort%% *}" # Get package name after slash
            else
                # Get first word which should be the package name
                local first_word="${pkg%% *}"
                pkg_name_for_sort=$first_word
                
                # Try to get repo from our mapping
                if [[ -n "${pkg_to_repo_map[$first_word]}" ]]; then
                    repo="${pkg_to_repo_map[$first_word]}"
                else
                    # Default based on common system packages or 'extra'
                    if [[ "$pkg_name_for_sort" == "glibc" || "$pkg_name_for_sort" == "linux" || "$pkg_name_for_sort" == "bash" ]]; then
                        repo="core"
                    else
                        repo="extra" # Default to extra if truly unknown
                    fi
                fi
            fi

            # Clean up repo name 
            repo=$(echo "$repo" | fix_repo_display)

            # Get priority for this repo
            local priority=$(get_repo_priority "$repo")

            # Store in format "priority:repo:original_package_string"
            sortable_pacman_updates+=("$priority:$repo:$pkg")
        done

        # Sort numerically based on the priority prefix using print -l and ${(f)...}
        local sorted_lines=("${(f)$(print -l -- "${sortable_pacman_updates[@]}" | sort -t: -k1,1n)}")
        
        # Replace the pacman_updates array with the sorted packages
        pacman_updates=()
        for sorted_entry in "${sorted_lines[@]}"; do
            # Extract the original package string (everything after the second colon)
            local original_pkg=$(echo "$sorted_entry" | cut -d: -f3-)
            # Ensure we add the full original line back, preserving spaces
            pacman_updates+=("$original_pkg")
        done
        # Remove any potential empty entries (shouldn't be needed now, but keep as safeguard)
        pacman_updates=("${pacman_updates[@]:#}")
    fi

    # Add a header for pacman
    if [[ $pacman_count -gt 0 ]]; then
        if [[ "$has_gum" = true ]]; then
            display_list+=("$(gum style --foreground "#00AFFF" --bold "== Pacman Updates ==")")
        else
            display_list+=("== Pacman Updates ==")
        fi
        display_list+=("")
    fi

    # Add pacman packages
    for pkg in "${pacman_updates[@]}"; do
        item_idx_for_display=$((item_idx_for_display + 1))
        local first_word=$(echo "$pkg" | awk '{print $1}')
        local pkg_name_display="$first_word" # Default to the first word
        local repo_color_info=""
        local repo_name_for_display="unknown"
        local color_for_display="#BFBFBF"

        # If checkupdates provided "repo/package", use that
        if [[ "$first_word" == */* ]]; then
            repo_color_info=$(get_package_repo_info "$first_word")
            pkg_name_display="${first_word#*/}" # Get only the package name part
        else
            # Otherwise, it's just "package", get repo info for it
            repo_color_info=$(get_package_repo_info "$first_word")
        fi
        
        repo_name_for_display=$(echo "$repo_color_info" | awk '{print $1}')
        color_for_display=$(echo "$repo_color_info" | awk '{print $2}')

        # Reconstruct the package info line for display
        # The original $pkg line is like "package old_ver -> new_ver" or "repo/package old_ver -> new_ver"
        # We want to display "[REPO] package old_ver -> new_ver"
        local rest_of_line=$(echo "$pkg" | cut -d' ' -f2-) # Get everything after the first word
        local pkg_info="$pkg_name_display $rest_of_line"   # e.g., "btop 1.2.3 -> 1.2.4"

        if [[ "$has_gum" = true ]]; then
            local styled_idx=$(gum style --bold "[$item_idx_for_display]")
            display_list+=("$(printf "%s %s %s" "$styled_idx" "$(gum style --foreground "$color_for_display" "[$repo_name_for_display]")" "$pkg_info")")
        else
            display_list+=("$(printf "[%2d] [%s] %s" "$item_idx_for_display" "$repo_name_for_display" "$pkg_info")")
        fi
        all_updates+=("pacman:$pkg") # Store with type prefix and original line
    done

    # Add a header for AUR
    if [[ $aur_count -gt 0 ]]; then
        if [[ "$has_gum" = true ]]; then
            display_list+=("")
            display_list+=("$(gum style --foreground "#FF8700" --bold "== AUR Updates ==")")
        else
            display_list+=("")
            display_list+=("== AUR Updates ==")
        fi
        display_list+=("")
    fi

    # Add AUR packages
    for pkg in "${aur_updates[@]}"; do
        item_idx_for_display=$((item_idx_for_display + 1))
        local pkg_name_aur=$(echo "$pkg" | awk '{print $1}')
        # AUR packages don't have a repo in the same way, so we'll just use "aur"
        local repo_color_info_aur=$(get_package_repo_info "aur/$pkg_name_aur") # Pass it like this to get AUR color
        local color_for_display_aur=$(echo "$repo_color_info_aur" | awk '{print $2}')

        if [[ "$has_gum" = true ]]; then
            local styled_idx=$(gum style --bold "[$item_idx_for_display]")
            display_list+=("$(printf "%s %s %s" "$styled_idx" "$(gum style --foreground "$color_for_display_aur" "[aur]")" "$pkg")")
        else
            display_list+=("$(printf "[%2d] [aur] %s" "$item_idx_for_display" "$pkg")")
        fi
        all_updates+=("aur:$pkg") # Store with type prefix and original line
    done

    # Add a header for flatpak
    if [[ $flatpak_count -gt 0 ]]; then
        if [[ "$has_gum" = true ]]; then
            display_list+=("$(gum style --foreground "#00FF00" --bold "== Flatpak Updates ==")")
        else
            display_list+=("== Flatpak Updates ==")
        fi
        display_list+=("")
    fi

    # Add flatpak packages
    for pkg in "${flatpak_updates[@]}"; do
        item_idx_for_display=$((item_idx_for_display + 1))
        all_updates+=("flatpak:$pkg") # Already correct

        if [[ "$has_gum" = true ]]; then
            local styled_idx=$(gum style --bold --foreground "#00FF00" "[$item_idx_for_display]")
            local styled_repo=$(gum style --foreground "#00FF00" "flatpak")
            display_list+=("$(printf "%s %-15s %s" "$styled_idx" "$styled_repo" "$pkg")")
        else
            # Format with proper padding
            display_list+=("$(printf "[%2d] %-12s %s" "$item_idx_for_display" "flatpak" "$pkg")")
        fi
    done

    # Show all packages
    echo "Available updates:"
    echo ""
    printf "%s\n" "${display_list[@]}" 
    echo ""

    # Skip if no confirmation needed
    if [[ "$skip_confirm" = false ]]; then
        local exclude_input=$(gum input --placeholder "Exclude numbers (e.g., 1 2 3 or 1-3)")

        local excluded_indices=()

        # Parse exclusion input
        if [[ -n "$exclude_input" ]]; then
            # Use Zsh specific splitting on spaces
            for part in ${(s: :)exclude_input}; do
                if [[ "$part" =~ ^[0-9]+-[0-9]+$ ]]; then
                    # Handle range (e.g., "1-3")
                    local range_start="${part%-*}"
                    local range_end="${part#*-}"
                    # Validate range numbers
                    if [[ "$range_start" =~ ^[0-9]+$ && "$range_end" =~ ^[0-9]+$ && $range_start -le $range_end ]]; then
                        for i in {$range_start..$range_end}; do
                            excluded_indices+=($i)
                        done
                    fi
                elif [[ "$part" =~ ^[0-9]+$ ]]; then
                    # Handle single number
                    excluded_indices+=($part)
                fi
            done
            # Ensure unique indices and sort them numerically
            excluded_indices=("${(@un)excluded_indices}")
        fi

        # Prepare exclude lists
        local pacman_excludes=()
        local aur_excludes=()
        # Flatpak exclusions are not directly supported by the update command

        # Process exclusions
        if [[ ${#excluded_indices[@]} -gt 0 ]]; then
            echo ""
            echo "Excluding packages:"
            local has_flatpak_exclusions=false # Flag to show note later

            for idx in "${excluded_indices[@]}"; do
                # Validate index range
                if [[ $idx -ge 1 && $idx -le ${#all_updates[@]} ]]; then
                    # Get the correct item using 1-based index (Zsh default)
                    local pkg_info="${all_updates[$idx]}"
                    # Extract type (pacman, aur, flatpak)
                    local pkg_type=$(echo "$pkg_info" | cut -d':' -f1)
                    # Extract the rest of the line (package details)
                    local pkg_line=$(echo "$pkg_info" | cut -d':' -f2-)

                    local pkg_name_to_ignore=""
                    local display_type_name=""

                    # Determine package name for --ignore and display type
                    case "$pkg_type" in
                        pacman)
                            # Extract package name (first word) and strip repo prefix
                            local raw_name="$(echo "$pkg_line" | awk '{print $1}')"
                            pkg_name_to_ignore="${raw_name#*/}"
                            pacman_excludes+=("$pkg_name_to_ignore")
                            display_type_name="Pacman"
                            ;;
                        aur)
                            pkg_name_to_ignore="$(echo "$pkg_line" | awk '{print $1}')" # Get package name from the line
                            aur_excludes+=("$pkg_name_to_ignore")
                            display_type_name="AUR"
                            ;;
                        flatpak)
                            # Extract the package name (first word of pkg_line)
                            pkg_name_to_ignore=$(echo "$pkg_line" | awk '{print $1}')
                            display_type_name="Flatpak"
                            has_flatpak_exclusions=true # Mark that a flatpak was selected for exclusion
                                                ;; # Added semicolon
                                            *) # Should not happen
                                                pkg_name_to_ignore="<error>"
                            display_type_name="Unknown"
                                                ;; # Added semicolon
                    esac
                    
                    # Echo the exclusion information clearly
                    echo "• [$idx] $pkg_name_to_ignore ($display_type_name)"
                    # Add note specifically for flatpak exclusions right here
                    if [[ "$pkg_type" == "flatpak" ]]; then
                         echo "    ↳ Note: Exclusion not supported for Flatpak."
                    fi
                    
                else
                     # Inform user about invalid index
                     echo "• [$idx] Not valid package number."
                fi
            done

            # Display the general Flatpak note only once if any Flatpak was selected
            # if [[ "$has_flatpak_exclusions" = true ]]; then
            #     echo ""
            #     echo "⚠️ Note: Exclusions for Flatpak packages are not supported. All Flatpak packages will be updated."
            # fi # Note is now shown per-package
        fi

        # Ask for confirmation with a styled border
        gum style --border rounded --border-foreground "#00AFFF" --foreground "#00AFFF" --bold "Proceed with update?"
        if ! gum confirm \
                --prompt.foreground "#00AFFF" \
                --selected.foreground "#000000" \
                --selected.background "#00AFFF" \
                --unselected.foreground D0D0D0 \
                --unselected.background "#2d2d2d" \
                ""; then
            echo "Update canceled."
            trap - INT # Clear the main INT trap as we are exiting based on user choice
            return 0
        fi
    fi

    # Run updates with exclusions
    echo ""
    echo "Starting update process..."

    # Update pacman/AUR packages
    if [[ $pacman_count -gt 0 || $aur_count -gt 0 ]]; then
        gum style --foreground "#00AFFF" --bold "Updating system packages..."

        local ignore_args=()
        # Combine both pacman and aur excludes for the yay command
        for pkg in "${pacman_excludes[@]}" "${aur_excludes[@]}"; do
            ignore_args+=("--ignore" "$pkg")
        done

        # Check if sudo password is needed (only if not skipping confirm)
        if [[ ${#ignore_args[@]} -gt 0 ]]; then
            if [[ "$skip_confirm" = false ]]; then
                local sudo_pass=$(gum input --password --placeholder "Sudo password")
                printf "%s\n" "$sudo_pass" | sudo -S -v
            else
                sudo -v
            fi
            gum style --foreground "#00AFFF" --bold "Updating system packages..."
            yay -Syu --noconfirm "${ignore_args[@]}"
        else
            if [[ "$skip_confirm" = false ]]; then
                local sudo_pass=$(gum input --password --placeholder "Sudo password")
                printf "%s\n" "$sudo_pass" | sudo -S -v
            else
                sudo -v
            fi
            gum style --foreground "#00AFFF" --bold "Updating system packages..."
            yay -Syu --noconfirm
        fi
    fi

    if [[ $flatpak_count -gt 0 ]]; then
        gum style --foreground "#00AFFF" --bold "Updating Flatpak packages..."
        flatpak update --noninteractive
    fi

    # Clean package caches if requested
    if [[ "$clean_cache" = true ]]; then
        echo "Cleaning package caches..."
        if command -v paccache &>/dev/null; then
            sudo paccache -r
        fi
        if command -v flatpak &>/dev/null; then
            flatpak uninstall --unused
        fi
    fi

    # Calculate elapsed time
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))

    echo ""
    echo "Update completed in $minutes minutes and $seconds seconds."

    # Check for kernel updates with more precise detection
    local kernel_updated=false
    local current_kernel=$(uname -r)
    
    # Use regex pattern matching directly instead of looping through an array
    for pkg in "${pacman_updates[@]}"; do
        local pkg_name="${pkg%% *}"
        pkg_name="${pkg_name#*/}" # Remove repo/ prefix if present
        
        # Match any linux kernel package efficiently
        if [[ "$pkg_name" =~ ^linux(-lts|-zen|-hardened)?$ ]]; then
            kernel_updated=true
            break
        fi
    done

    # More compact conditional
    [[ "$kernel_updated" = true ]] && {
        echo ""
        echo "⚠ Kernel update detected. A system restart is recommended after updating."
    }
}
