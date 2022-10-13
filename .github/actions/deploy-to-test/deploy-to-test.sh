#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
  echo "1 parameters required: ISSUE_NUMBER"
  exit 1
fi

ISSUE_NUMBER="$1"

# Get the full PR details
PR=$(curl \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$ISSUE_NUMBER")

SHA=$(echo "$PR" | jq -r ".merge_commit_sha")
echo "SHA: $SHA"

# Switch to test branch and reset it to the merge commit SHA
git fetch --unshallow
git checkout -b test origin/test
git reset --hard "$SHA"

# Create a deployment for the merge commit SHA
DEPLOYMENT=$(curl \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/deployments" \
  -d "{\"ref\":\"$SHA\",\"environment\":\"test\",\"description\":\"Deploy request from action\"}")

DEPLOYMENT_ID=$(echo "$DEPLOYMENT" | jq -r ".id")

# Mark the deployment as succeeded
curl \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/deployments/$DEPLOYMENT_ID/statuses" \
  -d '{"environment":"test","state":"success"}'

# force push the merce branch SHA to upstream test
git push --force origin test

# label the PR: Deployed to Test
curl \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/labels" \
  -d '{"labels":["Deployed to Test"]}'
