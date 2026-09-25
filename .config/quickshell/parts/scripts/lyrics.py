#!/usr/bin/env python3
"""Lyrics for one track from lrclib.net, as JSON on stdout.

    lyrics.py --artist ARTIST --title TITLE [--album ALBUM] [--duration SECONDS]

Prints one object:

    {"kind": "synced" | "plain" | "instrumental" | "none",
     "lines": [{"t": ms, "text": str, "words": [{"t": ms, "text": str}]}],
     "match": {"artist": str, "title": str, "duration": s}}

`t` is -1 on plain lyrics. `words` is only filled for enhanced LRC (word
timestamps); a blank synced line is a pause and is kept.

Lookup, most exact first, stopping at the first synced match:
  1. /api/get with the duration (lrclib's own exact match)
  2. /api/search by artist + title, then by free text, each candidate scored on
     title similarity, artist overlap and length
Plain lyrics are only used when nothing synced matched.

Results are cached under $XDG_CACHE_HOME/quickshell/lyrics: found ones for
good, misses for a day so a track added to lrclib later is picked up.
"""

import argparse
import difflib
import hashlib
import json
import os
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"
AGENT = "quickshell-island-lyrics/1.0 (https://github.com/andreumassanet/impasto)"
TIMEOUT = 6
MISS_TTL = 24 * 3600

CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "quickshell", "lyrics")

# Suffixes that name a release of the same recording, not a different song.
# "Remix", "Live" and "Acoustic" are left alone: they have their own lyrics
# timing.
NOISE = re.compile(
    r"\s*(?:[(\[][^)\]]*\b(?:feat\.?|ft\.?|with|remaster(?:ed)?|radio edit|"
    r"single version|album version|mono|stereo|bonus track|explicit|clean)\b[^)\]]*[)\]]"
    r"|-\s*(?:\d{4}\s*)?remaster(?:ed)?.*$"
    r"|-\s*(?:radio edit|single version|album version|mono|stereo).*$)",
    re.IGNORECASE)

ARTIST_SPLIT = re.compile(r"\s*(?:,|&|/|\bfeat\.?|\bft\.?|\bx\b|\band\b)\s*", re.IGNORECASE)


# ── MATCHING ────────────────────────────────────────────────────────────────

def fold(text):
    """Lower case, no accents, no punctuation: 'Zszedłem Ze Sceny' ~ 'zszedlem ze sceny'."""
    text = unicodedata.normalize("NFKD", text or "")
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.replace("ł", "l").replace("Ł", "l")
    text = re.sub(r"[^\w\s]", " ", text.casefold())
    return re.sub(r"\s+", " ", text).strip()


def clean_title(title):
    return NOISE.sub("", title or "").strip() or (title or "")


def artists_of(artist):
    return {fold(part) for part in ARTIST_SPLIT.split(artist or "") if fold(part)}


def score(item, artist, title, duration):
    """0–1, or None when it cannot be the same recording."""
    want_title = fold(clean_title(title))
    got_title = fold(clean_title(item.get("trackName") or item.get("name") or ""))
    if not want_title or not got_title:
        return None
    title_score = difflib.SequenceMatcher(None, want_title, got_title).ratio()
    if want_title in got_title or got_title in want_title:
        title_score = max(title_score, 0.9)
    if title_score < 0.6:
        return None

    want_artists = artists_of(artist)
    got_artists = artists_of(item.get("artistName") or "")
    if want_artists and got_artists:
        overlap = len(want_artists & got_artists) / min(len(want_artists), len(got_artists))
        if overlap == 0:
            # Transliterated or differently credited names.
            overlap = max(difflib.SequenceMatcher(None, a, b).ratio()
                          for a in want_artists for b in got_artists)
            if overlap < 0.7:
                return None
    else:
        overlap = 0.5

    length_score = 1.0
    got_duration = item.get("duration") or 0
    if duration and got_duration:
        diff = abs(got_duration - duration)
        if diff > 20:
            return None
        length_score = 1.0 - diff / 20

    return 0.5 * title_score + 0.3 * overlap + 0.2 * length_score


# ── LRCLIB ──────────────────────────────────────────────────────────────────

# Whether lrclib answered at all this run, so a miss can be told apart from
# being offline.
reached = False


def request(path, **params):
    global reached
    url = f"{API}/{path}?{urllib.parse.urlencode({k: v for k, v in params.items() if v})}"
    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            reached = True
            return json.load(response)
    except urllib.error.HTTPError as error:
        reached = True
        if error.code != 404:
            sys.stderr.write(f"lrclib {path}: HTTP {error.code}\n")
    except Exception as error:  # offline, timeout, bad JSON
        sys.stderr.write(f"lrclib {path}: {error}\n")
    return None


def candidates(artist, title, album, duration):
    """Yields lrclib records, the most exact lookups first."""
    if duration:
        exact = request("get", artist_name=artist, track_name=title,
                        album_name=album, duration=duration)
        if exact:
            yield exact
    primary = next(iter(ARTIST_SPLIT.split(artist or "")), artist)
    cleaned = clean_title(title)
    seen = set()
    for params in (
        {"artist_name": artist, "track_name": cleaned},
        {"artist_name": primary, "track_name": cleaned},
        {"q": f"{primary} {cleaned}"},
    ):
        key = tuple(sorted(params.items()))
        if key in seen:
            continue
        seen.add(key)
        results = request("search", **params)
        if isinstance(results, list):
            yield from results


def find(artist, title, album, duration):
    best_synced = best_plain = None
    for item in candidates(artist, title, album, duration):
        value = score(item, artist, title, duration)
        if value is None:
            continue
        if item.get("syncedLyrics"):
            if not best_synced or value > best_synced[0]:
                best_synced = (value, item)
            # An exact, synced match will not be beaten.
            if value > 0.95:
                break
        elif item.get("plainLyrics") or item.get("instrumental"):
            if not best_plain or value > best_plain[0]:
                best_plain = (value, item)
    chosen = best_synced or best_plain
    return chosen[1] if chosen else None


# ── LRC ─────────────────────────────────────────────────────────────────────

STAMP = re.compile(r"\[(\d+):(\d{1,2})(?:[.:](\d{1,3}))?\]")
WORD = re.compile(r"<(\d+):(\d{1,2})(?:[.:](\d{1,3}))?>")
OFFSET = re.compile(r"^\[offset:\s*([+-]?\d+)\]", re.IGNORECASE | re.MULTILINE)


def ms(minutes, seconds, fraction):
    fraction = (fraction or "0").ljust(3, "0")[:3]
    return (int(minutes) * 60 + int(seconds)) * 1000 + int(fraction)


def parse_lrc(text):
    offset_match = OFFSET.search(text)
    # A positive offset shows lyrics earlier.
    offset = -int(offset_match.group(1)) if offset_match else 0
    lines = []
    for raw in text.splitlines():
        stamps = list(STAMP.finditer(raw))
        if not stamps:
            continue
        body = raw[stamps[-1].end():].strip()
        words = []
        pieces = WORD.split(body)
        # pieces: [lead, m, s, f, text, m, s, f, text, ...]
        if len(pieces) > 1:
            for i in range(1, len(pieces), 4):
                word_text = pieces[i + 3] if i + 3 < len(pieces) else ""
                words.append({"t": ms(*pieces[i:i + 3]) + offset, "text": word_text})
            if pieces[0].strip():
                words.insert(0, {"t": None, "text": pieces[0]})
        plain = WORD.sub("", body).strip()
        # One line may carry several timestamps (a repeated chorus).
        for stamp in stamps:
            start = ms(*stamp.groups()) + offset
            line_words = [{"t": w["t"] if w["t"] is not None else start, "text": w["text"]}
                          for w in words]
            lines.append({"t": max(0, start), "text": plain, "words": line_words})
    lines.sort(key=lambda line: line["t"])
    return lines


def result_of(item):
    match = {"artist": item.get("artistName", ""), "title": item.get("trackName", ""),
             "duration": item.get("duration", 0)}
    if item.get("syncedLyrics"):
        lines = parse_lrc(item["syncedLyrics"])
        if lines:
            return {"kind": "synced", "lines": lines, "match": match}
    if item.get("plainLyrics"):
        lines = [{"t": -1, "text": line.strip(), "words": []}
                 for line in item["plainLyrics"].splitlines()]
        # Collapse runs of blank lines to one stanza break.
        tidy = []
        for line in lines:
            if line["text"] or (tidy and tidy[-1]["text"]):
                tidy.append(line)
        return {"kind": "plain", "lines": tidy, "match": match}
    if item.get("instrumental"):
        return {"kind": "instrumental", "lines": [], "match": match}
    return None


# ── CACHE ───────────────────────────────────────────────────────────────────

def cache_path(artist, title, duration):
    key = f"{fold(artist)}\n{fold(clean_title(title))}\n{round(duration or 0)}"
    return os.path.join(CACHE, hashlib.sha1(key.encode()).hexdigest() + ".json")


def cached(path):
    try:
        with open(path) as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return None
    if data.get("kind") == "none" and time.time() - data.get("at", 0) > MISS_TTL:
        return None
    return data


def store(path, data):
    try:
        os.makedirs(CACHE, exist_ok=True)
        temporary = path + ".tmp"
        with open(temporary, "w") as handle:
            json.dump(dict(data, at=int(time.time())), handle)
        os.replace(temporary, path)
    except OSError as error:
        sys.stderr.write(f"lyrics cache: {error}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--artist", default="")
    parser.add_argument("--title", required=True)
    parser.add_argument("--album", default="")
    parser.add_argument("--duration", type=float, default=0)
    parser.add_argument("--refresh", action="store_true", help="ignore the cache")
    args = parser.parse_args()
    duration = round(args.duration) if args.duration > 0 else 0

    path = cache_path(args.artist, args.title, duration)
    data = None if args.refresh else cached(path)
    if data is None:
        item = find(args.artist, args.title, args.album, duration)
        data = (result_of(item) if item else None) or {"kind": "none", "lines": []}
        # A network failure is not a miss worth remembering.
        if item or reached:
            store(path, data)
    data.pop("at", None)
    json.dump(data, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # the card must never break on a lyrics failure
        sys.stderr.write(f"lyrics: {error}\n")
        print(json.dumps({"kind": "none", "lines": []}))
