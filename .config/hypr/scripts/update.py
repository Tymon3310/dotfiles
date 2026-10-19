#!/usr/bin/python3
"""System update helper: pacman, AUR and Flatpak in one list.

    update              list everything, pick what to skip, update
    update -y           update everything without asking
    update --check      list only; exit 0 if updates exist, 2 if none

    update --orphans    also offer to remove orphaned packages afterwards
    update --pacnew     also list .pacnew/.pacsave files to merge afterwards

Before updating it shows Arch news posted since the last full upgrade (the
"manual intervention" notices). Afterwards it reports each stage and whether
a reboot is due. --orphans and --pacnew run even when nothing needs updating.
"""

import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
import urllib.request
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

import click

# Repo -> (colour, short tag, sort priority). Lower sorts first.
REPOS = {
    "core-testing": ("magenta", "C-T", 1),
    "extra-testing": ("cyan", "E-T", 2),
    "multilib-testing": ("yellow", "M-T", 3),
    "core": ("red", "COR", 4),
    "extra": ("green", "EXT", 5),
    "multilib": ("yellow", "MUL", 6),
    "visual-studio-code-insiders": ("blue", "VSC", 7),
    "aur": ("blue", "AUR", 50),
    "flatpak": ("white", "FLT", 60),
}
DEFAULT_REPO = ("white", "???", 99)
CATEGORIES = {"Pacman": "blue", "AUR": "cyan", "Flatpak": "magenta"}

# Updating any of these means the running system is out of date until a reboot.
REBOOT_PACKAGES = re.compile(
    r"^(linux(-[a-z0-9]+)*|linux-firmware.*|.*-ucode|systemd|glibc|mesa|nvidia.*|xe-.*|intel-.*-driver)$"
)

NEWS_FEED = "https://archlinux.org/feeds/news/"
PACMAN_LOG = "/var/log/pacman.log"


@dataclass
class Update:
    name: str
    old: str
    new: str
    repo: str

    @property
    def category(self) -> str:
        return "Flatpak" if self.repo == "flatpak" else "AUR" if self.repo == "aur" else "Pacman"

    @property
    def sort_key(self):
        return (REPOS.get(self.repo, DEFAULT_REPO)[2], self.name)


# ── helpers ──────────────────────────────────────────────────────────────────

def warn(text: str) -> None:
    click.secho(f"warning: {text}", fg="yellow", err=True)


def run(cmd: list[str], ok_codes=(0,)) -> list[str]:
    """Run a command quietly and return its stdout lines ([] on failure)."""
    if not shutil.which(cmd[0]):
        return []
    try:
        res = subprocess.run(cmd, capture_output=True, text=True)
    except OSError as error:
        warn(f"'{cmd[0]}' failed to start: {error}")
        return []
    if res.returncode in ok_codes:
        return res.stdout.splitlines()
    last = res.stderr.strip().splitlines()
    warn(f"'{' '.join(cmd[:2])}' exited {res.returncode}" + (f": {last[-1]}" if last else ""))
    return []


def heading(text: str, color: str = "cyan") -> None:
    click.secho(f"\n:: {text}", fg=color, bold=True)


# ── gathering ────────────────────────────────────────────────────────────────

def parse_arrow(line: str):
    """'pkg old -> new' (checkupdates, yay -Qua) -> (pkg, old, new)."""
    parts = line.split()
    if "->" in parts:
        i = parts.index("->")
        if i >= 2 and len(parts) > i + 1:
            return parts[0], parts[i - 1], parts[i + 1]
    return None


def repo_map(names: set[str]) -> dict[str, dict[str, str]]:
    """Package -> {version: repo}, from the database checkupdates synced."""
    if not names:
        return {}
    db = os.environ.get("CHECKUPDATES_DB") or os.path.join(
        os.environ.get("TMPDIR", "/tmp"), f"checkup-db-{os.getuid()}"
    )
    cmd = ["pacman", "-Sl"] + (["--dbpath", db] if os.path.isdir(db) else [])
    found = defaultdict(dict)
    for line in run(cmd):
        parts = line.split()
        if len(parts) >= 3 and parts[1] in names:
            found[parts[1]][parts[2]] = parts[0]
    return found


def pacman_updates() -> list[Update]:
    lines = run(["checkupdates"], ok_codes=(0, 2))
    parsed = [p for line in lines if (p := parse_arrow(line))]
    repos = repo_map({p[0] for p in parsed})
    out = []
    for name, old, new in parsed:
        versions = repos.get(name, {})
        repo = versions.get(new) or next(iter(versions.values()), "core")
        out.append(Update(name, old, new, repo))
    return out


def aur_updates() -> list[Update]:
    return [Update(p[0], p[1], p[2], "aur")
            for line in run(["yay", "-Qua"], ok_codes=(0, 1)) if (p := parse_arrow(line))]


def flatpak_updates() -> list[Update]:
    cols = "--columns=application,branch,version,commit"
    pending = run(["flatpak", "remote-ls", "--updates", cols])
    if not pending:
        return []
    installed = {}
    for line in run(["flatpak", "list", "--columns=application,branch,version,active"]):
        p = line.split("\t") + ["", "", "", ""]
        installed[(p[0], p[1])] = (p[2], p[3])
    out = []
    for line in pending:
        p = line.split("\t") + ["", "", "", ""]
        app, branch, new_v, new_c = p[:4]
        if not app:
            continue
        old_v, old_c = installed.get((app, branch), ("", ""))
        # Same version string but a new commit: show the commits instead.
        if (not old_v and not new_v) or (old_v == new_v and old_c != new_c):
            old_v = f"{old_v} [{old_c[:7]}]".strip() if old_c else old_v
            new_v = f"{new_v} [{new_c[:7]}]".strip() if new_c else new_v
        out.append(Update(app, old_v, new_v, "flatpak"))
    return out


def last_full_upgrade() -> datetime | None:
    """When pacman last ran a full system upgrade, from its log."""
    try:
        with open(PACMAN_LOG, errors="replace") as log:
            stamp = None
            for line in log:
                if "starting full system upgrade" in line:
                    stamp = line[1:line.index("]")]
    except OSError:
        return None
    if not stamp:
        return None
    try:
        return datetime.fromisoformat(stamp)
    except ValueError:
        return None


def arch_news(since: datetime | None) -> list[tuple[str, str, datetime]]:
    """Arch news items published after `since` (title, link, date)."""
    if since is None:
        return []
    try:
        with urllib.request.urlopen(NEWS_FEED, timeout=4) as response:
            root = ET.fromstring(response.read())
    except Exception:
        return []
    if since.tzinfo is None:
        since = since.replace(tzinfo=timezone.utc)
    items = []
    for item in root.iter("item"):
        try:
            date = parsedate_to_datetime(item.findtext("pubDate", ""))
        except (TypeError, ValueError):
            continue
        if date > since:
            items.append((item.findtext("title", "").strip(), item.findtext("link", "").strip(), date))
    return items


def gather(aur: bool, flatpak: bool, news: bool):
    with concurrent.futures.ThreadPoolExecutor() as pool:
        jobs = {"pacman": pool.submit(pacman_updates)}
        if aur and shutil.which("yay"):
            jobs["aur"] = pool.submit(aur_updates)
        if flatpak and shutil.which("flatpak"):
            jobs["flatpak"] = pool.submit(flatpak_updates)
        if news:
            jobs["news"] = pool.submit(lambda: arch_news(last_full_upgrade()))
        results = {key: job.result() for key, job in jobs.items()}
    updates = results.get("pacman", []) + results.get("aur", []) + results.get("flatpak", [])
    updates.sort(key=lambda u: u.sort_key)
    return updates, results.get("news", [])


# ── display ──────────────────────────────────────────────────────────────────

def version_diff(old: str, new: str) -> str:
    """'old -> new' with only the changed tail of the new version highlighted."""
    if not old:
        return click.style(new, fg="magenta")
    i = 0
    while i < min(len(old), len(new)) and old[i] == new[i]:
        i += 1
    # Back up to the start of the differing component (after . - : + _).
    while i > 0 and new[i - 1] not in ".-:+_":
        i -= 1
    return (click.style(old, fg="bright_black") + " -> " + new[:i]
            + click.style(new[i:], fg="green", bold=True))


def show_summary(updates: list[Update]) -> None:
    counts = Counter(u.category for u in updates)
    parts = [click.style(f"{cat} {counts[cat]}", fg=col, bold=True)
             for cat, col in CATEGORIES.items() if counts[cat]]
    click.echo("  " + click.style(f"{len(updates)} updates", bold=True) + "  ·  " + "  ".join(parts))


def show_news(items) -> None:
    if not items:
        return
    click.secho("\n╭─ Arch news since your last upgrade ─", fg="yellow", bold=True)
    for title, link, date in items:
        click.secho("│ ", fg="yellow", nl=False)
        click.secho(f"{date:%Y-%m-%d}  ", fg="bright_black", nl=False)
        click.secho(title, bold=True)
        click.secho("│ ", fg="yellow", nl=False)
        click.secho(f"            {link}", fg="bright_black")
    click.secho("╰─ read these before updating", fg="yellow", bold=True)


def show_list(updates: list[Update]) -> None:
    width = max(len(u.name) for u in updates)
    idx_w = len(str(len(updates)))
    current = None
    for idx, u in enumerate(updates, 1):
        if u.category != current:
            current = u.category
            click.secho(f"\n── {current} ──", fg=CATEGORIES[current], bold=True)
        color, tag, _ = REPOS.get(u.repo, DEFAULT_REPO)
        flag = click.style(" ↻", fg="yellow") if REBOOT_PACKAGES.match(u.name) else "  "
        click.echo(
            click.style(f"[{idx:>{idx_w}}]", fg="bright_black") + " "
            + click.style(f"{tag:<3}", fg=color, bold=True) + "  "
            + click.style(u.name.ljust(width), bold=True) + flag + " "
            + version_diff(u.old, u.new)
        )


# ── choosing ─────────────────────────────────────────────────────────────────

def parse_skip(text: str, updates: list[Update]) -> set[int]:
    """Numbers, ranges (3-7) and package names, separated by spaces or commas."""
    by_name = {u.name: i for i, u in enumerate(updates, 1)}
    chosen = set()
    for part in text.replace(",", " ").split():
        if part in by_name:
            chosen.add(by_name[part])
        elif re.fullmatch(r"\d+-\d+", part):
            a, b = map(int, part.split("-"))
            chosen.update(range(min(a, b), max(a, b) + 1))
        elif part.isdigit():
            chosen.add(int(part))
        else:
            warn(f"'{part}' is not a number or a listed package, ignored")
    return {i for i in chosen if 1 <= i <= len(updates)}


# ── updating ─────────────────────────────────────────────────────────────────

def update_system(run_list: list[Update], skipped: list[Update]) -> int | None:
    names = [u.name for u in run_list if u.repo != "flatpak"]
    if not names:
        return None
    skip = [u.name for u in skipped if u.repo != "flatpak"]
    if shutil.which("yay"):
        cmd = ["yay", "-Syu", "--noconfirm"]
    else:
        cmd = ["sudo", "pacman", "-Syu", "--noconfirm"]
    if skip:
        click.secho(f"   skipping: {', '.join(skip)}", fg="yellow")
        cmd += ["--ignore", ",".join(skip)]
    heading(f"Updating {len(names)} packages", "blue")
    return subprocess.run(cmd).returncode


def update_flatpak(run_list: list[Update], skipped: list[Update]) -> int | None:
    apps = [u.name for u in run_list if u.repo == "flatpak"]
    if not apps:
        return None
    heading(f"Updating {len(apps)} Flatpaks", "magenta")
    # Name the refs only when some were skipped; otherwise update everything
    # (runtimes included).
    targets = apps if any(u.repo == "flatpak" for u in skipped) else []
    return subprocess.run(["flatpak", "update", "-y", *targets]).returncode


def check_reboot(updated: list[Update]) -> None:
    """A core package changed, or the running kernel's modules are gone."""
    kernel_gone = not os.path.isdir(f"/usr/lib/modules/{os.uname().release}")
    core = sorted({u.name for u in updated if REBOOT_PACKAGES.match(u.name)})
    if kernel_gone or core:
        why = "the running kernel was replaced" if kernel_gone else ", ".join(core)
        heading(f"Reboot recommended ({why})", "yellow")


def check_pacnew() -> None:
    """.pacnew / .pacsave files waiting to be merged (--pacnew)."""
    if not shutil.which("pacdiff"):
        warn("pacdiff not found (pacman-contrib), can't look for .pacnew files")
        return
    pending = run(["pacdiff", "-o"])
    if not pending:
        click.secho("   No .pacnew files to merge.", fg="green")
        return
    heading(f"{len(pending)} config file(s) to merge (run: sudo DIFFPROG='nvim -d' pacdiff)", "yellow")
    for path in pending:
        click.echo(f"   {path}")


def check_orphans(interactive: bool) -> None:
    """Dependencies nothing needs any more (--orphans)."""
    orphans = run(["pacman", "-Qdtq"], ok_codes=(0, 1))
    if not orphans:
        click.secho("   No orphaned packages.", fg="green")
        return
    heading(f"{len(orphans)} orphaned package(s): {' '.join(orphans)}", "cyan")
    if interactive and click.confirm("   Remove them?", default=False):
        subprocess.run(["sudo", "pacman", "-Rns", *orphans])


def extra_checks(pacnew: bool, orphans: bool, interactive: bool) -> None:
    if pacnew:
        check_pacnew()
    if orphans:
        check_orphans(interactive)


# ── main ─────────────────────────────────────────────────────────────────────

@click.command(context_settings={"help_option_names": ["-h", "--help"]})
@click.option("--yes", "-y", is_flag=True, help="Update everything without asking.")
@click.option("--check", "-c", is_flag=True, help="List updates and exit (0 = updates, 2 = none).")
@click.option("--no-aur", is_flag=True, help="Leave AUR packages out.")
@click.option("--no-flatpak", is_flag=True, help="Leave Flatpaks out.")
@click.option("--no-news", is_flag=True, help="Don't fetch Arch news.")
@click.option("--pacnew", "-p", is_flag=True, help="Also list .pacnew/.pacsave files to merge.")
@click.option("--orphans", "-o", is_flag=True, help="Also offer to remove orphaned packages.")
def main(yes, check, no_aur, no_flatpak, no_news, pacnew, orphans):
    """List pacman, AUR and Flatpak updates, choose what to skip, update."""
    try:
        click.secho(":: Checking for updates...", fg="cyan", bold=True)
        updates, news = gather(not no_aur, not no_flatpak, not no_news)

        if not updates:
            click.secho("System is up to date.", fg="green", bold=True)
            if not check:
                extra_checks(pacnew, orphans, interactive=not yes)
            sys.exit(2 if check else 0)

        if not check:
            click.clear()
        show_summary(updates)
        show_news(news)
        show_list(updates)
        if check:
            sys.exit(0)

        to_run, skipped = list(updates), []
        if not yes:
            click.echo()
            answer = click.prompt(
                click.style("Skip (numbers, ranges, names), q to quit, Enter for all", fg="cyan"),
                default="", show_default=False,
            ).strip()
            if answer.lower() in {"q", "quit", "exit"}:
                sys.exit(0)
            if answer:
                chosen = parse_skip(answer, updates)
                skipped = [u for i, u in enumerate(updates, 1) if i in chosen]
                to_run = [u for i, u in enumerate(updates, 1) if i not in chosen]
                if not to_run:
                    click.secho("Everything skipped.", fg="yellow")
                    sys.exit(0)
            if not click.confirm(click.style(f"\nUpdate {len(to_run)} package(s)?", bold=True), default=True):
                click.secho("Aborted.", fg="red")
                sys.exit(0)

        results = {
            "System": update_system(to_run, skipped),
            "Flatpak": update_flatpak(to_run, skipped),
        }

        heading("Summary", "cyan")
        failed = False
        for stage, code in results.items():
            if code is None:
                continue
            if code == 0:
                click.secho(f"   {stage}: done", fg="green")
            else:
                failed = True
                click.secho(f"   {stage}: failed (exit {code})", fg="red", bold=True)

        check_reboot(to_run)
        extra_checks(pacnew, orphans, interactive=not yes)
        sys.exit(1 if failed else 0)

    except (KeyboardInterrupt, click.Abort):
        click.secho("\nAborted.", fg="red")
        sys.exit(130)


if __name__ == "__main__":
    main()
