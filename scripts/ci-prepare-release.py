#!/usr/bin/env python3
"""Prepare a version branch and reviewable PR. Never tag, sign or publish."""
import argparse
import os
from pathlib import Path
import subprocess

from release_tools import ROOT, REPOSITORY, git, prepare, validate_coverage, version_tuple


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--date", required=True)
    parser.add_argument("--previous-public-tag")
    args = parser.parse_args()
    version_tuple(args.version)
    if os.getenv("GITHUB_ACTIONS") != "true" or os.getenv("GITHUB_REPOSITORY") != REPOSITORY or os.getenv("GITHUB_REF") != "refs/heads/main":
        raise ValueError("Remote preparation must run explicitly on the expected main branch")
    if git("status", "--porcelain"):
        raise ValueError("Preparation checkout must be clean")
    import json
    permission = json.loads(subprocess.check_output(["gh", "api", f"repos/{REPOSITORY}/actions/permissions/workflow"], text=True))
    if not permission.get("can_approve_pull_request_reviews"):
        raise ValueError("Enable the repository's Actions create/approve-PR setting during setup before running preparation")
    branch = f"codex/prepare-v{args.version}"
    remote = subprocess.run(["git", "ls-remote", "--exit-code", "origin", "refs/heads/" + branch], capture_output=True)
    if remote.returncode == 0:
        raise ValueError("Preparation branch already exists; update the existing PR without overwriting it")
    if remote.returncode != 2:
        raise ValueError("Cannot establish preparation branch state")
    subprocess.run(["git", "switch", "-c", branch], check=True)
    prepare(args.version, args.date, args.previous_public_tag)
    # Reset acceptance when preparing a different version; the owner reviews it in development.
    from release_tools import read_json, write_json
    acceptance_path = ROOT / "docs/release-acceptance.json"
    acceptance = read_json(acceptance_path)
    if acceptance["version"] != args.version:
        acceptance.update(version=args.version, productDigest=None, reviewedReleaseNotesSHA256=None)
        for item in acceptance["checks"].values():
            item.update(status="pending", evidence="Development acceptance for this version remains pending.")
        write_json(acceptance_path, acceptance)
    validate_coverage()
    subprocess.run(["git", "config", "user.name", "github-actions[bot]"], check=True)
    subprocess.run(["git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com"], check=True)
    subprocess.run(["git", "add", "Config/Info.plist", "CHANGELOG.md", "docs/RELEASE_NOTES.md", "docs/changes", "docs/releases", "docs/release-acceptance.json"], check=True)
    if subprocess.run(["git", "diff", "--cached", "--quiet"]).returncode == 0:
        raise ValueError("No preparation changes; use the existing prepared release")
    subprocess.run(["git", "commit", "-m", f"chore(release): prepare {args.version}", "-m", "Release-Note: none (deterministic release documentation preparation)"], check=True)
    subprocess.run(["git", "push", "origin", f"HEAD:refs/heads/{branch}"], check=True)
    body = Path(os.environ["RUNNER_TEMP"]) / "blenny-preparation-pr.md"
    body.write_text("Prepare the version and generated engineering/user release notes from structured fragments.\n\nReview the source, notes and development acceptance before authorizing the annotated release tag. This PR does not publish a release.\n")
    subprocess.run(["gh", "pr", "create", "--repo", REPOSITORY, "--base", "main", "--head", branch,
                    "--title", f"chore(release): prepare {args.version}", "--body-file", str(body)], check=True)
    # GITHUB_TOKEN-created PRs do not trigger ordinary PR CI. Dispatch the same
    # unsigned development workflow explicitly, never the signing workflow.
    subprocess.run(["gh", "workflow", "run", "ci.yml", "--repo", REPOSITORY, "--ref", branch], check=True)


if __name__ == "__main__":
    main()
