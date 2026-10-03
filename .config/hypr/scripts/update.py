#!/usr/bin/python3
import concurrent.futures
import subprocess
import sys
from collections import Counter, defaultdict
import click

# Priorities: Lower number = Higher importance (Testing > Core > Extra > AUR)
REPOS = {
    "core-testing":                {"color": "magenta", "abbr": "C-T", "prio": 1},
    "extra-testing":               {"color": "cyan",    "abbr": "E-T", "prio": 2},
    "multilib-testing":            {"color": "yellow",  "abbr": "M-T", "prio": 3},
    "core":                        {"color": "red",     "abbr": "COR", "prio": 4},
    "extra":                       {"color": "green",   "abbr": "EXT", "prio": 5},
    "multilib":                    {"color": "yellow",  "abbr": "MUL", "prio": 6},
    "visual-studio-code-insiders": {"color": "blue",    "abbr": "VSC", "prio": 7},
    "aur":                         {"color": "blue",    "abbr": "AUR", "prio": 50},
    "flatpak":                     {"color": "white",   "abbr": "FLT", "prio": 60},
    "unknown":                     {"color": "white",   "abbr": "???", "prio": 99},
}

CATEGORIES = {
    "Pacman":  {"color": "blue",    "pad": 2},
    "AUR":     {"color": "cyan",    "pad": 5},
    "Flatpak": {"color": "magenta", "pad": 1},
}


def run_command(cmd):
    """Run a command and return stdout lines."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return [line for line in result.stdout.splitlines() if line]
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []


def build_version_map():
    """Map package versions to their repository using pacman -Sl."""
    version_map = defaultdict(dict)
    for line in run_command(["pacman", "-Sl"]):
        parts = line.split()
        if len(parts) >= 3:
            version_map[parts[1]][parts[2]] = parts[0]
    return version_map


def parse_arrow_line(line):
    """Parse 'pkg old_ver -> new_ver ...' line."""
    parts = line.split()
    if "->" in parts:
        idx = parts.index("->")
        if idx >= 2 and len(parts) > idx + 1:
            return parts[0], parts[idx - 1], parts[idx + 1]
    return None


def fetch_updates():
    """Fetch updates from all sources in parallel."""
    with concurrent.futures.ThreadPoolExecutor() as executor:
        future_map = executor.submit(build_version_map)
        future_pac = executor.submit(run_command, ["checkupdates"])
        future_aur = executor.submit(run_command, ["yay", "-Qua"])
        future_flat = executor.submit(
            run_command, ["flatpak", "remote-ls", "--updates", "--columns=application,version"]
        )

        return (
            future_map.result(),
            future_pac.result(),
            future_aur.result(),
            future_flat.result(),
        )


def get_category(repo):
    if repo == "flatpak":
        return "Flatpak"
    if repo == "aur":
        return "AUR"
    return "Pacman"


def parse_updates(version_map, pac_raw, aur_raw, flat_raw):
    updates = []

    # Official Repos
    for line in pac_raw:
        parsed = parse_arrow_line(line)
        if parsed:
            name, old_ver, new_ver = parsed
            repo_map = version_map.get(name, {})
            repo = repo_map.get(new_ver) or next(iter(repo_map.values()), "core")
            updates.append({"name": name, "old": old_ver, "new": new_ver, "repo": repo})

    # AUR
    for line in aur_raw:
        parsed = parse_arrow_line(line)
        if parsed:
            name, old_ver, new_ver = parsed
            updates.append({"name": name, "old": old_ver, "new": new_ver, "repo": "aur"})

    # Flatpak
    for line in flat_raw:
        parts = line.split()
        if parts:
            name = parts[0]
            ver = parts[1] if len(parts) > 1 else ""
            updates.append({"name": name, "old": "", "new": ver, "repo": "flatpak"})

    updates.sort(key=lambda x: (REPOS.get(x["repo"], REPOS["unknown"])["prio"], x["name"]))
    return updates


def print_summary_box(updates):
    """Prints a summary box at the top."""
    counts = Counter(get_category(u["repo"]) for u in updates)
    items = [
        (cat, f"{cat}:{' ' * meta['pad']}{counts[cat]}", meta["color"])
        for cat, meta in CATEGORIES.items()
        if counts[cat] > 0
    ]

    if not items:
        return

    width = max(len(text) for _, text, _ in items) + 4

    click.secho(f"\n╭{'─' * width}╮", fg="bright_white", bold=True)
    for _, text, color in items:
        click.secho("│  ", fg="bright_white", bold=True, nl=False)
        click.secho(text.ljust(width - 4), fg=color, bold=True, nl=False)
        click.secho("  │", fg="bright_white", bold=True)
    click.secho(f"╰{'─' * width}╯", fg="bright_white", bold=True)


def parse_ignore_indices(user_input):
    """Parse space or comma-separated indices and ranges (e.g. 1 3 5-8)."""
    indices = set()
    for part in user_input.replace(",", " ").split():
        if "-" in part:
            start, _, end = part.partition("-")
            if start.isdigit() and end.isdigit():
                indices.update(range(int(start), int(end) + 1))
        elif part.isdigit():
            indices.add(int(part))
    return indices


@click.command()
@click.option("--yes", "-y", is_flag=True, help="Skip confirmation and update all")
def main(yes):
    try:
        # 1. Sync Databases First (Fixes incorrect repo tagging)
        try:
            click.secho(":: Synchronizing package databases...", fg="cyan", bold=True)
            subprocess.run(["sudo", "pacman", "-Sy"], check=True)
            print("")  # Newline for cleanliness
        except subprocess.CalledProcessError:
            click.secho("Authentication failed or sync error.", fg="red")
            sys.exit(1)

        # 2. Fetch Updates (Now using fresh DB)
        click.secho(":: Fetching updates...", fg="cyan", bold=True)
        version_map, pac, aur, flat = fetch_updates()
        all_updates = parse_updates(version_map, pac, aur, flat)

        if not all_updates:
            click.secho("System is up to date!", fg="green", bold=True)
            sys.exit(0)

        click.clear()

        # 3. Print Summary
        print_summary_box(all_updates)

        max_name = max(len(u["name"]) for u in all_updates)
        idx_width = len(str(len(all_updates)))
        prev_cat = None

        # 4. Print List
        for idx, u in enumerate(all_updates, 1):
            cat = get_category(u["repo"])
            if cat != prev_cat:
                if prev_cat:
                    click.echo("")
                head_col = CATEGORIES.get(cat, {}).get("color", "white")
                click.secho(f"── {cat} ──", fg=head_col, bold=True)
                prev_cat = cat

            style = REPOS.get(u["repo"], REPOS["unknown"])
            idx_str = click.style(f"[{idx:0{idx_width}d}]", fg="bright_black")
            repo_str = click.style(f"{style['abbr']:<3}", fg=style["color"], bold=True)
            name_str = click.style(u["name"].ljust(max_name), bold=True)

            if u["repo"] == "flatpak":
                ver_str = click.style(u["new"], fg="magenta") if u["new"] else ""
            else:
                ver_str = f"{u['old']} -> {click.style(u['new'], fg='green')}"

            click.echo(f"{idx_str} {repo_str}  {name_str}  {ver_str}")

        # 5. Interactive Selection
        updates_to_run = list(all_updates)
        ignored = []

        if not yes:
            click.echo("")
            ignore_input = click.prompt(
                click.style("Enter numbers to ignore (space separated), 'q' to quit, or Enter to update all", fg="cyan"),
                default="",
                show_default=False,
            )

            if ignore_input.strip().lower() in ["q", "quit", "exit"]:
                click.secho("Exiting.", fg="red")
                sys.exit(0)

            if ignore_input.strip():
                indices = parse_ignore_indices(ignore_input)
                ignored = [u for idx, u in enumerate(all_updates, 1) if idx in indices]
                updates_to_run = [u for idx, u in enumerate(all_updates, 1) if idx not in indices]

                if not updates_to_run:
                    click.secho("All updates ignored. Exiting.", fg="yellow")
                    sys.exit(0)

            if not click.confirm(click.style("\nProceed with update?", bold=True), default=True):
                click.secho("Aborted.", fg="red")
                sys.exit(0)

        # 6. Execution
        sys_updates = [u["name"] for u in updates_to_run if u["repo"] != "flatpak"]
        ignored_sys = [u["name"] for u in ignored if u["repo"] != "flatpak"]

        if sys_updates or ignored_sys:
            cmd = ["yay", "-Syu", "--noconfirm"]
            if ignored_sys:
                click.secho(f"\n:: Ignoring: {', '.join(ignored_sys)}", fg="yellow")
                cmd.extend(["--ignore", ",".join(ignored_sys)])

            if sys_updates:
                click.secho(f"\n:: Updating {len(sys_updates)} packages...", fg="blue", bold=True)
                subprocess.run(cmd)

        flatpak_updates = [u["name"] for u in updates_to_run if u["repo"] == "flatpak"]
        if flatpak_updates:
            click.secho("\n:: Updating Flatpaks...", fg="magenta", bold=True)
            ignored_flatpak = any(u["repo"] == "flatpak" for u in ignored)
            flatpak_cmd = ["flatpak", "update"] + (["-y"] + flatpak_updates if ignored_flatpak else ["--noninteractive"])
            subprocess.run(flatpak_cmd)

    except (KeyboardInterrupt, click.Abort):
        click.secho("\nAborted.", fg="red")
        sys.exit(0)


if __name__ == "__main__":
    main()
