#!/usr/bin/env bash
#
# Usage:
#   ./fetch-types.sh                # normal operation
#   DEBUG=true ./fetch-types.sh     # debug mode (skips git operations and npm publish)
#

# debug flag - set to true to skip git operations and npm publish
DEBUG=${DEBUG:-false}

# hash the original file
if [ -f test.d.ts ]; then
    OLD_HASH=$(sha256sum test.d.ts | cut -d ' ' -f 1)
else
    # if the file doesn't exist yet, set a dummy hash that won't match anything
    OLD_HASH="file-does-not-exist"
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG] test.d.ts does not exist yet, will create it"
    fi
fi

# get the current version number from package.json using grep and cut (pure shell)
CURRENT_VERSION=$(grep -o '"version": "[^"]*"' package.json | cut -d'"' -f4)

# validate that we have a version
if [[ -z "$CURRENT_VERSION" ]]; then
    echo "error: could not extract version from package.json"
    exit 1
fi

# increment the patch version
# extract major, minor, and patch components
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)

# handle complex version formats (extract patch and preserve any suffixes)
if [[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(.*)$ ]]; then
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
    VERSION_SUFFIX="${BASH_REMATCH[4]}"
else
    # fallback to simpler parsing if regex doesn't match
    PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3 | cut -d+ -f1 | cut -d- -f1)
    VERSION_SUFFIX=""
fi

# validate version components
if [[ -z "$MAJOR" || -z "$MINOR" || -z "$PATCH" ]]; then
    echo "error: invalid version format in package.json: $CURRENT_VERSION"
    echo "expected format: major.minor.patch"
    exit 1
fi

# ensure patch is a number
if ! [[ "$PATCH" =~ ^[0-9]+$ ]]; then
    echo "error: patch version is not a number: $PATCH"
    exit 1
fi

# increment patch
PATCH=$((PATCH + 1))

# construct the new version (without any suffix that might have been in the original)
INCREMENTED_VERSION="${MAJOR}.${MINOR}.${PATCH}"

# get the latest release tag
LATEST_TAG=$(curl -s https://api.github.com/repos/oven-sh/bun/releases/latest | grep "tag_name" | cut -d '"' -f 4)

# check if we got a valid tag
if [[ -z "$LATEST_TAG" ]]; then
    echo "error: failed to get latest release tag from GitHub"
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG] GitHub API response:"
        curl -s https://api.github.com/repos/oven-sh/bun/releases/latest
        echo "[DEBUG] This could be due to GitHub API rate limiting. Consider using a GitHub token."
    fi
    exit 1
fi

# extract just the version numbers (major.minor.patch) regardless of prefix format
LATEST_TAG_FOR_NPM="${INCREMENTED_VERSION}+${LATEST_TAG}"

# debug output
if [ "$DEBUG" = "true" ]; then
    echo "[DEBUG] Current version: ${CURRENT_VERSION}"
    echo "[DEBUG] Incremented version: ${INCREMENTED_VERSION}"
    echo "[DEBUG] Latest tag: ${LATEST_TAG}"
    echo "[DEBUG] New version for NPM: ${LATEST_TAG_FOR_NPM}"
    echo "[DEBUG] Fetching test.d.ts from GitHub for tag: ${LATEST_TAG}"
fi

# use the GitHub API to get the file content from that specific tag
curl -H "Accept: application/vnd.github.v3.raw" \
     -L "https://api.github.com/repos/oven-sh/bun/contents/packages/bun-types/test.d.ts?ref=${LATEST_TAG}" \
     -o test-new.d.ts

# check if curl was successful
if [ $? -ne 0 ]; then
    echo "error: failed to fetch test.d.ts from GitHub"
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG] curl command failed with exit code $?"
    fi
    rm -f test-new.d.ts
    exit 1
fi

# hash the new file
NEW_HASH=$(sha256sum test-new.d.ts | cut -d ' ' -f 1)

# debug output for hashes
if [ "$DEBUG" = "true" ]; then
    echo "[DEBUG] Old hash: ${OLD_HASH}"
    echo "[DEBUG] New hash: ${NEW_HASH}"
fi

# make sure the new file is not empty
if [ ! -s test-new.d.ts ]; then
    echo "new file is empty"
    rm test-new.d.ts
    exit 1
fi

# if the hashes are different, update the old file
if [ "$NEW_HASH" != "$OLD_HASH" ]; then
    if [ "$DEBUG" != "true" ]; then
        # rename the new file to the original file
        mv test-new.d.ts test.d.ts
        echo "updated test.d.ts"

        # commit the changes
        git add test.d.ts
        git commit --allow-empty -m "update test.d.ts to ${LATEST_TAG} (bump to ${INCREMENTED_VERSION})"
        git push

        # update the version in package.json using sed (pure shell)
        # this works across different sed versions by creating a backup with .bak extension
        sed -i.bak "s/\"version\": \"[^\"]*\"/\"version\": \"${LATEST_TAG_FOR_NPM}\"/" package.json
        rm package.json.bak  # remove the backup file

        echo "version bumped from ${CURRENT_VERSION} to ${LATEST_TAG_FOR_NPM}"
        
        # publish the changes
        npm publish
    else
        echo "[DEBUG] would commit and push changes with message: update test.d.ts to ${LATEST_TAG} (bump to ${INCREMENTED_VERSION})"
        echo "[DEBUG] would update package.json version from ${CURRENT_VERSION} to ${LATEST_TAG_FOR_NPM}"
        echo "[DEBUG] would run: npm publish"
    fi

    exit 0
fi

echo "No changes to test.d.ts"
rm test-new.d.ts
