#!/usr/bin/env python3

import re
import sys
import xml.sax.saxutils as saxutils


def parse_version(text):
    parts = []
    for chunk in re.split(r"[.\-+]", text):
        match = re.match(r"\d+", chunk)
        parts.append(int(match.group(0)) if match else 0)
    return tuple(parts)


def main() -> int:
    if len(sys.argv) != 8:
        print(
            "usage: update_appcast.py <appcast-path> <version> <build> "
            "<download-url> <ed-signature> <length> <release-notes-url>",
            file=sys.stderr,
        )
        return 1

    appcast_path, version, build, url, signature, length, notes_url = sys.argv[1:8]

    with open(appcast_path, "r", encoding="utf-8") as handle:
        text = handle.read()

    if f'sparkle:shortVersionString="{saxutils.escape(version)}"' in text:
        print(f"appcast already contains version {version}; nothing to do")
        return 0

    existing = re.findall(r'sparkle:shortVersionString="([^"]+)"', text)
    if existing and parse_version(version) <= max(parse_version(v) for v in existing):
        print(
            f"new version {version} is not newer than latest appcast entry "
            f"{max(existing, key=parse_version)}",
            file=sys.stderr,
        )
        return 1

    from datetime import datetime, timezone

    pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S GMT")

    item = (
        "    <item>\n"
        f"      <title>HiddenApp {saxutils.escape(version)}</title>\n"
        f"      <sparkle:releaseNotesLink>{saxutils.escape(notes_url)}</sparkle:releaseNotesLink>\n"
        f"      <pubDate>{pub_date}</pubDate>\n"
        "      <enclosure\n"
        f'        url="{saxutils.escape(url)}"\n'
        f'        sparkle:version="{saxutils.escape(build)}"\n'
        f'        sparkle:shortVersionString="{saxutils.escape(version)}"\n'
        f'        sparkle:edSignature="{saxutils.escape(signature)}"\n'
        f'        length="{saxutils.escape(length)}"\n'
        '        type="application/octet-stream" />\n'
        "    </item>\n"
    )

    closing = "</channel>"
    index = text.find(closing)
    if index == -1:
        print(f"{appcast_path} has no </channel> element", file=sys.stderr)
        return 1

    updated = text[:index] + item + text[index:]
    with open(appcast_path, "w", encoding="utf-8") as handle:
        handle.write(updated)

    print(f"added HiddenApp {version} (build {build}) to {appcast_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
