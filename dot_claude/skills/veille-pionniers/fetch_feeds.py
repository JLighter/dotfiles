#!/usr/bin/env python3
"""Fetch the pioneers' feeds from sources.yml and output TSV sorted by date.

Adapted from the `veille` skill script: sources are people, not aggregators,
so the footer reports each source's article count and last post date
(to tell "silent" from "dormant"), and search-only sources are listed
for the skill to query with WebSearch.
"""

import sys
import re
import html
import subprocess
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

ATOM = "{http://www.w3.org/2005/Atom}"
MEDIA = "{http://search.yahoo.com/mrss/}"
DESCRIPTION_MAX = 300


def load_sources():
    """Load sources from sources.yml next to this script (no PyYAML needed)."""
    sources_path = Path(__file__).parent / "sources.yml"
    sources = []
    current = None
    with open(sources_path) as f:
        for line in f:
            stripped = line.strip()
            if stripped.startswith("#") or not stripped or stripped == "sources:":
                continue
            if stripped.startswith("- name:"):
                if current:
                    sources.append(current)
                current = {"name": stripped.split(":", 1)[1].strip()}
            elif current and ":" in stripped:
                key, val = stripped.split(":", 1)
                current[key.strip()] = val.split(" #")[0].strip()
    if current:
        sources.append(current)
    return sources


def strip_html(text):
    """Remove HTML tags and decode entities."""
    if not text:
        return ""
    text = re.sub(r"<!\[CDATA\[(.*?)\]\]>", r"\1", text, flags=re.DOTALL)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text)
    return " ".join(text.split())[:DESCRIPTION_MAX]


def parse_date(date_str):
    """Parse RFC 2822 (RSS) or ISO 8601 (Atom) date string to aware datetime."""
    if not date_str:
        return None
    date_str = date_str.strip()
    try:
        parsed = parsedate_to_datetime(date_str)
    except (TypeError, ValueError):
        try:
            parsed = datetime.fromisoformat(date_str)
        except ValueError:
            return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def parse_items(root):
    """Yield (date, title, link, description) for RSS 2.0 or Atom entries."""
    items = root.findall(".//item")
    for item in items:
        yield (
            parse_date(item.findtext("pubDate", "")),
            item.findtext("title", "").strip(),
            item.findtext("link", "").strip(),
            strip_html(item.findtext("description", "")),
        )
    if items:
        return
    for entry in root.findall(f".//{ATOM}entry"):
        link_el = entry.find(f"{ATOM}link[@href]")
        content = (
            entry.findtext(f"{ATOM}summary")
            or entry.findtext(f"{ATOM}content")
            or entry.findtext(f"{MEDIA}group/{MEDIA}description")  # YouTube
            or ""
        )
        yield (
            parse_date(entry.findtext(f"{ATOM}published") or entry.findtext(f"{ATOM}updated")),
            (entry.findtext(f"{ATOM}title") or "").strip(),
            link_el.get("href", "") if link_el is not None else "",
            strip_html(content[:4000]),
        )


def fetch_feed(source, cutoff):
    """Return (articles in window, last post date overall, error or None)."""
    name = source["name"]
    # curl rather than urllib: the Claude Code sandbox proxy truncates large
    # urllib responses (IncompleteRead) while curl reads them whole.
    try:
        body = subprocess.run(
            ["curl", "-sfL", "--max-time", "15", "-A", "veille-techno/1.0", source["feed"]],
            capture_output=True, check=True,
        ).stdout
        root = ET.fromstring(body)
    except subprocess.CalledProcessError as e:
        return [], None, f"ERROR: {name} - curl exit {e.returncode}"
    except ET.ParseError as e:
        return [], None, f"ERROR: {name} - {e}"

    articles = []
    last_post = None
    for date, title, link, desc in parse_items(root):
        if date is None:
            continue
        last_post = max(last_post, date) if last_post else date
        if date >= cutoff:
            articles.append({"date": date, "title": title, "link": link,
                             "description": desc, "source": name})
    return articles, last_post, None


def clean(field):
    return field.replace("\t", " ").replace("\n", " ")


def main():
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    sources = load_sources()
    fed = [s for s in sources if s.get("feed")]

    with ThreadPoolExecutor(max_workers=min(len(fed), 10) or 1) as pool:
        results = dict(zip((s["name"] for s in fed), pool.map(lambda s: fetch_feed(s, cutoff), fed)))

    seen = {}
    for articles, _, error in results.values():
        if error:
            print(error, file=sys.stderr)
        for a in articles:
            seen.setdefault(a["link"], a)

    for a in sorted(seen.values(), key=lambda a: a["date"], reverse=True):
        print("\t".join([a["date"].strftime("%Y-%m-%d"), clean(a["source"]), clean(a["title"]),
                         a["link"], clean(a["description"]) or "N/A"]))

    # name, known_for, site, count in window, last post date (N/A = no feed or fetch error)
    print("SOURCES:")
    for s in sources:
        articles, last_post, _ = results.get(s["name"], ([], None, None))
        last = last_post.strftime("%Y-%m-%d") if last_post else "N/A"
        print(f"  {s['name']}\t{s.get('known_for', '')}\t{s.get('site', '')}\t{len(articles)}\t{last}")

    # name, known_for, WebSearch query
    print("SEARCH:")
    for s in sources:
        if s.get("search"):
            print(f"  {s['name']}\t{s.get('known_for', '')}\t{s['search']}")


if __name__ == "__main__":
    main()
