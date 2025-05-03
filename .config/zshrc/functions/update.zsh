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
    local pkg_name="$1"
    local repo_name="unknown" # Default repo name
    local color="#BFBFBF"    # Default color

    # Check if package name is empty
    if [[ -z "$pkg_name" ]]; then
        echo "$repo_name $color"
        return 1
    fi

    # Handle packages with slash notation (e.g., extra/btop)
    if [[ "$pkg_name" == */* ]]; then
        repo_name=$(echo "$pkg_name" | cut -d'/' -f1)
        pkg_name=$(echo "$pkg_name" | cut -d'/' -f2)
        # We have the repo name, now determine its color
        case "$repo_name" in
            core)               color="#FF5555";; # Red
            core-testing)       color="#FF79C6";; # Pink
            extra)              color="#50FA7B";; # Green
            extra-testing)      color="#8BE9FD";; # Cyan
            multilib)           color="#FFB86C";; # Orange
            multilib-testing)   color="#F1FA8C";; # Yellow
            aur)                color="#FF8700";; # AUR Orange
            visual-studio-code-insiders) color="#3EA7FF";; # VS Code Blue
            *)                  color="#BFBFBF";; # Light gray for others
        esac
        echo "$repo_name $color"
        return 0 # Found repo from prefix, no need to query pacman
    fi

    # Query pacman database for repository info if not found via prefix
    local repo_info=$(pacman -Si "$pkg_name" 2>/dev/null | grep "Repository" | awk '{print $3}' | tr -d '[:space:]')

    # If not found in standard repos, check if it's installed and get info
    if [[ -z "$repo_info" ]]; then
        local db_info=$(pacman -Qi "$pkg_name" 2>/dev/null | grep "Repository" | awk '{print $3}' | tr -d '[:space:]')
        if [[ -n "$db_info" ]]; then
            repo_info=$db_info
        else
            # Try to get info from pacman -Ss as a fallback (less reliable)
            local ss_info=$(pacman -Ss "^$pkg_name\$" 2>/dev/null | head -n1 | awk -F/ '{print $1}' | tr -d '[:space:]')
            if [[ -n "$ss_info" ]]; then
                 repo_info=$ss_info
            fi
        fi
    fi

    # Make sure we only get one repo name
    repo_name=$(echo "$repo_info" | head -n1 | tr -d '[:space:]')

    # Fix any combined testing repo formats (e.g., "core-testingcore")
    repo_name=$(echo "$repo_name" | fix_repo_display)

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
    # Set up signal handler for SIGINT (Ctrl+C)
    trap 'echo ""; echo "Update canceled by user."; return 1' INT

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
            # Run gum choose directly and check exit status
            gum style --border rounded --border-foreground "#00AFFF" --foreground "#00AFFF" --bold "Restart browser now?"
            if gum choose --cursor.foreground "#00AFFF" Yes No; then
                # User chose Yes (exit status 0)
                if pgrep -f zen-twilight > /dev/null; then
                    echo "Restarting Zen Twilight..."
                    pkill -f zen-twilight
                    sleep 1
                    hyprctl dispatch exec '[workspace 11 silent]' zen-twilight
                else
                    echo "Starting Zen Twilight..."
                    hyprctl dispatch exec '[workspace 11 silent]' zen-twilight
                fi
            fi
        else
            echo "Zen Twilight not installed."
        fi

        return 0
    fi

    # Main update process
    # # Animated Checking for updates header
    # printf "$(gum style --foreground "#00AFFF" --bold "Checking for updates")"
    # for i in {1..4}; do
    #     sleep 0.3
    #     printf ' .'
    # done
    # echo ''

    # Check for gum for prettier output
    local has_gum=false
    if command -v gum >/dev/null 2>&1; then
        has_gum=true
    fi

    # Get updates
    local pacman_updates=()
    local raw_updates=""

    if command -v checkupdates >/dev/null 2>&1; then
        # Get the raw update output first
        raw_updates=$(checkupdates 2>/dev/null)

        # Process the raw output
        if [[ -n "$raw_updates" ]]; then
            if [[ -n "$filter" ]]; then
                 # Filter if needed
                 pacman_updates=("${(f)$(echo "$raw_updates" | grep -i "$filter")}")
            else
                 # Assign directly
                 pacman_updates=("${(f)raw_updates}")
            fi
            # Remove empty entries just in case
            pacman_updates=("${pacman_updates[@]:#}")
        fi
    elif command -v pacman >/dev/null 2>&1; then
        # Regular pacman fallback
        pacman_updates=("${(f)$(pacman -Qu 2>/dev/null | grep -i "$filter")}")
        # Remove empty entries
        pacman_updates=("${pacman_updates[@]:#}")
    fi

    local aur_updates=()
    if command -v yay >/dev/null 2>&1; then
        aur_updates=("${(f)$(yay -Qua 2>/dev/null | grep -i "$filter")}")
        # Remove empty entries
        aur_updates=("${aur_updates[@]:#}")
    fi

    local flatpak_updates=()
    if command -v flatpak >/dev/null 2>&1; then
        # Check if there are actual updates available by parsing the output properly
        local flatpak_output=$(flatpak remote-ls --updates 2>/dev/null)
        
        # Skip if the output is empty or contains "Nothing to do"
        if [[ -n "$flatpak_output" && "$flatpak_output" != *"Nothing to do"* ]]; then
            # Filter out lines that just contain "flatpak" or are empty
            flatpak_output=$(echo "$flatpak_output" | grep -v "^flatpak$" | grep -v "^$")
            
            if [[ -n "$flatpak_output" ]]; then
                # Filter the output if needed
                if [[ -n "$filter" ]]; then
                    flatpak_updates=("${(f)$(echo "$flatpak_output" | grep -i "$filter")}")
                else
                    flatpak_updates=("${(f)flatpak_output}")
                fi
                # Remove empty entries
                flatpak_updates=("${flatpak_updates[@]:#}")
            fi
        fi
    fi

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
        return 0
    fi

    # Create numbered list for ALL packages
    local all_updates=()
    local display_list=()
    
    # Sort pacman updates by repository priority if there are any
    # <<< BEGIN TEMPORARY DISABLE SORTING >>>
    if [[ $pacman_count -gt 0 ]]; then
        # Create an array of "priority:repo:package" strings for sorting
        local sortable_pacman_updates=()
        
        for pkg in "${pacman_updates[@]}"; do
            # Extract repository from the package string
            local repo=""
            local pkg_name_for_sort="" # The part used for sorting key

            # Check if the line starts with repo/package format
            if [[ "$pkg" == */* ]]; then
                repo=$(echo "$pkg" | cut -d'/' -f1)
                pkg_name_for_sort=$(echo "$pkg" | cut -d'/' -f2- | awk '{print $1}') # Get package name after slash
            else
                # Assume regular format: "package version -> new_version"
                # Try to get repo info using the function
                local first_word=$(echo "$pkg" | awk '{print $1}')
                local repo_info=$(get_package_repo_info "$first_word") # Use first word which should be pkg name
                repo=$(echo "$repo_info" | awk '{print $1}')
                pkg_name_for_sort=$first_word

                # If repo is unknown after extraction, use a default
                if [[ "$repo" == "unknown" ]]; then
                    # Default based on common system packages or 'extra'
                    if [[ "$pkg_name_for_sort" == "glibc" || "$pkg_name_for_sort" == "linux" || "$pkg_name_for_sort" == "bash" ]]; then
                        repo="core"
                    else
                        repo="extra" # Default to extra if truly unknown
                    fi
                fi
            fi

            # Clean up repo name (e.g., fix "core-testingcore")
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
    # <<< END TEMPORARY DISABLE SORTING >>>

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
        all_updates+=("pacman:$pkg")
        local idx=${#all_updates[@]}

        # Handle both regular and testing repo packages
        local repo=""
        local repo_color=""
        local pkg_info="$pkg" # Start with the full original line
        local pkg_name=""

        # Check if this line uses the repo/package format
        if [[ "$pkg" == */* ]]; then
            # Extract repo and actual package name from the prefix
            repo=$(echo "$pkg" | cut -d'/' -f1)
            local actual_pkg_name=$(echo "$pkg" | cut -d'/' -f2 | awk '{print $1}') # Get name after slash
            # Reconstruct the display string without the repo prefix
            pkg_info=$(echo "$pkg" | sed "s~^[^ ]* ~~") # Remove the first word (repo/package) and space
            pkg_name=$actual_pkg_name

            # Get color based on the extracted repo name
            case "$repo" in
                 core)               repo_color="#FF5555";; # Red
                 core-testing)       repo_color="#FF79C6";; # Pink
                 extra)              repo_color="#50FA7B";; # Green
                 extra-testing)      repo_color="#8BE9FD";; # Cyan
                 multilib)           repo_color="#FFB86C";; # Orange
                 multilib-testing)   repo_color="#F1FA8C";; # Yellow
                 visual-studio-code-insiders) repo_color="#3EA7FF";; # VS Code Blue
                 *)                  repo_color="#BFBFBF";; # Light gray
            esac
        else
            # Regular package handling (assume no repo prefix in the line)
            # The repo should have been determined during sorting, but we might need to re-fetch color
            pkg_name=$(echo "$pkg" | awk '{print $1}') # Get the package name (first word)

            # Get repository info and color using the function
            local repo_info_result=$(get_package_repo_info "$pkg_name")
            repo=$(echo "$repo_info_result" | awk '{print $1}')
            repo_color=$(echo "$repo_info_result" | awk '{print $2}')

            # If repo is still unknown, assign defaults
            if [[ "$repo" == "unknown" ]]; then
                 if [[ "$pkg_name" == "glibc" || "$pkg_name" == "linux" || "$pkg_name" == "bash" ]]; then
                     repo="core"
                     repo_color="#FF5555"
                 else
                     repo="extra"
                     repo_color="#50FA7B"
                 fi
            fi
            # pkg_info remains the original $pkg line
        fi

        if [[ "$has_gum" = true ]]; then
            # Format with gum styling
            local styled_idx=$(gum style --foreground "#00AFFF" --bold "[$idx]")
            # Apply proper color based on repo type
            local styled_repo=$(gum style --foreground "$repo_color" "$repo")
            # Use pkg_info instead of pkg for testing repos
            display_list+=("$(printf "%s %-15s %s" "$styled_idx" "$styled_repo" "$pkg_info")")
        else
            # Format as a single line with proper padding
            display_list+=("$(printf "%-5s %-12s %s" "[$idx]" "$repo" "$pkg_info")")
        fi
    done

    # Add a separator after pacman
    if [[ $pacman_count -gt 0 ]]; then
        display_list+=("")
    fi

    # Add a header for AUR
    if [[ $aur_count -gt 0 ]]; then
        if [[ "$has_gum" = true ]]; then
            display_list+=("$(gum style --foreground "#FF8700" --bold "== AUR Updates ==")")
        else
            display_list+=("== AUR Updates ==")
        fi
        display_list+=("")
    fi

    # Add AUR packages
    for pkg in "${aur_updates[@]}"; do
        all_updates+=("aur:$pkg")
        local idx=${#all_updates[@]}

        if [[ "$has_gum" = true ]]; then
            # Format AUR packages similar to pacman packages
            local styled_idx=$(gum style --foreground "#FF8700" --bold "[$idx]")
            local styled_repo=$(gum style --foreground "#FF8700" "aur")
            display_list+=("$(printf "%s %-15s %s" "$styled_idx" "$styled_repo" "$pkg")")
        else
            # Format with proper padding
            display_list+=("$(printf "%-5s %-12s %s" "[$idx]" "aur" "$pkg")")
        fi
    done

    # Add a separator after AUR
    if [[ $aur_count -gt 0 ]]; then
        display_list+=("")
    fi

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
        all_updates+=("flatpak:$pkg")
        local idx=${#all_updates[@]}

        if [[ "$has_gum" = true ]]; then
            # Format Flatpak packages similar to pacman packages
            local styled_idx=$(gum style --foreground "#00FF00" --bold "[$idx]")
            local styled_repo=$(gum style --foreground "#00FF00" "flatpak")
            display_list+=("$(printf "%s %-15s %s" "$styled_idx" "$styled_repo" "$pkg")")
        else
            # Format with proper padding
            display_list+=("$(printf "%-5s %-12s %s" "[$idx]" "flatpak" "$pkg")")
        fi
    done

    # Show all packages
    echo "Available updates:"
    echo ""
    for line in "${display_list[@]}"; do
        echo "$line" | fix_repo_display
    done
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
                    local range_start=$(echo "$part" | cut -d'-' -f1)
                    local range_end=$(echo "$part" | cut -d'-' -f2)
                    # Validate range numbers
                    if [[ "$range_start" =~ ^[0-9]+$ && "$range_end" =~ ^[0-9]+$ && $range_start -le $range_end ]]; then
                        for i in $(seq $range_start $range_end); do
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
                                                pkg_name_to_ignore=$(echo "$pkg_line" | awk '{print $2}')
                                                pacman_excludes+=("$pkg_name_to_ignore")
                                                display_type_name="Pacman"
                                                ;; # Added semicolon
                                            aur)
                                                pkg_name_to_ignore=$(echo "$pkg_line" | awk '{print $2}')
                                                aur_excludes+=("$pkg_name_to_ignore")
                                                display_type_name="AUR"
                                                ;; # Added semicolon
                                            flatpak)
                                                pkg_name_to_ignore=$(echo "$pkg_line" | awk '{print $2}')
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
    local current_kernel=$(pacman -Q linux 2>/dev/null | awk '{print $2}' || echo "unknown")
    local kernel_packages=("linux" "linux-lts" "linux-zen" "linux-hardened")

    for pkg in "${pacman_updates[@]}"; do
        local pkg_name=$(echo "$pkg" | awk '{print $1}')
        # Handle packages with slash notation (e.g., extra/linux)
        if [[ "$pkg_name" == */* ]]; then
            pkg_name=$(echo "$pkg_name" | cut -d'/' -f2)
        fi
        
        # Check if it's one of the main kernel packages (exact match)
        for kpkg in "${kernel_packages[@]}"; do
            if [[ "$pkg_name" == "$kpkg" ]]; then
                kernel_updated=true
                echo ""
                echo "⚠ Kernel update detected: $pkg_name from version $current_kernel"
                echo "A system restart is recommended after updating."
                break 2
            fi
        done
    done

    # Reset the trap
    trap - INT
}
