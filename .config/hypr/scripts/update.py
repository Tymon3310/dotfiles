#!/usr/bin/python3
import concurrent.futures
import os
import subprocess
import sys
from collections import Counter, defaultdict
import click

# Priorities: Lower number = Higher importance (Testing > Core > Extra > AUR)
REPOS = {
    "core-testing":                ("magenta", "C-T", 1),
    "extra-testing":               ("cyan",    "E-T", 2),
    "multilib-testing":            ("yellow",  "M-T", 3),
    "core":                        ("red",     "COR", 4),
    "extra":                       ("green",   "EXT", 5),
    "multilib":                    ("yellow",  "MUL", 6),
    "visual-studio-code-insiders": ("blue",    "VSC", 7),
    "aur":                         ("blue",    "AUR", 50),
    "flatpak":                     ("white",   "FLT", 60),
}
DEFAULT_REPO = ("white", "???", 99)
CATEGORIES = {"Pacman": "blue", "AUR": "cyan", "Flatpak": "magenta"}


def get_category(repo):
    return "Flatpak" if repo == "flatpak" else "AUR" if repo == "aur" else "Pacman"


def run_command(cmd, ok_codes=(0,)):
    """Run a command and return stdout lines."""
    try:
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode in ok_codes:
            return res.stdout.splitlines()
        err = res.stderr.strip().splitlines()
        msg = f": {err[-1]}" if err else ""
        click.secho(f"warning: '{' '.join(cmd[:2])}' failed ({res.returncode}){msg}", fg="yellow", err=True)
    except FileNotFoundError:
        click.secho(f"warning: '{cmd[0]}' not found, skipping", fg="yellow", err=True)
    return []


def build_version_map(target_pkgs):
    """Map package versions to their repository using pacman -Sl."""
    if not target_pkgs:
        return {}
    tmp_db = os.environ.get("CHECKUPDATES_DB") or f"/tmp/checkup-db-{os.getuid()}"
    cmd = ["pacman", "-Sl"] + (["--dbpath", tmp_db] if os.path.isdir(tmp_db) else [])
    vmap = defaultdict(dict)
    for line in run_command(cmd):
        parts = line.split()
        if len(parts) >= 3 and parts[1] in target_pkgs:
            vmap[parts[1]][parts[2]] = parts[0]
    return vmap


def parse_arrow_line(line):
    """Parse 'pkg old_ver -> new_ver ...' line."""
    parts = line.split()
    try:
        idx = parts.index("->")
        if idx >= 2 and len(parts) > idx + 1:
            return parts[0], parts[idx - 1], parts[idx + 1]
    except ValueError:
        pass


def fetch_updates():
    """Fetch updates from all sources in parallel."""
    with concurrent.futures.ThreadPoolExecutor() as ex:
        f_pac = ex.submit(run_command, ["checkupdates"], (0, 2))
        f_aur = ex.submit(run_command, ["yay", "-Qua"], (0, 1))
        f_flat = ex.submit(run_command, ["flatpak", "remote-ls", "--updates", "--columns=application,branch,version,commit"])
        f_flat_inst = ex.submit(run_command, ["flatpak", "list", "--columns=application,branch,version,active"])

        pac = f_pac.result()
        targets = {p[0] for line in pac if (p := parse_arrow_line(line))}
        return build_version_map(targets), pac, f_aur.result(), f_flat.result(), f_flat_inst.result()


def parse_updates(version_map, pac_raw, aur_raw, flat_raw, flat_inst_raw):
    updates = []
    for line in pac_raw:
        if p := parse_arrow_line(line):
            vmap = version_map.get(p[0], {})
            updates.append({"name": p[0], "old": p[1], "new": p[2], "repo": vmap.get(p[2]) or next(iter(vmap.values()), "core")})

    for line in aur_raw:
        if p := parse_arrow_line(line):
            updates.append({"name": p[0], "old": p[1], "new": p[2], "repo": "aur"})

    flat_inst = {(p[0], p[1]): (p[2] if len(p) > 2 else "", p[3] if len(p) > 3 else "") for line in flat_inst_raw if len(p := line.split("\t")) >= 2}

    for line in flat_raw:
        if (p := line.split("\t")) and p[0]:
            app, branch = p[0], p[1] if len(p) > 1 else ""
            new_v, new_c = p[2] if len(p) > 2 else "", p[3] if len(p) > 3 else ""
            old_v, old_c = flat_inst.get((app, branch), ("", ""))
            old_str, new_str = old_v, new_v
            if (not old_v and not new_v) or (old_v == new_v and old_c != new_c):
                c1, c2 = old_c[:7], new_c[:7]
                old_str, new_str = f"{old_v} [{c1}]" if old_v else c1, f"{new_v} [{c2}]" if new_v else c2
            updates.append({"name": app, "old": old_str, "new": new_str, "repo": "flatpak"})

    updates.sort(key=lambda x: (REPOS.get(x["repo"], DEFAULT_REPO)[2], x["name"]))
    return updates


def print_summary_box(updates):
    """Prints a summary box at the top."""
    counts = Counter(get_category(u["repo"]) for u in updates)
    items = [(f"{cat + ':':<8} {counts[cat]}", col) for cat, col in CATEGORIES.items() if counts[cat] > 0]
    if not items:
        return

    w = max(len(t) for t, _ in items) + 4
    click.secho(f"\n╭{'─' * w}╮", fg="bright_white", bold=True)
    for text, color in items:
        click.secho("│  ", fg="bright_white", bold=True, nl=False)
        click.secho(text.ljust(w - 4), fg=color, bold=True, nl=False)
        click.secho("  │", fg="bright_white", bold=True)
    click.secho(f"╰{'─' * w}╯", fg="bright_white", bold=True)


def parse_ignore_indices(user_input):
    """Parse space or comma-separated indices and ranges (e.g. 1 3 5-8)."""
    indices = set()
    for part in user_input.replace(",", " ").split():
        if "-" in part:
            s, _, e = part.partition("-")
            if s.isdigit() and e.isdigit():
                indices.update(range(min(int(s), int(e)), max(int(s), int(e)) + 1))
        elif part.isdigit():
            indices.add(int(part))
    return indices


@click.command()
@click.option("--yes", "-y", is_flag=True, help="Skip confirmation and update all")
def main(yes):
    try:
        click.secho(":: Fetching updates...", fg="cyan", bold=True)
        all_updates = parse_updates(*fetch_updates())
        if not all_updates:
            click.secho("System is up to date!", fg="green", bold=True)
            sys.exit(0)

        click.clear()
        print_summary_box(all_updates)

        max_name = max(len(u["name"]) for u in all_updates)
        idx_w = len(str(len(all_updates)))
        prev_cat = None

        for idx, u in enumerate(all_updates, 1):
            cat = get_category(u["repo"])
            if cat != prev_cat:
                if prev_cat:
                    click.echo("")
                click.secho(f"── {cat} ──", fg=CATEGORIES.get(cat, "white"), bold=True)
                prev_cat = cat

            color, abbr, _ = REPOS.get(u["repo"], DEFAULT_REPO)
            idx_str = click.style(f"[{idx:0{idx_w}d}]", fg="bright_black")
            repo_str = click.style(f"{abbr:<3}", fg=color, bold=True)
            name_str = click.style(u["name"].ljust(max_name), bold=True)
            ver_str = f"{u['old']} -> {click.style(u['new'], fg='green')}" if u["old"] else click.style(u["new"], fg="magenta")
            click.echo(f"{idx_str} {repo_str}  {name_str}  {ver_str}")

        updates_to_run, ignored = list(all_updates), []
        if not yes:
            click.echo("")
            val = click.prompt(click.style("Enter numbers to ignore, 'q' to quit, or Enter to update all", fg="cyan"), default="", show_default=False).strip()
            if val.lower() in {"q", "quit", "exit"}:
                sys.exit(0)
            if val:
                idx_set = parse_ignore_indices(val)
                ignored = [u for i, u in enumerate(all_updates, 1) if i in idx_set]
                updates_to_run = [u for i, u in enumerate(all_updates, 1) if i not in idx_set]
                if not updates_to_run:
                    click.secho("All updates ignored. Exiting.", fg="yellow")
                    sys.exit(0)
            if not click.confirm(click.style("\nProceed with update?", bold=True), default=True):
                click.secho("Aborted.", fg="red")
                sys.exit(0)

        sys_pkgs = [u["name"] for u in updates_to_run if u["repo"] != "flatpak"]
        ign_sys = [u["name"] for u in ignored if u["repo"] != "flatpak"]
        if sys_pkgs:
            cmd = ["yay", "-Syu", "--noconfirm"]
            if ign_sys:
                click.secho(f"\n:: Ignoring: {', '.join(ign_sys)}", fg="yellow")
                cmd.extend(["--ignore", ",".join(ign_sys)])
            click.secho(f"\n:: Updating {len(sys_pkgs)} packages...", fg="blue", bold=True)
            subprocess.run(cmd)

        flat_pkgs = [u["name"] for u in updates_to_run if u["repo"] == "flatpak"]
        if flat_pkgs:
            click.secho("\n:: Updating Flatpaks...", fg="magenta", bold=True)
            ign_flat = any(u["repo"] == "flatpak" for u in ignored)
            subprocess.run(["flatpak", "update", "-y"] + (flat_pkgs if ign_flat else []))

    except (KeyboardInterrupt, click.Abort):
        click.secho("\nAborted.", fg="red")
        sys.exit(0)


if __name__ == "__main__":
    main()
