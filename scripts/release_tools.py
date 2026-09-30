#!/usr/bin/env python3
"""Deterministic release preparation and shared, fail-closed release contracts."""
import argparse
import datetime
import hashlib
import json
import plistlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "f-is-h/Blenny"
CATEGORIES = {"added": "Added", "changed": "Changed", "fixed": "Fixed",
              "security": "Security", "internal": "Engineering", "limitations": "Requirements and limitations"}
CI_BUILD_OFFSET = 1000
CI_ATTEMPT_SLOTS = 100
PRODUCT_PATHS = ("Sources", "Assets", "Config", "Package.swift", "Package.resolved",
                 "LICENSE", "NOTICE", "THIRD_PARTY_NOTICES.txt", "scripts/build-app.sh",
                 "scripts/prepare-release.sh", "scripts/prepare-sparkle-update.sh",
                 "scripts/verify-distribution.sh", "scripts/create-appcast.py",
                 "scripts/release_tools.py", "scripts/verify-dmg.py",
                 "scripts/verify-artifact.py", "scripts/ci-sign-package.sh",
                 "scripts/ci-toolchain.sh", "scripts/ci-release.py",
                 ".github/workflows/release.yml")


def git(*args, root=ROOT):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def version_tuple(value):
    if not isinstance(value, str) or not re.fullmatch(r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)", value):
        raise ValueError("Expected a canonical X.Y.Z marketing version")
    return tuple(map(int, value.split(".")))


def marketing_version(root=ROOT):
    return plistlib.loads((root / "Config/Info.plist").read_bytes())["CFBundleShortVersionString"]


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def product_digest(root=ROOT):
    """Acceptance covers product bytes/configuration, independent of a later Git commit."""
    files = set()
    for relative in PRODUCT_PATHS:
        path = root / relative
        if path.is_dir():
            files.update(p for p in path.rglob("*") if p.is_file() and not p.is_symlink())
        elif path.is_file():
            files.add(path)
        else:
            raise ValueError(f"Missing acceptance input: {relative}")
    digest = hashlib.sha256()
    for path in sorted(files):
        digest.update(path.relative_to(root).as_posix().encode() + b"\0")
        digest.update(bytes.fromhex(sha256(path)))
    return digest.hexdigest()


def plain_summary(value):
    if not isinstance(value, str) or not value.strip() or value != value.strip() or "\n" in value or "\r" in value:
        raise ValueError("Summaries must be nonempty, single-line text")
    if len(value) > 700 or any(ord(c) < 32 for c in value):
        raise ValueError("Invalid summary length/control character")
    return value


def markdown_text(value):
    # Fragments are plain data: no HTML, images, headings or injected Markdown links.
    return re.sub(r"([\\`*_\[\]<>])", r"\\\1", value)


def fragments(root=ROOT):
    result = []
    for path in sorted((root / "docs/changes").glob("*.json")):
        item = read_json(path)
        allowed = {"id", "version", "category", "technical", "user", "commits", "skipReason"}
        if set(item) - allowed or not {"id", "version", "category", "technical", "commits"} <= set(item):
            raise ValueError(f"Invalid fragment schema: {path.name}")
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", item["id"]) or path.stem != item["id"]:
            raise ValueError(f"Invalid fragment identifier: {path.name}")
        if item["version"] != "unreleased":
            version_tuple(item["version"])
        if item["category"] not in CATEGORIES:
            raise ValueError(f"Invalid category: {path.name}")
        plain_summary(item["technical"])
        if item.get("user") is not None:
            plain_summary(item["user"])
        if "skipReason" in item:
            plain_summary(item["skipReason"])
            if item.get("user") is not None:
                raise ValueError("A no-entry rationale cannot also have a user-facing entry")
        if not isinstance(item["commits"], list) or any(not re.fullmatch(r"[0-9a-f]{40}", c) for c in item["commits"]):
            raise ValueError("Commit references must be full Git SHAs, not unverified attribution")
        for commit in item["commits"]:
            if git("cat-file", "-t", commit, root=root) != "commit":
                raise ValueError("Reference is not a Git commit")
            subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", commit, "HEAD"], check=True)
        result.append(item)
    if len({f["id"] for f in result}) != len(result):
        raise ValueError("Duplicate fragment IDs")
    return result


def release_records(root=ROOT):
    records = []
    for path in (root / "docs/releases").glob("*.json"):
        item = read_json(path)
        version_tuple(item["version"])
        if path.stem != item["version"]:
            raise ValueError("Release record filename mismatch")
        datetime.date.fromisoformat(item["date"])
        if not isinstance(item["firstPublicRelease"], bool):
            raise ValueError("firstPublicRelease must be boolean")
        if not item["firstPublicRelease"] and not re.fullmatch(r"v\d+\.\d+\.\d+", item.get("previousPublicTag", "")):
            raise ValueError("Subsequent releases require a previous public tag")
        records.append(item)
    return sorted(records, key=lambda r: version_tuple(r["version"]), reverse=True)


def render_documents(root=ROOT):
    changes = fragments(root)
    records = release_records(root)
    if not records:
        raise ValueError("No release records")
    outputs = {}
    for filename, user_facing in [("CHANGELOG.md", False), ("docs/RELEASE_NOTES.md", True)]:
        title = "Blenny release notes" if user_facing else "Blenny changelog"
        lines = [f"# {title}", "", "<!-- Generated by scripts/release_tools.py from docs/changes and docs/releases. -->", ""]
        for record in records:
            selected = [f for f in changes if f["version"] == record["version"]]
            if not selected:
                raise ValueError(f"No fragments for {record['version']}")
            lines += [f"## {record['version']} — {record['date']}", ""]
            if record["firstPublicRelease"]:
                lines += ["First public release. Earlier 0.x versions were private engineering milestones.", ""]
            for category, heading in CATEGORIES.items():
                summaries = []
                seen = set()
                for fragment in selected:
                    if fragment["category"] != category or fragment.get("skipReason"):
                        continue
                    summary = fragment.get("user") if user_facing else fragment["technical"]
                    if summary is None:
                        continue
                    key = " ".join(summary.casefold().split())
                    if key not in seen:
                        seen.add(key)
                        summaries.append(markdown_text(summary))
                if summaries:
                    lines += [f"### {heading}", ""] + [f"- {s}" for s in summaries] + [""]
        outputs[filename] = "\n".join(lines).rstrip() + "\n"
    return outputs


def version_notes(version, root=ROOT):
    version_tuple(version)
    text = (root / "docs/RELEASE_NOTES.md").read_text(encoding="utf-8")
    sections = re.split(r"(?m)^## ", text)
    matches = [part for part in sections[1:] if part.startswith(version + " — ")]
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one prepared release-notes section for {version}")
    return "## " + matches[0].rstrip() + "\n"


def validate_documents(root=ROOT):
    version = marketing_version(root)
    version_tuple(version)
    for filename, expected in render_documents(root).items():
        if not (root / filename).exists() or (root / filename).read_text(encoding="utf-8") != expected:
            raise ValueError(f"Stale generated output: {filename}; run release_tools.py render")
    if version != release_records(root)[0]["version"]:
        raise ValueError("Info.plist and newest prepared release version disagree")
    version_notes(version, root)


def validate_coverage(root=ROOT):
    record = release_records(root)[0]
    if record["firstPublicRelease"]:
        # The first public notes cover the entire product, not a private tag delta.
        return
    base = record["previousPublicTag"]
    subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", base, "HEAD"], check=True)
    covered = {c for f in fragments(root) if f["version"] == record["version"] for c in f["commits"]}
    missing = []
    for commit in git("rev-list", f"{base}..HEAD", root=root).splitlines():
        if commit in covered:
            continue
        message = git("show", "-s", "--format=%B", commit, root=root)
        if not re.search(r"(?m)^Release-Note: none \([^\n]+\)$", message):
            parents = git("show", "-s", "--format=%P", commit, root=root).split()
            if len(parents) > 1 and not git("show", "--format=", "--cc", "--name-only", commit, root=root):
                # A pure merge contributes the already reconciled child commits.
                continue
            missing.append(commit)
    if missing:
        raise ValueError("Unreconciled commits (add fragment references or a justified Release-Note trailer): " + ", ".join(missing))


def validate_acceptance(root=ROOT):
    record = read_json(root / "docs/release-acceptance.json")
    if record.get("version") != marketing_version(root) or record.get("productDigest") != product_digest(root):
        raise ValueError("Development acceptance does not cover the current product/configuration bytes")
    required = {"realMenuBar", "freshInstallAndPermissions", "firstApplyUndoRelaunch", "loginLifecycle", "uninstallAndRestoration"}
    checks = record.get("checks", {})
    if not required <= set(checks) or any(checks[k].get("status") != "passed" or not checks[k].get("evidence") for k in required):
        raise ValueError("Owner development acceptance remains pending")
    for key in ("sleep", "display"):
        check = checks.get(key, {})
        if check.get("status") not in {"passed", "limited"} or not check.get("evidence"):
            raise ValueError(f"Record actual exercised coverage or explicit hardware limits for {key}")
    if record.get("reviewedReleaseNotesSHA256") != hashlib.sha256(version_notes(marketing_version(root), root).encode()).hexdigest():
        raise ValueError("Release notes have not been reviewed for this version")
    return record


def ci_build_number(run_number, attempt, published_builds=()):
    if not isinstance(run_number, int) or run_number <= 0 or not isinstance(attempt, int) or not 1 <= attempt < CI_ATTEMPT_SLOTS:
        raise ValueError("Invalid CI sequence/attempt; reset/overflow needs an explicit migration")
    build = CI_BUILD_OFFSET + run_number * CI_ATTEMPT_SLOTS + attempt
    if build <= max([108, *map(int, published_builds)]):
        raise ValueError("CI build sequence would decrease; migrate the documented offset before publishing")
    return build


def prepare(version, date, previous_tag, root=ROOT):
    version_tuple(version)
    datetime.date.fromisoformat(date)
    existing = release_records(root)
    if existing and version_tuple(version) < version_tuple(existing[0]["version"]):
        raise ValueError("Cannot prepare an older version")
    path = root / f"docs/releases/{version}.json"
    if not path.exists():
        if existing and not previous_tag:
            raise ValueError("The next version requires --previous-public-tag")
        write_json(path, dict(version=version, date=date, firstPublicRelease=not bool(existing), previousPublicTag=previous_tag))
    for path in (root / "docs/changes").glob("*.json"):
        value = read_json(path)
        if value["version"] == "unreleased":
            # Reconcile the commits that actually introduced/updated the fragment,
            # including direct commits; no commit needs to embed its own SHA.
            if previous_tag:
                commits = git("log", "--format=%H", f"{previous_tag}..HEAD", "--", path.relative_to(root).as_posix(), root=root).splitlines()
                value["commits"] = sorted(set(value["commits"] + commits))
            value["version"] = version
            write_json(path, value)
    info_path = root / "Config/Info.plist"
    text = info_path.read_text()
    text, count = re.subn(r"(<key>CFBundleShortVersionString</key>\s*<string>)[^<]+(</string>)",
                         lambda m: m[1] + version + m[2], text)
    if count != 1:
        raise ValueError("Expected one marketing version in Info.plist")
    info_path.write_text(text)
    for filename, content in render_documents(root).items():
        (root / filename).write_text(content, encoding="utf-8")
    validate_documents(root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ["render", "check", "coverage", "fingerprint", "acceptance"]:
        commands.add_parser(name)
    notes = commands.add_parser("notes")
    notes.add_argument("--version")
    prep = commands.add_parser("prepare")
    prep.add_argument("--version", required=True)
    prep.add_argument("--date", required=True)
    prep.add_argument("--previous-public-tag")
    build = commands.add_parser("ci-build")
    build.add_argument("--run", type=int, required=True)
    build.add_argument("--attempt", type=int, required=True)
    args = parser.parse_args()
    if args.command == "render":
        for filename, content in render_documents().items():
            (ROOT / filename).write_text(content, encoding="utf-8")
    elif args.command == "check":
        validate_documents()
        print("Fragment schema, generated documents and marketing version: PASS")
    elif args.command == "coverage":
        validate_coverage()
        print("Release contribution reconciliation: PASS")
    elif args.command == "notes":
        print(version_notes(args.version or marketing_version()), end="")
    elif args.command == "prepare":
        prepare(args.version, args.date, args.previous_public_tag)
    elif args.command == "fingerprint":
        print(product_digest())
    elif args.command == "acceptance":
        validate_acceptance()
        print("Pre-trigger development acceptance: PASS")
    elif args.command == "ci-build":
        print(ci_build_number(args.run, args.attempt))


if __name__ == "__main__":
    main()
