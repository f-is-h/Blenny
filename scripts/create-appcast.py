#!/usr/bin/env python3
"""Create a Sparkle item from the final, signed immutable archive."""
import argparse
import base64
import datetime
from pathlib import Path
import re
import xml.etree.ElementTree as ET
from urllib.parse import urlsplit
from release_tools import version_tuple, version_notes

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE)


def validate_url(value, allow_loopback=False):
    url = urlsplit(value)
    if (url.scheme != "https" and not (allow_loopback and url.scheme == "http" and url.hostname == "127.0.0.1")) or not url.hostname or url.username or url.password or url.fragment:
        raise ValueError("Expected an HTTPS URL without credentials or fragment")


def create_item(feed, *, version, build, signature, length, download_url, release_url, notes, allow_loopback=False):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or not str(build).isdigit() or int(build) < 1:
        raise ValueError("Invalid version/build")
    if len(base64.b64decode(signature, validate=True)) != 64 or length <= 0:
        raise ValueError("Invalid signature/archive length")
    validate_url(download_url, allow_loopback)
    validate_url(release_url)
    root = ET.parse(feed).getroot() if feed.exists() else ET.Element("rss", version="2.0")
    if root.tag != "rss":
        raise ValueError("Expected RSS")
    channel = root.find("channel")
    if channel is None:
        if list(root):
            raise ValueError("Missing RSS channel")
        channel = ET.SubElement(root, "channel")
        ET.SubElement(channel, "title").text = "Blenny updates"
        ET.SubElement(channel, "link").text = "https://github.com/f-is-h/Blenny"
        ET.SubElement(channel, "description").text = "Signed Blenny updates"
    builds = []
    versions = []
    for item in channel.findall("item"):
        previous = item.findtext(f"{{{SPARKLE}}}version")
        if previous is None or not previous.isdigit():
            raise ValueError("Existing item has invalid build")
        builds.append(int(previous))
        previous_version = item.findtext(f"{{{SPARKLE}}}shortVersionString")
        if previous_version is None:
            raise ValueError("Existing item has invalid marketing version")
        versions.append(version_tuple(previous_version))
    if builds and int(build) <= max(builds):
        raise ValueError("Build must increase beyond published items")
    if versions and version_tuple(version) <= max(versions):
        raise ValueError("Marketing version must increase beyond published items")
    item = ET.Element("item")
    ET.SubElement(item, "title").text = f"Blenny {version}"
    ET.SubElement(item, "pubDate").text = datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S %z")
    ET.SubElement(item, f"{{{SPARKLE}}}version").text = str(build)
    ET.SubElement(item, f"{{{SPARKLE}}}shortVersionString").text = version
    ET.SubElement(item, f"{{{SPARKLE}}}minimumSystemVersion").text = "27.0"
    ET.SubElement(item, "link").text = release_url
    ET.SubElement(item, "description", {f"{{{SPARKLE}}}format": "markdown"}).text = notes
    ET.SubElement(item, "enclosure", {
        "url": download_url, "length": str(length), "type": "application/octet-stream",
        f"{{{SPARKLE}}}edSignature": signature,
    })
    channel.insert(0, item)
    ET.indent(root)
    temporary = feed.with_suffix(".xml.tmp")
    ET.ElementTree(root).write(temporary, encoding="utf-8", xml_declaration=True)
    temporary.replace(feed)


def main():
    parser = argparse.ArgumentParser()
    for name in ["feed", "archive", "version", "build", "signature", "download-url", "release-url", "notes"]:
        parser.add_argument(f"--{name}", required=True)
    parser.add_argument("--allow-loopback", action="store_true")
    args = parser.parse_args()
    create_item(Path(args.feed), version=args.version, build=args.build, signature=args.signature,
                length=Path(args.archive).stat().st_size, download_url=args.download_url,
                release_url=args.release_url, notes=version_notes(args.version, Path(args.notes).resolve().parent.parent),
                allow_loopback=args.allow_loopback)


if __name__ == "__main__":
    main()
