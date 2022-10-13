#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
    echo "1 parameters required: ISSUE_NUMBER"
    exit 1
fi

ISSUE_NUMBER="$1"
PR=$(curl -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$ISSUE_NUMBER")

echo "$PR"

curl -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/labels" -d '{"labels":["Deployed to Test"]}'
