#!/usr/bin/env python3
"""Require a fragment or an explicit rationale for a meaningful development diff."""
import argparse
import re

from release_tools import ROOT, git


def check(base, root=ROOT):
    if not base or set(base) == {"0"}:
        print("Initial source push: the complete first-public fragment set is checked separately")
        return
    if not re.fullmatch(r"[0-9a-f]{40}", base):
        raise ValueError("Expected an immutable development base SHA")
    paths = git("diff", "--name-only", base, "HEAD", root=root).splitlines()
    relevant = any(p.startswith(("Sources/", "Assets/", "Config/", "scripts/", ".github/")) or p in {"Package.swift", "Package.resolved"} for p in paths)
    if not relevant:
        return
    if any(p.startswith("docs/changes/") and p.endswith(".json") for p in paths):
        print("Meaningful development diff includes a release fragment")
        return
    commits = git("rev-list", f"{base}..HEAD", root=root).splitlines()
    for commit in commits:
        changed = git("diff-tree", "--no-commit-id", "--name-only", "-r", commit, root=root).splitlines()
        if any(p in paths for p in changed):
            message = git("show", "-s", "--format=%B", commit, root=root)
            if not re.search(r"(?m)^Release-Note: none \([^\n]+\)$", message):
                raise ValueError("Meaningful source change requires a release fragment or justified Release-Note trailer: " + commit)
    print("Meaningful development diff has an explicit no-entry rationale")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    args = parser.parse_args()
    check(args.base)
