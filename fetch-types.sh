#!/usr/bin/env bash


# hash the original file
OLD_HASH=$(sha256sum test.d.ts | cut -d ' ' -f 1)

# get the latest release tag
LATEST_TAG=$(curl -s https://api.github.com/repos/oven-sh/bun/releases/latest | grep "tag_name" | cut -d '"' -f 4)

echo "Latest tag: ${LATEST_TAG}"

# use the GitHub API to get the file content from that specific tag
curl -H "Accept: application/vnd.github.v3.raw" \
     -L "https://api.github.com/repos/oven-sh/bun/contents/packages/bun-types/test.d.ts?ref=${LATEST_TAG}" \
     -o test-new.d.ts

# hash the new file
NEW_HASH=$(sha256sum test-new.d.ts | cut -d ' ' -f 1)

# make sure the new file is not empty
if [ ! -s test-new.d.ts ]; then
    echo "New file is empty"
    rm test-new.d.ts
    exit 1
fi

# if the hashes are different, update the old file
if [ "$NEW_HASH" != "$OLD_HASH" ]; then
    mv test-new.d.ts test.d.ts
    echo "Updated test.d.ts"
    # commit the changes
    git add test.d.ts
    git commit -m "Update test.d.ts to ${LATEST_TAG}"
    git push
    # update the version in package.json
    sed -i '' "s/\"version\": \"[0-9\.]*\"/\"version\": \"${LATEST_TAG}\"/" package.json
    # publish the changes
    npm publish
    exit 0
fi

echo "No changes to test.d.ts"
rm test-new.d.ts
