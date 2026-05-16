#!/usr/bin/env python3
"""
fetch-url.py — Fetch a URL → clean Markdown for LLM ingestion.

Strategy:
  1. Try static extraction (requests + markdownify) — fast, token-efficient
  2. If word count < MIN_WORDS threshold → fall back to r.jina.ai (handles JS)
  3. Save to raw/articles/<slug>.md with proper frontmatter

Usage:
  python3 tools/fetch-url.py <url> [output-name]
  python3 tools/fetch-url.py https://example.com/article  # auto-slug
  python3 tools/fetch-url.py https://example.com/article my-article
  python3 tools/fetch-url.py https://example.com/article --dry-run
"""

import sys
import os
import re
import json
import datetime
import argparse
from pathlib import Path
from urllib.parse import urlparse, urljoin, parse_qs, unquote

ROOT = Path(__file__).parent.parent
RAW_DIR = ROOT / "raw" / "articles"
VENV_PYTHON = Path(__file__).parent / ".venv" / "bin" / "python3"

MIN_WORDS = 200  # below this → try Jina fallback
JINA_BASE = "https://r.jina.ai/"


def slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_-]+", "-", text)
    text = re.sub(r"^-+|-+$", "", text)
    return text[:80]


def slug_from_url(url: str) -> str:
    parsed = urlparse(url)
    path = parsed.path.rstrip("/")
    parts = [p for p in path.split("/") if p]
    if parts:
        return slugify(parts[-1])
    return slugify(parsed.netloc.split(".")[0])


def word_count(text: str) -> int:
    return len(text.split())


def rewrite_image_urls(content_md: str, base_url: str) -> str:
    """
    Fix image URLs in Markdown:
    1. Relative → absolute (prepend base URL origin)
    2. Next.js /_next/image?url=<encoded> → decode to get direct CDN URL
    3. Drop SVG logos (low value: company logos, icons)
    """
    parsed_base = urlparse(base_url)
    origin = f"{parsed_base.scheme}://{parsed_base.netloc}"

    def fix_url(img_url: str) -> str | None:
        img_url = img_url.strip()

        # Drop SVG — usually logos/icons, not data charts
        if img_url.lower().endswith(".svg"):
            return None

        # Decode Next.js image wrapper: /_next/image?url=<encoded>&w=...&q=...
        if "/_next/image" in img_url:
            # Make absolute first if relative
            if img_url.startswith("/"):
                img_url = origin + img_url
            parsed = urlparse(img_url)
            qs = parse_qs(parsed.query)
            if "url" in qs:
                # url= param contains the real CDN URL (URL-encoded)
                decoded = unquote(qs["url"][0])
                return decoded
            return img_url

        # Relative URL → absolute
        if img_url.startswith("//"):
            return parsed_base.scheme + ":" + img_url
        if img_url.startswith("/"):
            return origin + img_url

        return img_url

    # Match all Markdown image syntax: ![alt](url)
    def replace_match(m: re.Match) -> str:
        alt = m.group(1)
        url = m.group(2)
        new_url = fix_url(url)
        if new_url is None:
            return ""  # drop SVG lines entirely
        if new_url != url:
            return f"![{alt}]({new_url})"
        return m.group(0)

    content_md = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", replace_match, content_md)
    # Clean up blank lines left by dropped SVGs
    content_md = re.sub(r"\n{3,}", "\n\n", content_md)
    return content_md


def static_fetch(url: str) -> tuple[str, str]:
    """Fetch URL with requests + markdownify. Returns (title, markdown)."""
    import requests
    from bs4 import BeautifulSoup
    from markdownify import markdownify as md

    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/120.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml",
        "Accept-Language": "en-US,en;q=0.9",
    }

    resp = requests.get(url, headers=headers, timeout=15)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    # Extract title
    title = ""
    if soup.title:
        title = soup.title.get_text(strip=True)
    elif soup.find("h1"):
        title = soup.find("h1").get_text(strip=True)

    # Remove noise elements
    for tag in soup.find_all(
        ["script", "style", "nav", "header", "footer",
         "aside", "noscript", "iframe", "svg"]
    ):
        tag.decompose()

    # Try <article> or <main> first for focused content
    body = soup.find("article") or soup.find("main") or soup.find("body")
    if not body:
        body = soup

    content_md = md(
        str(body),
        heading_style="ATX",
        bullets="-",
    )

    # Strip trailing noise: "Related content", "Related articles", footer link sections
    for noise_tag in soup.find_all(["section", "div"], class_=re.compile(
        r"related|footer|newsletter|subscribe|sidebar|recommend", re.I
    )):
        noise_tag.decompose()

    content_md = md(
        str(body),
        heading_style="ATX",
        bullets="-",
    )

    # Clean up excessive blank lines
    content_md = re.sub(r"\n{3,}", "\n\n", content_md).strip()

    # Strip "## Related content" section and everything after it
    content_md = re.sub(
        r"\n#{1,3}\s*(Related content|Related articles|See also|More from).*$",
        "", content_md, flags=re.IGNORECASE | re.DOTALL
    )

    # Rewrite image URLs: relative → absolute, decode Next.js /_next/image wrappers
    content_md = rewrite_image_urls(content_md, url)

    return title, content_md


def jina_fetch(url: str) -> tuple[str, str]:
    """Fetch via r.jina.ai — handles JS-rendered pages."""
    import requests

    jina_url = JINA_BASE + url
    headers = {
        "Accept": "text/plain, text/markdown",
        "X-Return-Format": "markdown",
    }

    print(f"  → JS page detected, falling back to r.jina.ai ...", file=sys.stderr)
    resp = requests.get(jina_url, headers=headers, timeout=30)
    resp.raise_for_status()

    content = resp.text.strip()

    # Jina typically starts with "Title: ..." on first line
    title = ""
    lines = content.splitlines()
    if lines and lines[0].startswith("Title:"):
        title = lines[0].replace("Title:", "").strip()
        content = "\n".join(lines[1:]).strip()

    return title, content


def build_frontmatter(title: str, url: str, slug: str, source: str) -> str:
    today = datetime.date.today().isoformat()
    return f"""---
title: "{title or slug}"
source: "{url}"
fetched_via: "{source}"
created: {today}
tags:
  - "clippings"
---

"""


def main():
    parser = argparse.ArgumentParser(description="Fetch URL → Markdown for LLM ingestion")
    parser.add_argument("url", help="URL to fetch")
    parser.add_argument("name", nargs="?", default=None, help="Output filename slug (optional)")
    parser.add_argument("--dry-run", action="store_true", help="Print output, don't save")
    parser.add_argument("--force-jina", action="store_true", help="Skip static, use Jina directly")
    args = parser.parse_args()

    url = args.url
    slug = args.name or slug_from_url(url)
    output_path = RAW_DIR / f"{slug}.md"

    print(f"=== fetch-url: {url} ===", file=sys.stderr)

    # ── Step 1: Try static fetch ──────────────────────────────────────────────
    title = ""
    content = ""
    source_tag = "static"

    if not args.force_jina:
        try:
            title, content = static_fetch(url)
            wc = word_count(content)
            print(f"  Static fetch: {wc} words", file=sys.stderr)

            if wc < MIN_WORDS:
                print(f"  Word count {wc} < {MIN_WORDS} — content likely JS-rendered", file=sys.stderr)
                title, content = jina_fetch(url)
                source_tag = "jina-reader"
        except Exception as e:
            print(f"  Static fetch failed ({e}), trying Jina ...", file=sys.stderr)
            title, content = jina_fetch(url)
            source_tag = "jina-reader"
    else:
        title, content = jina_fetch(url)
        source_tag = "jina-reader"

    wc = word_count(content)
    print(f"  Final: {wc} words via {source_tag}", file=sys.stderr)

    # ── Step 2: Assemble output ───────────────────────────────────────────────
    frontmatter = build_frontmatter(title, url, slug, source_tag)
    full_output = frontmatter + content

    if args.dry_run:
        print("--- DRY RUN OUTPUT ---")
        print(full_output[:2000])
        if len(full_output) > 2000:
            print(f"\n... ({len(full_output)} chars total, truncated)")
        return

    # ── Step 3: Save ──────────────────────────────────────────────────────────
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    output_path.write_text(full_output, encoding="utf-8")

    img_count = len(re.findall(r"!\[", full_output))
    print(f"\n✅ Saved: raw/articles/{slug}.md (~{wc} words, {img_count} images, via {source_tag})", file=sys.stderr)

    # ── Step 4: Auto fetch-images ─────────────────────────────────────────────
    if img_count > 0:
        fetch_images_script = ROOT / "tools" / "fetch-images.sh"
        if fetch_images_script.exists():
            print(f"\n  → Auto-fetching {img_count} image(s) ...", file=sys.stderr)
            import subprocess
            result = subprocess.run(
                ["bash", str(fetch_images_script), str(output_path)],
                capture_output=True, text=True
            )
            # Print fetch-images output (stderr has the status lines)
            for line in result.stdout.splitlines() + result.stderr.splitlines():
                if line.strip():
                    print(f"  {line}", file=sys.stderr)

            # ── Step 5: Drop small images (< MIN_IMAGE_KB) from markdown ─────
            # Small images are decorative (hero banners ~20K, icons).
            # Charts/tables are typically 100K+. Keep only high-signal images.
            MIN_IMAGE_KB = 80
            images_dir = ROOT / "raw" / "images"
            updated = output_path.read_text(encoding="utf-8")
            dropped = 0

            def should_drop_image(img_path_str: str) -> bool:
                # img_path_str is the rewritten local path, e.g. ../images/foo.png
                fname = Path(img_path_str).name
                local = images_dir / fname
                if local.exists():
                    size_kb = local.stat().st_size / 1024
                    if size_kb < MIN_IMAGE_KB:
                        return True
                return False

            def filter_image(m: re.Match) -> str:
                nonlocal dropped
                alt, img_url = m.group(1), m.group(2)
                # Only filter local paths (already downloaded)
                if img_url.startswith("../images/"):
                    if should_drop_image(img_url):
                        dropped += 1
                        return ""
                return m.group(0)

            updated = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", filter_image, updated)
            updated = re.sub(r"\n{3,}", "\n\n", updated)

            if dropped > 0:
                output_path.write_text(updated, encoding="utf-8")
                remaining = img_count - dropped
                print(f"  → Kept {remaining} chart/data image(s), dropped {dropped} small/decorative", file=sys.stderr)

    print(f"\nNext step:", file=sys.stderr)
    print(f"  compile raw/articles/{slug}.md", file=sys.stderr)


if __name__ == "__main__":
    main()
