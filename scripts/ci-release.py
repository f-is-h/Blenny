#!/usr/bin/env python3
"""Bounded GitHub release transaction. Publication is invoked only by release.yml."""
import argparse
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

from release_tools import (ROOT, CONTROLLER_ROOT, REPOSITORY, ci_build_number, git, marketing_version,
                           product_digest, validate_acceptance, validate_coverage,
                           validate_documents, version_notes, version_tuple, write_json)


def load_script(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), CONTROLLER_ROOT / "scripts" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


artifact = load_script("verify-artifact")
appcast = load_script("create-appcast")


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)


def api(endpoint):
    return json.loads(gh("api", endpoint))


def optional_release(tag):
    # Distinguish a genuine 404 from authentication, network and API failures.
    result = subprocess.run(["gh", "api", f"repos/{REPOSITORY}/releases/tags/{tag}"], capture_output=True, text=True)
    if result.returncode == 0:
        return json.loads(result.stdout)
    if "HTTP 404" in result.stderr:
        # The tag endpoint returns published releases only. Authenticated list
        # access also exposes drafts; require one exact match before resuming.
        matches = [release for release in releases() if release["tag_name"] == tag]
        if len(matches) > 1:
            raise ValueError("Multiple releases exist for the selected tag")
        return matches[0] if matches else None
    raise RuntimeError("Cannot establish existing release state: " + result.stderr.strip())


def releases():
    pages = json.loads(gh("api", "--paginate", "--slurp", f"repos/{REPOSITORY}/releases?per_page=100"))
    return [release for page in pages for release in page]


def public_bytes(url):
    appcast.validate_url(url)
    request = urllib.request.Request(url, headers={"User-Agent": "Blenny-release-delivery-verification", "Cache-Control": "no-cache"})
    # No authorization or owner cookies. One request and bounded network timeout.
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status != 200 or not response.url.startswith("https://"):
            raise ValueError("Anonymous HTTPS delivery failed")
        return response.read()


def ensure_order(version, existing_releases, current_tag):
    for release in existing_releases:
        tag = release["tag_name"]
        if release["draft"] or not tag.startswith("v") or tag == current_tag:
            continue
        published = version_tuple(tag[1:])
        if published >= version_tuple(version):
            raise ValueError("Cannot publish an equal/older marketing version")


def select_source(operation, requested_tag):
    """Select immutable application source separately from the reviewed controller."""
    if os.getenv("GITHUB_ACTIONS") != "true" or os.getenv("GITHUB_REPOSITORY") != REPOSITORY:
        raise ValueError("Source selection requires the expected hosted repository")
    event, ref = os.getenv("GITHUB_EVENT_NAME"), os.getenv("GITHUB_REF")
    controller = git("rev-parse", "HEAD", root=CONTROLLER_ROOT)
    if controller != os.environ["GITHUB_SHA"] or git("status", "--porcelain", root=CONTROLLER_ROOT):
        raise ValueError("Release controller must be clean and match the immutable workflow revision")
    if event == "push":
        if not ref or not ref.startswith("refs/tags/v"):
            raise ValueError("Automatic publication requires a version-tag push")
        operation, requested_tag = "publish", ref.removeprefix("refs/tags/")
    elif event != "workflow_dispatch" or ref != "refs/heads/main":
        raise ValueError("Manual release controls must run from reviewed main")
    if operation not in {"verification", "signing-diagnostics", "publish"}:
        raise ValueError("Unknown release operation")
    if operation == "publish" and not requested_tag:
        raise ValueError("Manual publication requires an explicit existing version tag")
    selected = controller
    tag_object = ""
    if requested_tag:
        if not requested_tag.startswith("v"):
            raise ValueError("Expected a canonical vX.Y.Z source tag")
        version_tuple(requested_tag[1:])
        if git("cat-file", "-t", "refs/tags/" + requested_tag, root=CONTROLLER_ROOT) != "tag":
            raise ValueError("Selected source tag must be annotated")
        selected = git("rev-parse", requested_tag + "^{commit}", root=CONTROLLER_ROOT)
        tag_object = git("rev-parse", "refs/tags/" + requested_tag, root=CONTROLLER_ROOT)
        remote = api(f"repos/{REPOSITORY}/git/ref/tags/{requested_tag}")
        if remote["object"]["sha"] != tag_object:
            raise ValueError("Selected remote tag was replaced or diverged")
        run("git", "-C", str(CONTROLLER_ROOT), "merge-base", "--is-ancestor", selected, "origin/main")
    return dict(mode="production" if operation == "publish" else "verification",
                production=str(operation == "publish").lower(), diagnostics=str(operation == "signing-diagnostics").lower(),
                source_ref=selected, source_sha=selected, source_tag=requested_tag, tag_object=tag_object)


def preflight(mode):
    if os.getenv("GITHUB_ACTIONS") != "true" or os.getenv("GITHUB_REPOSITORY") != REPOSITORY:
        raise ValueError("Hosted release commands require the expected GitHub Actions repository")
    source = git("rev-parse", "HEAD")
    expected_source = os.getenv("BLENNY_RELEASE_SOURCE_SHA", os.environ["GITHUB_SHA"])
    if git("status", "--porcelain") or source != expected_source:
        raise ValueError("Release checkout must be clean and match the selected immutable source")
    if ROOT != CONTROLLER_ROOT:
        if git("rev-parse", "HEAD", root=CONTROLLER_ROOT) != os.environ["GITHUB_SHA"] or git("status", "--porcelain", root=CONTROLLER_ROOT):
            raise ValueError("Release controller differs from the immutable workflow revision")
    validate_documents()
    validate_coverage()
    version = marketing_version()
    tag = "v" + version
    if mode == "verification" and (os.getenv("GITHUB_EVENT_NAME") != "workflow_dispatch" or os.getenv("GITHUB_REF") != "refs/heads/main"):
        raise ValueError("Verification-only signing is explicitly dispatched from reviewed main")
    if mode == "production":
        automatic = os.getenv("GITHUB_EVENT_NAME") == "push" and os.getenv("GITHUB_REF") == "refs/tags/" + tag
        manual = (os.getenv("GITHUB_EVENT_NAME") == "workflow_dispatch" and os.getenv("GITHUB_REF") == "refs/heads/main"
                  and os.getenv("BLENNY_RELEASE_TAG") == tag and ROOT != CONTROLLER_ROOT)
        if not (automatic or manual):
            raise ValueError("Publication requires a version-tag push or explicit existing-tag dispatch from reviewed main")
        if git("cat-file", "-t", "refs/tags/" + tag) != "tag" or git("rev-parse", tag + "^{commit}") != source:
            raise ValueError("Release tag must be annotated and point to the checked-out source")
        run("git", "merge-base", "--is-ancestor", source, "origin/main")
        local_tag = git("rev-parse", "refs/tags/" + tag)
        remote_tag = gh("api", f"repos/{REPOSITORY}/git/ref/tags/{tag}")
        if json.loads(remote_tag)["object"]["sha"] != local_tag:
            raise ValueError("Remote tag was replaced or diverged")
        validate_acceptance()
        if api(f"repos/{REPOSITORY}")["private"]:
            raise ValueError("Resolve repository visibility before the production trigger")
        ensure_order(version, releases(), tag)
    return source, version, tag


def recover(directory, production):
    """Reuse published/draft bytes first, then a sealed artifact from this same run."""
    source, version, tag = preflight("production" if production else "verification")
    directory.mkdir(parents=True, exist_ok=True)
    release = optional_release(tag) if production else None
    if release:
        expected = {f"Blenny-{version}.dmg", f"Blenny-{version}.dmg.sha256", f"Blenny-{version}.receipt.json", "release-notes.md"}
        present = {a["name"] for a in release["assets"]}
        if present == expected:
            # Never rebuild or overwrite a version that already has complete assets.
            run("gh", "release", "download", tag, "--repo", REPOSITORY, "--dir", str(directory))
            artifact.verify(directory, production=True, source=source)
            return True
        if not release["draft"] or not present <= expected:
            raise ValueError("Existing published release has an incomplete/conflicting asset set")
    run_id = os.environ["GITHUB_RUN_ID"]
    pages = json.loads(gh("api", "--paginate", "--slurp", f"repos/{REPOSITORY}/actions/runs/{run_id}/artifacts?per_page=100"))
    prefix = f"sealed-{version}-{source}-"
    found = [a for page in pages for a in page["artifacts"] if a["name"].startswith(prefix) and not a["expired"]]
    if found:
        selected = max(found, key=lambda a: a["id"])
        run("gh", "run", "download", run_id, "--repo", REPOSITORY, "--name", selected["name"], "--dir", str(directory))
        artifact.verify(directory, production=production, source=source)
        return True
    if release and release["assets"]:
        raise ValueError("Partial draft exists but its sealed source artifact is unavailable; refuse to rebuild different bytes")
    # An empty unpublished draft contains no committed bytes. A new dispatch
    # may allocate a newer internal build and resume that same draft.
    return False


def allocate(mode):
    source, version, tag = preflight(mode)
    feed = ET.parse(ROOT / "appcast.xml")
    builds = [int(item.findtext(f"{{{appcast.SPARKLE}}}version")) for item in feed.findall("channel/item")]
    if mode == "production":
        # Also consult published receipts: assets may precede a failed feed commit.
        for release in releases():
            if release["draft"] or release["tag_name"] == tag:
                continue
            names = [a for a in release["assets"] if a["name"].endswith(".receipt.json")]
            if len(names) != 1:
                raise ValueError("Published release has no unique provenance receipt")
            receipt = json.loads(public_bytes(names[0]["browser_download_url"]))
            builds.append(int(receipt["build"]))
    return ci_build_number(int(os.environ["GITHUB_RUN_NUMBER"]), int(os.environ["GITHUB_RUN_ATTEMPT"]), builds)


def verify_public_assets(release, directory, receipt):
    expected = {receipt["archive"], receipt["archive"] + ".sha256",
                f"Blenny-{receipt['version']}.receipt.json", "release-notes.md"}
    assets = {asset["name"]: asset for asset in release["assets"]}
    if set(assets) != expected:
        raise ValueError("Release assets are incomplete or unexpected")
    for name in sorted(expected):
        downloaded = public_bytes(assets[name]["browser_download_url"])
        if downloaded != (directory / name).read_bytes():
            raise ValueError("Anonymous downloaded bytes differ from sealed artifact: " + name)
    return {name: assets[name]["browser_download_url"] for name in sorted(expected)}


def feed_has_release(feed, receipt, download_url):
    root = ET.fromstring(feed)
    matches = [item for item in root.findall("channel/item") if item.findtext(f"{{{appcast.SPARKLE}}}shortVersionString") == receipt["version"]]
    if not matches:
        return False
    if len(matches) != 1:
        raise ValueError("Duplicate release in feed")
    item = matches[0]
    enclosure = item.find("enclosure")
    if item.findtext(f"{{{appcast.SPARKLE}}}version") != str(receipt["build"]) or enclosure is None or enclosure.get("url") != download_url or enclosure.get("length") != str(receipt["length"]) or enclosure.get(f"{{{appcast.SPARKLE}}}edSignature") != receipt["edSignature"] or item.findtext("description") != version_notes(receipt["version"]) or item.findtext(f"{{{appcast.SPARKLE}}}minimumSystemVersion") != "27.0" or item.findtext("link") != f"https://github.com/{REPOSITORY}/releases/tag/v{receipt['version']}":
        raise ValueError("Existing feed item conflicts with sealed release")
    return True


def publish(directory):
    source, version, tag = preflight("production")
    receipt = artifact.verify(directory, production=True, source=source)
    release = optional_release(tag)
    assets = [directory / receipt["archive"], directory / (receipt["archive"] + ".sha256"),
              directory / f"Blenny-{version}.receipt.json", directory / "release-notes.md"]
    if release is None:
        run("gh", "release", "create", tag, "--repo", REPOSITORY, "--verify-tag", "--draft", "--title", f"Blenny {version}", "--notes-file", str(directory / "release-notes.md"))
        release = optional_release(tag)
    if release is None:
        raise ValueError("Created release is unavailable; stop before uploading assets")
    if release["body"].strip() != version_notes(version).strip():
        raise ValueError("Release transaction notes differ from the prepared, reviewed notes")
    if release["draft"]:
        present = {a["name"] for a in release["assets"]}
        for path in assets:
            if path.name not in present:
                run("gh", "release", "upload", tag, str(path), "--repo", REPOSITORY)
        # Authenticate draft downloads, independently verify all bytes before publishing.
        with tempfile.TemporaryDirectory(prefix="blenny-draft-verification-") as temp:
            run("gh", "release", "download", tag, "--repo", REPOSITORY, "--dir", temp)
            artifact.verify(Path(temp), production=True, source=source)
            downloaded = {p.name for p in Path(temp).iterdir()}
            if downloaded != {p.name for p in assets}:
                raise ValueError("Draft asset set differs from sealed set")
            if any((Path(temp) / path.name).read_bytes() != path.read_bytes() for path in assets):
                raise ValueError("Draft asset bytes differ from selected sealed artifact")
        run("gh", "release", "edit", tag, "--repo", REPOSITORY, "--draft=false", "--latest")
        release = optional_release(tag)
    urls = verify_public_assets(release, directory, receipt)
    print("Published assets verified anonymously; preparing feed transaction.", flush=True)
    with tempfile.TemporaryDirectory(prefix="blenny-feed-transaction-") as temp:
        worktree = Path(temp) / "main"
        run("git", "fetch", "origin", "main")
        run("git", "worktree", "add", "--detach", str(worktree), "origin/main")
        try:
            feed = worktree / "appcast.xml"
            if not feed_has_release(feed.read_bytes(), receipt, urls[receipt["archive"]]):
                appcast.create_item(feed, version=version, build=receipt["build"], signature=receipt["edSignature"], length=receipt["length"],
                                    download_url=urls[receipt["archive"]], release_url=release["html_url"], notes=version_notes(version))
            public_receipt = dict(status="published", version=version, build=receipt["build"], sourceCommit=source,
                                  tag=tag, sha256=receipt["sha256"], releaseURL=release["html_url"], assets=urls,
                                  anonymousAssetVerification=True, workflowRun=os.environ["GITHUB_RUN_ID"],
                                  workflowCommit=receipt.get("workflowCommit", source))
            write_json(worktree / "docs/public-release.json", public_receipt)
            run("git", "-C", str(worktree), "config", "user.name", "github-actions[bot]")
            run("git", "-C", str(worktree), "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
            run("git", "-C", str(worktree), "add", "appcast.xml", "docs/public-release.json")
            if subprocess.run(["git", "-C", str(worktree), "diff", "--cached", "--quiet"]).returncode != 0:
                run("git", "-C", str(worktree), "commit", "-m", f"chore(release): publish {version} update feed", "-m", "Release-Note: none (publication metadata for the already prepared release)")
                # A concurrent branch advance fails safely; rerun reuses public bytes and rebases via a fresh worktree.
                run("git", "-C", str(worktree), "push", "origin", "HEAD:refs/heads/main")
            feed_commit = subprocess.check_output(["git", "-C", str(worktree), "rev-parse", "HEAD"], text=True).strip()
        finally:
            run("git", "worktree", "remove", "--force", str(worktree))
    # Immutable raw commit verifies the write; the canonical URL verifies actual updater delivery.
    immutable_url = f"https://raw.githubusercontent.com/{REPOSITORY}/{feed_commit}/appcast.xml"
    canonical_url = f"https://raw.githubusercontent.com/{REPOSITORY}/main/appcast.xml"
    if not feed_has_release(public_bytes(immutable_url), receipt, urls[receipt["archive"]]) or not feed_has_release(public_bytes(canonical_url + "?release=" + feed_commit), receipt, urls[receipt["archive"]]):
        raise ValueError("Public update feed does not advertise the verified release")
    final = dict(public_receipt, feedCommit=feed_commit, feedURL=canonical_url, anonymousFeedVerification=True,
                 hostedInstallRelaunchVerified=False)
    write_json(directory / "publication-result.json", final)
    print(json.dumps(final, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    select_parser = commands.add_parser("select")
    select_parser.add_argument("--operation", required=True)
    select_parser.add_argument("--tag", default="")
    for name in ("preflight", "allocate"):
        sub = commands.add_parser(name)
        sub.add_argument("--mode", choices=["verification", "production"], required=True)
    recover_parser = commands.add_parser("recover")
    recover_parser.add_argument("directory", type=Path)
    recover_parser.add_argument("--production", action="store_true")
    publish_parser = commands.add_parser("publish")
    publish_parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    if args.command == "select":
        selected = select_source(args.operation, args.tag)
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            for key, value in selected.items():
                output.write(key + "=" + value + "\n")
        with open(os.environ["GITHUB_ENV"], "a") as environment:
            environment.write("BLENNY_RELEASE_SOURCE_SHA=" + selected['source_sha'] + "\n")
            environment.write("BLENNY_RELEASE_TAG=" + selected['source_tag'] + "\n")
        print(json.dumps(selected))
    elif args.command == "preflight":
        source, version, tag = preflight(args.mode)
        print(json.dumps(dict(source=source, version=version, tag=tag)))
    elif args.command == "allocate":
        print(allocate(args.mode))
    elif args.command == "recover":
        recovered = recover(args.directory, args.production)
        if os.getenv("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a") as output:
                output.write("reused=" + str(recovered).lower() + "\n")
        print("Sealed artifact recovered" if recovered else "No sealed artifact; build may proceed")
    elif args.command == "publish":
        try:
            publish(args.directory)
        except Exception:
            print("Publication failed. Existing public assets are immutable; a recovery rerun must reuse them. Feed delivery may still be incomplete.", flush=True)
            raise


if __name__ == "__main__":
    main()
