#!/bin/zsh

set -euo pipefail

version=""
base_ref=""
allow_dirty=false
phase=pre-trigger

usage() {
  print -u2 "Usage: $0 --version X.Y.Z --base PREVIOUS_TAG [--phase prepare|pre-trigger|published] [--allow-dirty]"
  exit 64
}

while (( $# > 0 )); do
  case "$1" in
    --version)
      (( $# >= 2 )) || usage
      version="$2"
      shift 2
      ;;
    --base)
      (( $# >= 2 )) || usage
      base_ref="$2"
      shift 2
      ;;
    --allow-dirty)
      allow_dirty=true
      shift
      ;;
    --phase)
      (( $# >= 2 )) || usage
      phase="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

[[ "$version" == <->.<->.<-> ]] || usage
[[ -n "$base_ref" ]] || usage
[[ "$phase" == prepare || "$phase" == pre-trigger || "$phase" == published ]] || usage
[[ "$phase" == prepare || "$allow_dirty" == false ]] || { print -u2 '--allow-dirty is preparation-only'; exit 64; }

repository_root=$(git rev-parse --show-toplevel)
cd "$repository_root"

failures=0

fail() {
  print -u2 "FAIL: $1"
  (( failures += 1 ))
}

pass() {
  print "PASS: $1"
}

git rev-parse --verify "$base_ref^{commit}" >/dev/null 2>&1 \
  || fail "base ref does not resolve to a commit: $base_ref"

if git merge-base --is-ancestor "$base_ref" HEAD; then
  pass "$base_ref is an ancestor of HEAD"
else
  fail "$base_ref is not an ancestor of HEAD"
fi

if $allow_dirty || [[ -z "$(git status --porcelain)" ]]; then
  pass "working tree policy satisfied"
else
  fail "working tree is not clean"
fi

if git diff --check "$base_ref..HEAD" && git diff --check; then
  pass "Git whitespace checks"
else
  fail "Git whitespace checks"
fi

range="$base_ref..HEAD"
commit_count=$(git rev-list --count "$range")
if (( commit_count > 0 )); then
  pass "$commit_count commit(s) found in $range"
else
  if [[ "$phase" == prepare ]]; then
    print "INFO: version range contains no commits; preparation does not authorize a commit"
  else
    fail "version range contains no commits: $range"
  fi
fi

bad_subjects=$(git log --format='%s' "$range" | while IFS= read -r subject; do
  if [[ ! "$subject" =~ '^(feat|fix|docs|refactor|perf|test|style|build|ci|chore)(\([^)]+\))?: .+' ]]; then
    print -r -- "$subject"
  fi
done)
if [[ -z "$bad_subjects" ]]; then
  pass "version commit subjects follow the repository convention"
else
  fail "non-conforming commit subjects:\n$bad_subjects"
fi

ai_pattern='(generated[ -]by|co-authored-by:.*(claude|chatgpt|openai|codex))'
if git log --format='%B' "$range" | grep -Eiq "$ai_pattern"; then
  fail "version commit messages contain prohibited AI attribution"
else
  pass "version commit messages contain no AI attribution"
fi

forbidden_paths=$(git log --all --name-only --pretty=format: | sort -u | grep -E \
  '(^|/)(LocalData|LocalNotes|DerivedData|\.build|build)/|\.(app|dSYM|xcresult|p12|pem|key|mobileprovision|provisionprofile)(/|$)' \
  || true)
if [[ -z "$forbidden_paths" ]]; then
  pass "reachable history contains no forbidden artifact paths"
else
  fail "reachable history contains forbidden artifact paths:\n$forbidden_paths"
fi

candidate_paths=(${(f)"$(git ls-files --cached --others --exclude-standard)"})
forbidden_candidate_paths=$(print -l -- "${candidate_paths[@]}" | grep -E \
  '(^|/)(LocalData|LocalNotes|DerivedData|\.build|build)/|\.(app|dSYM|xcresult|p12|pem|key|mobileprovision|provisionprofile)(/|$)' \
  || true)
if [[ -z "$forbidden_candidate_paths" ]]; then
  pass "current candidate paths contain no forbidden artifacts"
else
  fail "current candidate paths contain forbidden artifacts:\n$forbidden_candidate_paths"
fi

history_revisions=(${(f)"$(git rev-list --all)"})
private_key_pattern='BEGIN [A-Z ]*PRIVATE K''EY'
github_token_pattern='(gh''p_[[:alnum:]]{20,}|github_pat''_[[:alnum:]_]{20,})'
absolute_user_pattern='/Us''ers/[^/[:space:]]+/'
secret_hits=""
for pattern in "$private_key_pattern" "$github_token_pattern" "$absolute_user_pattern"; do
  hits=$(git grep -n -I -E "$pattern" $history_revisions -- . 2>/dev/null || true)
  if [[ -n "$hits" ]]; then
    secret_hits+="$hits\n"
  fi
  for file_path in "${candidate_paths[@]}"; do
    [[ -f "$file_path" ]] || continue
    hits=$(grep -nEI "$pattern" -- "$file_path" 2>/dev/null || true)
    if [[ -n "$hits" ]]; then
      secret_hits+="$file_path:$hits\n"
    fi
  done
done
if [[ -z "$secret_hits" ]]; then
  pass "reachable and current content contains no private keys, GitHub tokens, or personal absolute paths"
else
  fail "sensitive content found in reachable or current content:\n$secret_hits"
fi

metadata=$(git log --all --format='%an <%ae> | %cn <%ce>' | sort -u)
print "INFO: reachable author/committer identities:"
print -r -- "$metadata"

large_files=""
mach_o_files=""
for file_path in "${candidate_paths[@]}"; do
  [[ -f "$file_path" ]] || continue
  size=$(stat -f '%z' "$file_path")
  if (( size > 5242880 )); then
    large_files+="$file_path ($size bytes)\n"
  fi
  if file -b "$file_path" | grep -q 'Mach-O'; then
    mach_o_files+="$file_path\n"
  fi
done
if [[ -z "$large_files" ]]; then
  pass "no tracked file exceeds 5 MiB"
else
  fail "unexpected large tracked files:\n$large_files"
fi
if [[ -z "$mach_o_files" ]]; then
  pass "no tracked Mach-O binaries"
else
  fail "tracked Mach-O binaries found:\n$mach_o_files"
fi

spike_path="docs/TECH_SPIKE_${version}.md"
[[ -f "$spike_path" ]] \
  && pass "$spike_path exists" \
  || fail "$spike_path is missing"

bundle_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Config/Info.plist)
[[ "$bundle_version" == "$version" ]] \
  && pass "Info.plist version is $version" \
  || fail "Info.plist version is $bundle_version, expected $version"

roadmap_section=$(awk -v version="$version" '
  index($0, "## " version " ") == 1 { collecting = 1 }
  collecting && index($0, "## ") == 1 && index($0, "## " version " ") != 1 { exit }
  collecting { print }
' docs/ROADMAP.md)
if [[ "$version" == 0.* ]]; then
  if print -r -- "$roadmap_section" | grep -Fq "Status: **Complete" \
    && grep -Fq "Version \`$version\` completed" README.md \
    && grep -Eq "Current phase: \`$version\`.*complete" PROJECT_BRIEF.md; then
    pass "top-level version documents mention a completed $version milestone"
  else
    fail "top-level version documents are not aligned for $version"
  fi
else
  if python3 scripts/release_tools.py check && python3 scripts/release_tools.py coverage \
    && grep -Fq "$version" PROJECT_BRIEF.md \
    && print -r -- "$roadmap_section" | grep -Fq "$version"; then
    pass "prepared version documents and contribution coverage agree for $version"
  else
    fail "prepared version documents disagree for $version"
  fi
  if [[ "$phase" == pre-trigger ]]; then
    python3 scripts/release_tools.py acceptance \
      && pass 'development acceptance recorded before the trigger' \
      || fail 'pre-trigger development acceptance is incomplete or stale'
  elif [[ "$phase" == published ]]; then
    python3 - "$version" <<'PUBLISHED' \
      && pass 'published receipt and feed agree' \
      || fail 'published receipt or feed evidence is missing'
import json,sys,xml.etree.ElementTree as ET
from pathlib import Path
version=sys.argv[1]
receipt=json.loads(Path('docs/public-release.json').read_text())
assert receipt['status']=='published' and receipt['version']==version
assert receipt['anonymousAssetVerification'] is True
assert any(i.findtext('{http://www.andymatuschak.org/xml-namespaces/sparkle}shortVersionString')==version for i in ET.parse('appcast.xml').findall('channel/item'))
PUBLISHED
  else
    print 'INFO: owner acceptance, source closure and hosted publication are checked at their respective phases'
  fi
fi

tag="v$version"
if git rev-parse --verify "refs/tags/$tag" >/dev/null 2>&1; then
  tag_type=$(git cat-file -t "$tag")
  tag_target=$(git rev-list -n 1 "$tag")
  if [[ "$phase" == published && -f docs/public-release.json ]]; then
    head_target=$(python3 -c 'import json; print(json.load(open("docs/public-release.json"))["sourceCommit"])')
  else
    head_target=$(git rev-parse HEAD)
  fi
  [[ "$tag_type" == "tag" ]] \
    && pass "$tag is annotated" \
    || fail "$tag is not annotated"
  if [[ "$tag_target" == "$head_target" ]]; then
    pass "$tag points to the audited release source ($head_target)"
  elif [[ "$phase" == prepare ]] \
    && git merge-base --is-ancestor "$tag_target" HEAD \
    && git diff --quiet "$tag_target" -- Sources Assets Config Package.swift Package.resolved LICENSE NOTICE THIRD_PARTY_NOTICES.txt; then
    pass "$tag is preserved; application inputs are unchanged while release tooling is prepared"
  else
    fail "$tag points to $tag_target instead of release source $head_target"
  fi
else
  print "INFO: $tag is absent and may be created only after the full audit passes"
fi

if git fsck --full --strict >/dev/null; then
  pass "Git object database integrity"
else
  fail "Git object database integrity"
fi

if (( failures > 0 )); then
  print -u2 "Release audit failed with $failures finding(s)."
  exit 1
fi

print "Release audit passed for Blenny $version."
