#!/bin/bash

# Verify that Action calls that are pinned (not locally called)
# use the same referemnce as the relealse tag.
# See reasoning in ./github/actions/README.md

set -euo pipefail

# Verify the tag has semver format.
cd __EXAMPLE_PACKAGE__
# shellcheck source=/dev/null
source "./.github/workflows/scripts/e2e-utils.sh"
major=$(version_major "$RELEASE_TAG")
minor=$(version_minor "$RELEASE_TAG")
patch=$(version_patch "$RELEASE_TAG")
rc=$(version_rc "$RELEASE_TAG")
echo "\"$RELEASE_TAG\" follows semver:"
echo "major: $major"
echo "minor: $minor"
echo "patch: $patch"
echo "rc: $rc"
cd -

# Verify internal Actions are referenced by the release tag.
cd __THIS_REPO__
results=$(
    find .github/workflows/ -maxdepth 1 -type f -print0 -name '*.yaml' -o -name '*.yml' |
        xargs -0 grep -Pn "slsa-framework/slsa-github-generator/.github/actions/.*@(?!$RELEASE_TAG)" |
        sed 's/\(.*:\) *uses:.*\(\/.*\)/\1 [...]\2/' ||
        true
)
if [[ "$results" != "" ]]; then
    echo "Some Actions are not referenced via the correct release tag \"$RELEASE_TAG\""
    echo "$results"
    exit 1
fi

# Verify documentation refers to the most recent release tag
# TODO(https://github.com/slsa-framework/slsa-github-generator/issues/409):
#   Include "./internal/builders/container/*" in this check
results=$(
    find . -name "*.md" -not -path ./internal/builders/container/* -print0 |
        xargs -0 grep -Pn "uses: slsa-framework/slsa-github-generator/.*@(?!<|$RELEASE_TAG)" |
        sed "s/\(.*:\) *uses:.*\(\/.*\)/\1 [...]\2/" ||
        true
)

if [[ "$results" != "" ]]; then
    echo "Some documentation refers to an incorrect release tag"
    echo "Allowed tags are \"<pseudo_tags>\" or \"$RELEASE_TAG\""
    echo "$results"
    exit 1
fi
