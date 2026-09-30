#!/usr/bin/env python3
"""Parse workflow YAML and enforce the repository's release boundaries locally."""
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
APPROVED_ACTIONS = {
    "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1",
    "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a",
    "actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c",
}


def check(root=ROOT):
    workflows = {}
    for path in sorted((root / ".github/workflows").glob("*.yml")):
        # Ruby/Psych is bundled on the supported Mac and both selected hosted images.
        raw = subprocess.check_output(["ruby", "-rpsych", "-rjson", "-e",
                                       "puts JSON.generate(Psych.safe_load(File.read(ARGV[0]), aliases: false))", str(path)], text=True)
        workflow = json.loads(raw)
        workflows[path.stem] = workflow
        for job_name, job in workflow["jobs"].items():
            if "environment" in job:
                raise ValueError("Release workflow must not introduce a required environment review")
            if not job.get("timeout-minutes"):
                raise ValueError("Every job needs a bounded timeout")
            for step in job["steps"]:
                if "uses" in step and step["uses"] not in APPROVED_ACTIONS:
                    raise ValueError("Actions must be pinned to reviewed commit SHAs")
                if "${{" in step.get("run", ""):
                    raise ValueError("Pass event text through an environment variable, never shell interpolation")
                text = json.dumps(step)
                if "secrets." in text and not (path.stem == "release" and step.get("name") == "Sign and package on GitHub"):
                    raise ValueError("Signing secrets are restricted to the hosted signing step")
    if set(workflows) != {"ci", "release", "release-prepare"}:
        raise ValueError("Expected exactly the three approved workflows")
    ci, release, preparation = (workflows[n] for n in ("ci", "release", "release-prepare"))
    if ci["permissions"] != {"contents": "read"} or release["permissions"] != {} or preparation["permissions"] != {}:
        raise ValueError("Unexpected default workflow permissions")
    events = release.get("on", release.get("true"))
    if set(events) != {"push", "workflow_dispatch"} or events["push"] != {"tags": ["v*.*.*"]}:
        raise ValueError("Expected version-tag pushes and explicit manual release operations")
    inputs = events["workflow_dispatch"]["inputs"]
    if (inputs["operation"]["default"] != "verification" or inputs["operation"]["type"] != "choice"
            or inputs["operation"]["options"] != ["verification", "signing-diagnostics", "publish"]
            or inputs["release_tag"]["type"] != "string" or inputs["release_tag"]["default"] != ""):
        raise ValueError("Manual publication must be explicit; the default stays verification-only")
    for name, job in release["jobs"].items():
        checkouts = {s["with"]["path"]: s["with"] for s in job["steps"] if s.get("uses", "").startswith("actions/checkout@")}
        source_ref = "${{ steps.mode.outputs.source_sha }}" if name == "build" else "${{ needs.build.outputs.source_sha }}"
        if (set(checkouts) != {"controller", "source"} or checkouts["controller"]["ref"] != "${{ github.sha }}"
                or checkouts["source"]["ref"] != source_ref or job["defaults"]["run"]["working-directory"] != "source"):
            raise ValueError("Keep immutable workflow/controller and selected application source separate in every job")
    if release["concurrency"] != {"group": "blenny-public-release", "cancel-in-progress": False}:
        raise ValueError("Public release concurrency must span the whole repository")
    if release["jobs"]["publish"]["if"] != "needs.build.outputs.production == 'true'":
        raise ValueError("Verification-only runs must never publish")
    for job in [ci["jobs"]["verify"], release["jobs"]["build"]]:
        if job["runs-on"] != "xcode-27" or job["env"]["DEVELOPER_DIR"] != "/Applications/Xcode_27.0.app/Contents/Developer":
            raise ValueError("Pin the supported ARM64 macOS/Xcode 27 toolchain")
    if any("secrets." in json.dumps(w) for w in [ci, preparation]):
        raise ValueError("Development and preparation workflows must not access signing secrets")
    print("Workflow YAML, pinned actions, permissions, bounded execution and trigger boundaries: PASS")


if __name__ == "__main__":
    check()
