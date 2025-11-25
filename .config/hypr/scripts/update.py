#!/usr/bin/python3
import subprocess
import concurrent.futures
import sys
import os
import click

# --- Configuration ---
# Priorities: Lower number = Higher importance (Testing > Core > Extra > AUR)
REPOS = {
    "core-testing":     {"color": "magenta", "abbr": "C-T", "prio": 1},
    "extra-testing":    {"color": "cyan",    "abbr": "E-T", "prio": 2},
    "multilib-testing": {"color": "yellow",  "abbr": "M-T", "prio": 3},
    "core":             {"color": "red",     "abbr": "COR", "prio": 4},
    "extra":            {"color": "green",   "abbr": "EXT", "prio": 5},
    "multilib":         {"color": "yellow",  "abbr": "MUL", "prio": 6},
    "visual-studio-code-insiders": {"color": "blue", "abbr": "VSC", "prio": 7},
    "aur":              {"color": "blue",    "abbr": "AUR", "prio": 50},
    "flatpak":          {"color": "white",   "abbr": "FLT", "prio": 60},
    "unknown":          {"color": "white",   "abbr": "???", "prio": 99}
}

def run_command(cmd):
    """Run a command and return stdout lines."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return [line for line in result.stdout.splitlines() if line]
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []

def build_version_map():
    """
    Map package versions to their repository using pacman -Sl.
    Returns: { "package_name": { "1.0.0-1": "core", "1.0.1-1": "core-testing" } }
    """
    version_map = {}
    try:
        lines = run_command(["pacman", "-Sl"])
        for line in lines:
            parts = line.split()
            if len(parts) >= 3:
                repo = parts[0]
                name = parts[1]
                ver  = parts[2]
                
                if name not in version_map:
                    version_map[name] = {}
                version_map[name][ver] = repo
    except: pass
    return version_map

def fetch_updates():
    """Fetch updates from all sources in parallel."""
    click.secho(":: Fetching updates...", fg="cyan", bold=True)
    
    with concurrent.futures.ThreadPoolExecutor() as executor:
        future_map = executor.submit(build_version_map)
        future_pac = executor.submit(run_command, ["checkupdates"])
        future_aur = executor.submit(run_command, ["yay", "-Qua"])
        # Request clean columns to avoid parsing issues
        future_flat = executor.submit(run_command, ["flatpak", "remote-ls", "--updates", "--columns=application,version"])
        
        return (
            future_map.result(),
            future_pac.result(),
            future_aur.result(),
            future_flat.result()
        )

def parse_updates(version_map, pac_raw, aur_raw, flat_raw):
    updates = []
    
    # Official Repos
    for line in pac_raw:
        try:
            parts = line.split()
            if len(parts) >= 4:
                name = parts[0]
                old_ver = parts[1]
                new_ver = parts[-1]
                
                repo = "core"
                if name in version_map and new_ver in version_map[name]:
                    repo = version_map[name][new_ver]
                elif name in version_map:
                    repo = list(version_map[name].values())[0]

                updates.append({"name": name, "old": old_ver, "new": new_ver, "repo": repo})
        except: continue

    # AUR
    for line in aur_raw:
        try:
            parts = line.split()
            if len(parts) >= 4:
                updates.append({"name": parts[0], "old": parts[1], "new": parts[-1], "repo": "aur"})
        except: continue
    
    # Flatpak
    for line in flat_raw:
        try:
            parts = line.split()
            if parts:
                name = parts[0]
                ver = parts[1] if len(parts) > 1 else ""
                updates.append({"name": name, "old": "", "new": ver, "repo": "flatpak"})
        except: continue
            
    updates.sort(key=lambda x: REPOS.get(x["repo"], REPOS["unknown"])["prio"])
    return updates

def get_category(repo):
    if repo == "flatpak": return "Flatpak"
    if repo == "aur": return "AUR"
    return "Pacman"

def print_summary_box(updates):
    """Prints a summary box at the top, hiding categories with 0 updates."""
    pac_len = len([u for u in updates if get_category(u['repo']) == "Pacman"])
    aur_len = len([u for u in updates if get_category(u['repo']) == "AUR"])
    flt_len = len([u for u in updates if get_category(u['repo']) == "Flatpak"])

    items = []
    if pac_len > 0: items.append(f"Pacman:  {pac_len}")
    if aur_len > 0: items.append(f"AUR:     {aur_len}")
    if flt_len > 0: items.append(f"Flatpak: {flt_len}")
    
    if not items: return

    # Box formatting
    width = max(len(i) for i in items) + 4
    
    click.secho("\n╭" + "─" * width + "╮", fg="bright_white", bold=True)
    for item in items:
        # Simple alignment
        text = item.ljust(width - 4)
        click.secho("│  ", fg="bright_white", bold=True, nl=False)
        
        # Colorize the count part if possible, but splitting by color is tricky 
        # inside a box. Keep it clean white/bold for now or use category color.
        if "Pacman" in item: col = "blue"
        elif "AUR" in item: col = "cyan"
        else: col = "magenta"
        
        click.secho(text, fg=col, bold=True, nl=False)
        click.secho("  │", fg="bright_white", bold=True)
    click.secho("╰" + "─" * width + "╯", fg="bright_white", bold=True)


@click.command()
@click.option("--yes", "-y", is_flag=True, help="Skip confirmation and update all")
def main(yes):
    try:
        subprocess.run(["sudo", "-v"], check=True)
    except subprocess.CalledProcessError:
        click.secho("Authentication failed.", fg="red")
        sys.exit(1)

    version_map, pac, aur, flat = fetch_updates()
    all_updates = parse_updates(version_map, pac, aur, flat)
    
    if not all_updates:
        click.secho("System is up to date!", fg="green", bold=True)
        sys.exit(0)

    click.clear()
    
    # 1. Print Summary Box
    print_summary_box(all_updates)
    
    max_name = max(len(u["name"]) for u in all_updates)
    idx_width = len(str(len(all_updates))) 
    prev_cat = None
    
    # 2. Print List
    for idx, u in enumerate(all_updates, 1):
        cat = get_category(u["repo"])
        if cat != prev_cat:
            if prev_cat: click.echo("") 
            head_col = "blue" if cat == "Pacman" else "magenta" if cat == "Flatpak" else "cyan"
            click.secho(f"── {cat} ──", fg=head_col, bold=True)
            prev_cat = cat

        repo_key = u["repo"]
        if repo_key not in REPOS: repo_key = "unknown"
        style = REPOS[repo_key]
        
        idx_str = click.style(f"[{idx:0{idx_width}d}]", fg="bright_black")
        repo_str = click.style(f"{style['abbr']}", fg=style['color'], bold=True)
        name_str = click.style(u["name"].ljust(max_name), bold=True)
        
        if u["repo"] == "flatpak":
            ver_str = click.style(u["new"], fg="magenta") if u["new"] else ""
        else:
            ver_str = f"{u['old']} -> {click.style(u['new'], fg='green')}"
        
        click.echo(f"{idx_str} {repo_str:<3}  {name_str}  {ver_str}")

    # 3. Selection
    updates_to_run = list(all_updates)
    ignored_names = []

    if not yes:
        click.echo("")
        ignore_input = click.prompt(
            click.style("Enter numbers to ignore (space separated), 'q' to quit, or Enter to update all", fg="cyan"), 
            default="", 
            show_default=False
        )
        
        if ignore_input.strip().lower() in ['q', 'quit', 'exit']:
            click.secho("Exiting.", fg="red")
            sys.exit(0)

        if ignore_input.strip():
            indices = set()
            for part in ignore_input.split():
                if part.isdigit(): indices.add(int(part))
            
            updates_to_run = []
            for idx, u in enumerate(all_updates, 1):
                if idx in indices: ignored_names.append(u["name"])
                else: updates_to_run.append(u)

            if not updates_to_run:
                click.secho("All updates ignored. Exiting.", fg="yellow")
                sys.exit(0)

        if not click.confirm(click.style("\nProceed with update?", bold=True), default=True):
            click.secho("Aborted.", fg="red")
            sys.exit(0)

    sys_pkg_names = [u["name"] for u in updates_to_run if u["repo"] != "flatpak"]
    
    if sys_pkg_names or ignored_names:
        cmd = ["yay", "-Syu", "--noconfirm"]
        
        if ignored_names:
            click.secho(f"\n:: Ignoring: {', '.join(ignored_names)}", fg="yellow")
            cmd.extend(["--ignore", ",".join(ignored_names)])
        
        if sys_pkg_names:
            click.secho(f"\n:: Updating {len(sys_pkg_names)} packages...", fg="blue", bold=True)
            subprocess.call(cmd)

    if any(u["repo"] == "flatpak" for u in updates_to_run):
        click.secho(f"\n:: Updating Flatpaks...", fg="magenta", bold=True)
        subprocess.call(["flatpak", "update", "--noninteractive"])

    if any("linux" in u["name"] for u in updates_to_run):
        click.secho("\n!!! Kernel updated. Reboot recommended. !!!", fg="red", blink=True, bold=True)

if __name__ == "__main__":
    main()