#!/usr/bin/env zsh
# Function to get repository information for a package using pacman -Si
# Usage: get_package_repo_info "package_name"
get_package_repo_info() {
    local pkg_name="$1"
    local repo_info="unknown #FFFFFF"
    
    if [[ -z "$pkg_name" ]]; then
        echo "$repo_info"
        return 1
    fi
    
    # Try to get repository from pacman database
    local pacman_info
    pacman_info=$(pacman -Si "$pkg_name" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        # Extract repository from the output
        local repo=$(echo "$pacman_info" | grep '^Repository' | cut -d ':' -f 2 | tr -d ' ')
        
        # Set color based on repository
        local color
        case "$repo" in
            core)           color="#FF0000" ;; # Red
            extra)          color="#00AFFF" ;; # Light blue
            multilib)       color="#FF00FF" ;; # Magenta
            *testing*)      color="#FFFF00" ;; # Yellow for testing repos
            *)              color="#FFFFFF" ;; # White default
        esac
        
        repo_info="$repo $color"
    fi
    
    echo "$repo_info"
}
