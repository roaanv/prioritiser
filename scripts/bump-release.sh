#!/usr/bin/env bash
# Bump MARKETING_VERSION in project.yml, commit, tag, and push — which triggers
# the signed/notarized release workflow (.github/workflows/release.yml).
#
# Usage (normally via the Makefile):
#   make release-patch     # 0.1.0 -> 0.1.1   (scripts/bump-release.sh patch)
#   make release-minor     # 0.1.0 -> 0.2.0   (scripts/bump-release.sh minor)
#
# Safety: refuses unless on `main`, the working tree is clean, and the target
# tag doesn't already exist. The branch + tag are pushed atomically.

set -euo pipefail

bump="${1:-}"
case "$bump" in
    patch|minor) ;;
    *) echo "Usage: $0 {patch|minor}" >&2; exit 1 ;;
esac

if [ ! -f project.yml ]; then
    echo "Error: project.yml not found — run from the repo root." >&2
    exit 1
fi

branch=$(git symbolic-ref --short HEAD)
if [ "$branch" != "main" ]; then
    echo "Error: releases are cut from 'main' (currently on '$branch')." >&2
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: working tree is dirty — commit or stash changes first." >&2
    exit 1
fi

# Parse the current MARKETING_VERSION (expects X.Y.Z).
current=$(grep -E '^[[:space:]]*MARKETING_VERSION:' project.yml | head -1 \
    | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')
if ! printf '%s' "$current" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Error: could not parse MARKETING_VERSION from project.yml (got '$current')." >&2
    exit 1
fi

IFS=. read -r major minor patch <<< "$current"
case "$bump" in
    patch) patch=$((patch + 1)) ;;
    minor) minor=$((minor + 1)); patch=0 ;;
esac
new="$major.$minor.$patch"
tag="v$new"

if git rev-parse "$tag" >/dev/null 2>&1; then
    echo "Error: tag $tag already exists." >&2
    exit 1
fi

echo "Bumping MARKETING_VERSION $current -> $new"

# Rewrite the version in place (temp file keeps this portable across sed flavors).
tmp=$(mktemp)
sed -E "s/^([[:space:]]*MARKETING_VERSION:[[:space:]]*\")[0-9]+\.[0-9]+\.[0-9]+(\")/\1$new\2/" \
    project.yml > "$tmp"
mv "$tmp" project.yml

git add project.yml
git commit -m "release: $tag"
git tag "$tag"

echo "Pushing main + $tag (this triggers the release workflow)..."
git push --atomic origin main "$tag"

echo "Released $tag. Watch: https://github.com/roaanv/prioritiser/actions"
echo "(Remember to move any [Unreleased] changelog notes under [$new].)"
