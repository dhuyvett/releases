#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
    echo "1 parameters required: ISSUE_NUMBER"
    exit 1
fi

ISSUE_NUMBER="$1"
PR=$(curl -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$ISSUE_NUMBER")

SHA=$(echo "$PR" | jq -r ".merge_commit_sha")

echo "SHA: $SHA"

git fetch --all
git checkout -b test origin/test
git reset --hard "$SHA"
git push --force origin test

curl -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/labels" -d '{"labels":["Deployed to Test"]}'
