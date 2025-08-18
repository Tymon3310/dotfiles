#!/usr/bin/env zsh
# filepath: ~/dotfiles/.config/zshrc/functions/update.zsh

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
            echo "5"
            ;;
        multilib)
            echo "6"
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

# Function to get color for a specific repository name
get_repo_color() {
    local repo_to_color="$1"
    local color="#BFBFBF" # Default
    case "$repo_to_color" in
        core)               color="#FF5555";;
        core-testing)       color="#FF79C6";;
        extra)              color="#50FA7B";;
        extra-testing)      color="#8BE9FD";;
        multilib)           color="#FFB86C";;
        multilib-testing)   color="#F1FA8C";;
        aur)                color="#FF8700";;
        visual-studio-code-insiders) color="#3EA7FF";;
        *)                  color="#BFBFBF";; # Other repos
    esac
    echo "$color"
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
         : # Placeholder, actual color assignment will be done after this block
    else
        # If still unknown, set repo name explicitly
        repo_name="unknown"
    fi

    # Get color by calling the dedicated function
    color=$(get_repo_color "$repo_name")

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

    # Synchronize package databases
    gum style --foreground "#00AFFF" --bold "Synchronizing package databases..."
    if [[ "$skip_confirm" = true ]]; then
        if ! sudo pacman -Sy --noconfirm > /dev/null 2>&1; then
            gum style --foreground "red" "Error: Failed to synchronize package databases. Update list may be inaccurate."
            # Consider returning 1 or handling error more strictly
        fi
    else
        local sudo_active_check_sync
        sudo -n true 2>/dev/null
        sudo_active_check_sync=$?

        if [[ $sudo_active_check_sync -ne 0 && -t 0 ]]; then # Sudo not active AND interactive TTY
            local sudo_pass_sync
            # Assign and check gum input status in one go
            if sudo_pass_sync=$(gum input --password --placeholder "Sudo password for DB sync" --cursor.foreground "#00AFFF"); then
                # gum input succeeded (user pressed Enter)
                # Now, the check with the obtained password before the pacman -Sy:
                if echo "$sudo_pass_sync" | sudo -S -v &>/dev/null; then
                    # Password is valid (and sudo timestamp refreshed), proceed with pacman -Sy
                    if ! echo "$sudo_pass_sync" | sudo -S pacman -Sy --noconfirm > /dev/null 2>&1; then 
                        gum style --foreground "red" "Error: Failed to synchronize package databases (even after password validation). Update list may be inaccurate."
                    fi
                else
                    # Password was invalid or sudo -S -v failed
                    gum style --foreground "red" "Error: Invalid sudo password or sudo validation failed. DB sync skipped."
                fi
            else
                # gum input failed (e.g., user pressed Esc; Ctrl+C is handled by main trap)
                # gum exits with non-zero status (e.g., 130 for Esc)
                gum style --foreground "yellow" "Password entry cancelled or failed. DB sync skipped."
            fi
        else # Sudo likely active, or non-interactive, or no TTY
            if ! sudo pacman -Sy --noconfirm > /dev/null 2>&1; then
                gum style --foreground "red" "Error: Failed to synchronize package databases. Update list may be inaccurate."
            fi
        fi
    fi
    echo "" # Add a newline for better spacing after sync output

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
    for pkg_line in "${pacman_updates[@]}"; do
        item_idx_for_display=$((item_idx_for_display + 1))
        
        local parts_array=(${(s: :)pkg_line}) 
        local pkg_name_or_spec_from_checkupdates="${parts_array[1]}" # e.g., "blender" or "somerepo/blender"
        local old_version="${parts_array[2]}"
        local arrow="${parts_array[3]}"
        local new_version="${parts_array[4]}" # e.g., "17:4.4.3-2"

        local actual_pkg_name=""
        if [[ "$pkg_name_or_spec_from_checkupdates" == */* ]]; then
            actual_pkg_name="${pkg_name_or_spec_from_checkupdates#*/}"
        else
            actual_pkg_name="$pkg_name_or_spec_from_checkupdates"
        fi

        local determined_repo_name="unknown" 
        local found_sl_repo=""
        
        # Try to find the repo providing the *new_version* of actual_pkg_name from pacman -Sl
        # Input to loop is "repo package version_from_sl"
        while IFS=' ' read -r r p v junk; do
            if [[ "$p" == "$actual_pkg_name" && "$v" == "$new_version" ]]; then
                found_sl_repo="$r"
                break 
            fi
        done < <(pacman -Sl "$actual_pkg_name" 2>/dev/null)
        
        if [[ -n "$found_sl_repo" ]]; then
            determined_repo_name="$found_sl_repo"
            determined_repo_name=$(echo "$determined_repo_name" | fix_repo_display)
        else
            # Fallback: If specific version not found in pacman -Sl 
            # (should be rare if checkupdates found it and pacman -Sl is comprehensive).
            # Use get_package_repo_info, which itself has fallbacks (map, Qi, Si).
            local repo_color_fallback_info=$(get_package_repo_info "$actual_pkg_name")
            determined_repo_name=$(echo "$repo_color_fallback_info" | awk '{print $1}')
            # fix_repo_display is called within get_package_repo_info, so not needed again here for the fallback.
        fi

        # Ensure determined_repo_name is not empty; default to "unknown" if all attempts failed.
        [[ -z "$determined_repo_name" ]] && determined_repo_name="unknown"

        local color_for_display=$(get_repo_color "$determined_repo_name")

        # Construct the display string: "actual_pkg_name old_version -> new_version"
        local pkg_info_for_display="$actual_pkg_name $old_version $arrow $new_version"

        if [[ "$has_gum" = true ]]; then
            local styled_idx=$(gum style --bold "[$item_idx_for_display]")
            display_list+=("$(printf "%s %s %s" "$styled_idx" "$(gum style --foreground "$color_for_display" "[$determined_repo_name]")" "$pkg_info_for_display")")
        else
            display_list+=("$(printf "[%2d] [%s] %s" "$item_idx_for_display" "$determined_repo_name" "$pkg_info_for_display")")
        fi
        all_updates+=("pacman:$pkg_line") # Store with type prefix and original line
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
                    display_list+=("")
            display_list+=("$(gum style --foreground "#00FF00" --bold "== Flatpak Updates ==")")
        else
                    display_list+=("")
            display_list+=("== Flatpak Updates ==")
        fi
        display_list+=("")
    fi

    # Add flatpak packages
    for pkg_line_raw in "${flatpak_updates[@]}"; do
        item_idx_for_display=$((item_idx_for_display + 1))

        # Parse the raw line using Zsh splitting by tab. Handles multi-line content within fields.
        # flatpak remote-ls --updates output fields:
        # 1: Name/Description (can be multi-line, this will be displayed)
        # 2: Application ID (used for exclusion)
        # ...and so on
        local fields_array=("${(ps:\\t:)pkg_line_raw}")
        local flatpak_name_to_display="${fields_array[1]}" # Use the "Name/Description" field for display
        local app_id_for_exclusion="${fields_array[2]}"   # Keep App ID for internal exclusion logic

        # Construct the simplified display string
        local display_pkg_info="$flatpak_name_to_display"

        # Store app_id for potential exclusion logic later.
        # If app_id_for_exclusion is empty (e.g., parsing failed or line format was unexpected for a particular line),
        # fall back to storing the raw line. This helps maintain correct indexing for the exclusion list,
        # though exclusion for such an item might not behave as expected if the app_id is missing.
        if [[ -n "$app_id_for_exclusion" ]]; then
            all_updates+=("flatpak:$app_id_for_exclusion")
        else
            # If App ID is missing, store the raw line but log or handle this case?
            # For now, storing raw line to keep indexing consistent.
            all_updates+=("flatpak:$pkg_line_raw")
        fi

        if [[ "$has_gum" = true ]]; then
            local styled_idx=$(gum style --bold "[$item_idx_for_display]")
            # Display: [idx] [flatpak] Name
            display_list+=("$(printf "%s %s %s" "$styled_idx" "$(gum style --foreground "#00FF00" "[flatpak]")" "$display_pkg_info")")
        else
            # Display: [idx] [flatpak] Name
            display_list+=("$(printf "[%2d] [flatpak] %s" "$item_idx_for_display" "$display_pkg_info")")
        fi
    done

    # Show all packages
    echo "Available updates:"
    echo ""
    printf "%s\n" "${display_list[@]}" 
    echo ""

    # Skip if no confirmation needed
    if [[ "$skip_confirm" = false ]]; then
        local exclude_input=$(gum input --placeholder "Exclude numbers (e.g., 1 2 3 or 1-3)" --cursor.foreground "#00AFFF")

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

        local proceed_with_yay_update=true

        # Check if sudo password is needed for yay
        if [[ "$skip_confirm" = false ]]; then
            local sudo_active_check_yay
            sudo -n true 2>/dev/null
            sudo_active_check_yay=$?

            if [[ $sudo_active_check_yay -ne 0 && -t 0 ]]; then # Sudo not active AND interactive TTY
                local sudo_pass_yay
                if sudo_pass_yay=$(gum input --password --placeholder "Sudo password for system update" --cursor.foreground "#00AFFF"); then
                    # gum input succeeded, now validate the password
                    if ! echo "$sudo_pass_yay" | sudo -S -v &>/dev/null; then
                        gum style --foreground "red" "Error: Invalid sudo password or sudo validation failed. System update skipped."
                        proceed_with_yay_update=false
                    fi
                    # If password was valid, sudo -S -v has refreshed the timestamp.
                else
                    # gum input failed (e.g., user pressed Esc)
                    gum style --foreground "yellow" "Password entry cancelled. System update skipped."
                    proceed_with_yay_update=false
                fi
            fi
            # If sudo was already active (sudo_active_check_yay was 0), or 
            # if it was not active but password was entered and validated, 
            # proceed_with_yay_update remains true.
        else # skip_confirm is true
            # Attempt to refresh sudo timestamp non-interactively.
            # If this fails and sudo is required, yay itself will prompt.
            if ! sudo -v &>/dev/null; then 
                 : # Do nothing, let yay handle its own sudo requirements.
            fi
        fi

        if [[ "$proceed_with_yay_update" = true ]]; then
            local yay_command_args=(-Syu --noconfirm)
            if [[ ${#ignore_args[@]} -gt 0 ]]; then
                yay_command_args+=("${ignore_args[@]}")
            fi
            
            # Execute yay command
            if ! yay "${yay_command_args[@]}"; then
                 gum style --foreground "red" "Error: yay update command failed."
            fi
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
    local updated_kernel=$(pacman -Q linux 2>/dev/null | awk '{print $2}')
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
                echo "$(gum style --foreground "#FF8700" "⚠ Kernel update detected: $pkg_name from version $current_kernel to $updated_kernel")"
                echo "$(gum style --foreground "#FF8700" "A system restart is recommended after updating.")"
                break 2
            fi
        done
    done
}