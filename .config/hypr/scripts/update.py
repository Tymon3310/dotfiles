#!/usr/bin/env python
import time
import click
import subprocess
import threading
import shutil
import re
import os
import sys
from concurrent.futures import ThreadPoolExecutor

# --- Configuration ---

# Based on zsh script's priorities (lower is better) and colors
# Mapped hex codes to click color names
REPOS = {
    "core-testing":         {"priority": 1, "color": "bright_magenta"},
    "extra-testing":        {"priority": 2, "color": "bright_cyan"},
    "multilib-testing":     {"priority": 3, "color": "bright_yellow"},
    "core":                 {"priority": 4, "color": "red"},
    "extra":                {"priority": 5, "color": "bright_green"},
    "multilib":             {"priority": 6, "color": "yellow"},
    "visual-studio-code-insiders": {"priority": 9, "color": "blue"},
    "aur":                  {"priority": 10, "color": "yellow"},
    "flatpak":              {"priority": 11, "color": "green"},
    "unknown":              {"priority": 100, "color": "white"}
}

# Use the more comprehensive list from the zsh script
REBOOT_PACKAGES = ['linux', 'linux-lts', 'linux-zen', 'linux-hardened']


# --- Fancy CLI Helpers ---

def print_summary_box(pac_count, aur_count, flat_count):
    """Prints a styled box with update counts, with correct alignment."""
    total = pac_count + aur_count + flat_count
    title = f" Found {total} Updates "
    
    lines_data = []
    if pac_count > 0:
        lines_data.append({"uncolored": f"• Pacman:  {pac_count}", 
                           "colored": click.style(f"• Pacman:  {pac_count}", fg=REPOS['core']['color'])})
    if aur_count > 0:
        lines_data.append({"uncolored": f"• AUR:     {aur_count}", 
                           "colored": click.style(f"• AUR:     {aur_count}", fg=REPOS['aur']['color'])})
    if flat_count > 0:
        lines_data.append({"uncolored": f"• Flatpak: {flat_count}", 
                           "colored": click.style(f"• Flatpak: {flat_count}", fg=REPOS['flatpak']['color'])})

    if total == 0: return

    # Determine max width. It's the longest of the lines or the title.
    max_line_len = 0
    if lines_data:
        max_line_len = max(len(l['uncolored']) for l in lines_data)
    
    # Use max_line_len for content width, but ensure title isn't wider
    content_width = max(max_line_len, len(title))
    
    # Ensure content_width has the same parity (odd/even) as the title for clean centering
    if content_width % 2 != len(title) % 2:
        content_width += 1

    # Final width for borders ('│ ' + content + ' │')
    box_width = content_width + 4 
    
    # Top border
    # Center title within the available space (box_width - 2)
    top_border_title = click.style(f"{title:─^{box_width-2}}", bold=True)
    top_border = "╭" + top_border_title + "╮"
    bottom_border = "╰" + "─" * (box_width-2) + "╯"
    
    click.secho(top_border, fg='cyan')
    
    # Content lines
    for l in lines_data:
        # Pad each line to match the full content_width
        padding = content_width - len(l['uncolored'])
        click.echo(f"│ {l['colored']}" + " " * padding + " │")
        
    click.secho(bottom_border, fg='cyan')
    click.echo("")


# --- Package Fetching Logic ---

def build_repo_map():
    """
    Builds a {package: repo} map from `pacman -Sl`.
    Must be run AFTER `pacman -Sy`.
    """
    repo_map = {}
    try:
        result = subprocess.run(
            ['pacman', '-Sl'],
            capture_output=True,
            text=True,
            check=True
        )
        populated_pkgs = set()
        for line in result.stdout.strip().split('\n'):
            try:
                repo, package, version, *_ = line.split()
                if package not in populated_pkgs:
                    repo_map[package] = repo
                    populated_pkgs.add(package)
            except ValueError:
                continue
    except subprocess.CalledProcessError as e:
        click.secho(f"Failed to build repo map with 'pacman -Sl': {e.stderr}", fg='red')
    except FileNotFoundError:
        click.secho("pacman command not found.", fg='red')
    return repo_map

def fetch_pacman_updates(repo_map, filter_str):
    """Fetches official repo updates using checkupdates."""
    updates = []
    try:
        result = subprocess.run(
            ['checkupdates'],
            capture_output=True, text=True, check=True
        )
        for line in result.stdout.strip().split('\n'):
            if filter_str and filter_str.lower() not in line.lower():
                continue
            try:
                name, version_old, _, version_new = line.split(' ')
                if '/' in name:
                    repo_from_line, name = name.split('/', 1)
                    repo = repo_from_line
                else:
                    repo = repo_map.get(name, 'unknown')

                updates.append({
                    'type': 'pacman',
                    'repo': repo,
                    'name': name,
                    'version_new': version_new,
                    'version_old': version_old
                })
            except ValueError:
                continue
    except FileNotFoundError:
        click.secho("checkupdates command not found. Skipping pacman updates.", fg='yellow')
    except subprocess.CalledProcessError:
        pass # checkupdates returns non-zero when no updates, which is fine
    return updates

def fetch_aur_updates(filter_str):
    """Fetches AUR updates using yay -Qua."""
    updates = []
    try:
        result = subprocess.run(
            ['yay', '-Qua'],
            capture_output=True, text=True, check=False
        )
        if result.stdout:
            for line in result.stdout.strip().split('\n'):
                if filter_str and filter_str.lower() not in line.lower():
                    continue
                try:
                    name, version_old, _, version_new = line.split(' ')
                    updates.append({
                        'type': 'aur',
                        'repo': 'aur',
                        'name': name,
                        'version_new': version_new,
                        'version_old': version_old
                    })
                except ValueError:
                    continue
    except FileNotFoundError:
        click.secho("yay command not found. Skipping AUR updates.", fg='yellow')
    return updates

def fetch_flatpak_updates(filter_str):
    """Fetches Flatpak updates."""
    updates = []
    try:
        result = subprocess.run(
            ['flatpak', 'remote-ls', '--updates'],
            capture_output=True, text=True, check=False
        )
        if result.stdout:
            for line in result.stdout.strip().split('\n'):
                if not line.strip() or "flatpak" in line:
                    continue
                if filter_str and filter_str.lower() not in line.lower():
                    continue
                try:
                    parts = line.split('\t')
                    name = parts[0]
                    app_id = parts[1]
                    version_new = parts[2]
                    updates.append({
                        'type': 'flatpak',
                        'repo': 'flatpak',
                        'name': name,
                        'app_id': app_id,
                        'version_new': version_new,
                        'version_old': 'N/A'
                    })
                except (ValueError, IndexError):
                    continue
    except FileNotFoundError:
        click.secho("flatpak command not found. Skipping Flatpak updates.", fg='yellow')
    return updates


# --- Exclusion Parsing ---

def parse_exclusions(exclude_input, all_updates_count):
    """Parses exclusion string (e.g., "1 2 5-7") into a set of indices."""
    excluded_indices = set()
    if not exclude_input:
        return excluded_indices, True

    valid_input = True
    for part in exclude_input.split():
        if '-' in part:
            try:
                start, end = map(int, part.split('-'))
                if start > end:
                    click.secho(f"Error: Invalid range '{part}'. Start must be less than end.", fg='red')
                    valid_input = False
                    continue
                for i in range(start, end + 1):
                    if 1 <= i <= all_updates_count:
                        excluded_indices.add(i)
                    else:
                        click.secho(f"Warning: Index {i} is out of range (1-{all_updates_count}).", fg='yellow')
            except ValueError:
                click.secho(f"Error: Invalid range '{part}'.", fg='red')
                valid_input = False
        else:
            try:
                i = int(part)
                if 1 <= i <= all_updates_count:
                    excluded_indices.add(i)
                else:
                    click.secho(f"Warning: Index {i} is out of range (1-{all_updates_count}).", fg='yellow')
            except ValueError:
                click.secho(f"Error: Invalid input '{part}'. Please enter numbers or ranges.", fg='red')
                valid_input = False
    return excluded_indices, valid_input


# --- Main Click Command ---

@click.command('update')
@click.option('-y', '--yes', is_flag=True, help="Skip confirmation prompts")
@click.option('-c', '--clean', is_flag=True, help="Clean package caches after update")
@click.option('-f', '--filter', 'filter_str', default=None, help="Only show packages containing STR")
def cli(yes, clean, filter_str):
    """
    Checks for and applies system updates (Pacman, AUR, Flatpak).
    Shows live output from pacman and yay.
    """
    start_time = time.monotonic()


    # --- 0. Validate Sudo Timestamp ---
    # This is the new "subtle" password prompt
    if not yes:
        click.secho("Refreshing sudo timestamp...", fg='blue', bold=True)
        try:
            # -v (validate) will prompt for a password if the timestamp is expired.
            # We let it run in the foreground to handle the TTY prompt.
            subprocess.run(['sudo', '-v'], check=True)
            click.secho("Sudo credentials validated.", fg='green')
        except subprocess.CalledProcessError:
            click.secho("Sudo validation failed. Please try again.", fg='red')
            return # Exit if they fail the password
        except KeyboardInterrupt:
            click.echo("\nSudo prompt canceled. Exiting.")
            return # Exit if they Ctrl+C
        except FileNotFoundError:
            click.secho("Error: 'sudo' command not found.", fg='red')
            return
        click.echo("") # Add a newline
    
# --- 1. Synchronize Databases ---
    click.secho("Synchronizing package databases...", fg='blue', bold=True)
    sync_command = ['sudo', 'pacman', '-Sy']
    if yes:
        sync_command.append('--noconfirm')
    try:
        # Capture output instead of discarding it
        subprocess.run(sync_command, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        click.secho("Error: Failed to synchronize package databases. Pacman said:", fg='red', bold=True)
        # Print the actual error from pacman
        click.secho(e.stderr, fg='red')
        click.secho("Update list may be inaccurate.", fg='yellow')
        return # Exit if sync fails
    except FileNotFoundError:
        click.secho("Error: 'sudo' or 'pacman' command not found.", fg='red')
        return


    # --- 2. Build Repo Map ---
    repo_map = build_repo_map()

    # --- 3. Fetch Updates in Parallel ---
    with ThreadPoolExecutor(max_workers=3) as executor:
        future_pac = executor.submit(fetch_pacman_updates, repo_map, filter_str)
        future_aur = executor.submit(fetch_aur_updates, filter_str)
        future_flatpak = executor.submit(fetch_flatpak_updates, filter_str)
        pacman_updates = future_pac.result()
        aur_updates = future_aur.result()
        flatpak_updates = future_flatpak.result()

    # --- 4. Show Summary ---
    pacman_count = len(pacman_updates)
    aur_count = len(aur_updates)
    flatpak_count = len(flatpak_updates)
    total_count = pacman_count + aur_count + flatpak_count

    print_summary_box(pacman_count, aur_count, flatpak_count)

    if total_count == 0:
        click.echo("No updates available.")
        return

    # --- 5. Sort and Display Updates ---
    pacman_updates.sort(key=lambda u: REPOS.get(u['repo'], REPOS['unknown'])['priority'])
    
    all_updates_for_exclusion = [] # 1-indexed

    def add_to_lists(updates, header):
        if not updates:
            return
        click.secho(f"\n== {header} ==", fg='cyan', bold=True)
        
        for u in updates:
            idx = len(all_updates_for_exclusion) + 1
            all_updates_for_exclusion.append(u)
            
            repo_info = REPOS.get(u['repo'], REPOS['unknown'])
            repo_name = u['repo']
            repo_color = repo_info['color']
            
            idx_str = click.style(f"[{idx}]", bold=True)
            repo_str = click.style(f"[{repo_name}]", fg=repo_color)
            
            if u['type'] == 'flatpak':
                line = f"{idx_str} {repo_str} {u['name']}"
            else:
                name_str = click.style(u['name'], bold=True)
                old_ver_str = click.style(u['version_old'], fg='bright_black')
                new_ver_str = click.style(u['version_new'], fg='blue')
                line = f"{idx_str} {repo_str} {name_str} {old_ver_str} → {new_ver_str}"
            click.echo(line)

    click.echo("Available updates:\n")
    add_to_lists(pacman_updates, "Pacman Updates")
    add_to_lists(aur_updates, "AUR Updates")
    add_to_lists(flatpak_updates, "Flatpak Updates")
    click.echo("")

    # --- 6. Handle Exclusions & Confirmation ---
    pacman_excludes = []
    aur_excludes = []
    
    if not yes:
        while True:
            click.echo(click.style('╭─ What packages to ignore (eg. 1 2 5-7)', bold=True, fg='blue'))
            exclude_input = click.prompt(click.style('╰─❯ ', bold=True, fg='blue'), default='', show_default=False)
            
            excluded_indices, valid = parse_exclusions(exclude_input, total_count)
            if valid:
                break
        
        if excluded_indices:
            click.echo("Excluding packages:")
            for idx in sorted(list(excluded_indices)):
                try:
                    pkg = all_updates_for_exclusion[idx - 1]
                    pkg_type = pkg['type']
                    name = pkg.get('app_id') if pkg_type == 'flatpak' else pkg['name']
                    
                    if pkg_type == 'pacman':
                        pacman_excludes.append(name)
                    elif pkg_type == 'aur':
                        aur_excludes.append(name)
                    
                    click.echo(f"• [{idx}] {name} ({pkg_type})")
                    if pkg_type == 'flatpak':
                        click.secho("    ↳ Note: Exclusion not supported for Flatpak.", fg='yellow')
                except IndexError:
                    click.secho(f"Error: Index {idx} is out of range.", fg='red')
            click.echo("")

        if not click.confirm(click.style("Proceed with update?", fg='green', bold=True), default=True):
            click.echo("Update canceled.")
            return

    # --- 7. Run Updates ---
    click.echo("\nStarting update process...")

    if pacman_count > 0 or aur_count > 0:
        click.secho("Updating system packages (yay will run)...", fg='blue', bold=True)
        yay_command = ['yay', '-Syu', '--noconfirm']
        ignore_list = pacman_excludes + aur_excludes
        if ignore_list:
            for pkg_name in ignore_list:
                yay_command.extend(['--ignore', pkg_name])
        try:
            # yay will use the sudo timestamp we already validated
            subprocess.run(yay_command, check=True)
        except subprocess.CalledProcessError:
            click.secho("Error: yay update command failed.", fg='red')
        except FileNotFoundError:
            click.secho("yay command not found, cannot update system.", fg='red')

    if flatpak_count > 0:
        click.secho("Updating Flatpak packages...", fg='blue', bold=True)
        try:
            subprocess.run(['flatpak', 'update', '--noninteractive'], check=True)
        except subprocess.CalledProcessError:
            click.secho("Error: flatpak update command failed.", fg='red')
        except FileNotFoundError:
             click.secho("flatpak not found, cannot update flatpaks.", fg='red')

    # --- 8. Clean Caches ---
    if clean:
        click.echo("\nCleaning package caches...")
        if shutil.which('paccache'):
            click.echo("Running paccache...")
            try:
                # paccache will use the sudo timestamp we already validated
                subprocess.run(['sudo', 'paccache', '-r'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                click.echo("paccache complete.")
            except subprocess.CalledProcessError:
                click.secho("Failed to run paccache.", fg='yellow')
        
        if shutil.which('flatpak'):
            click.echo("Cleaning unused flatpak runtimes...")
            try:
                subprocess.run(['flatpak', 'uninstall', '--unused', '--noninteractive'], check=True, stdout=subprocess.DEVNULL)
            except subprocess.CalledProcessError:
                click.secho("Failed to clean flatpak cache.", fg='yellow')

    # --- 9. Final Summary & Reboot Check ---
    end_time = time.monotonic()
    elapsed = end_time - start_time
    minutes, seconds = divmod(elapsed, 60)
    click.secho(f"\nUpdate completed in {int(minutes)} minutes and {int(seconds)} seconds.", bold=True, fg='green')

    updated_package_names = {p['name'] for p in pacman_updates if p['name'] not in pacman_excludes}
    
    kernel_updated = False
    for kernel in REBOOT_PACKAGES:
        if kernel in updated_package_names:
            kernel_updated = True
            click.secho(f"⚠ Kernel update detected: {kernel}", fg='yellow')
            break
            
    if kernel_updated:
        click.secho("A system restart is recommended.", fg='yellow', bold=True)
        if not yes:
            reboot_prompt = click.style(f'WARNING!', fg='red', bold=True) + " an important package has been updated! Do you want to reboot now?"
            if click.confirm(reboot_prompt, default=False):
                click.echo('Rebooting in 5 seconds...')
                time.sleep(5)
                subprocess.run(['reboot'])
            else:
                click.secho('Reboot skipped. Please remember to reboot soon.', bold=True, fg='yellow')


if __name__ == "__main__":
    cli()