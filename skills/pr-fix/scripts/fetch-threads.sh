#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/git.sh"

[[ $# -ge 2 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <PR 番号>"; exit 1; }

use_repo "$1"
pr=$2

info=$(repo_access "$repo") || { echo "$info"; exit 1; }
read -r owner name access <<< "$info"

case $access in
    write) echo "ACCESS write" ;;
    *) echo "ACCESS read（返信と解決は人がする）" ;;
esac

status=0
errors=$(mktemp)
trap 'rm -f "$errors"' EXIT
checks=$(cd "$repo" && gh pr checks "$pr" --json name,bucket,link \
    -q '.[] | select(.bucket == "fail") | "CI NG \(.name) \(.link)"' 2>"$errors") || status=$?
case $status in
    0 | 8) [[ -z $checks ]] || echo "$checks" ;;
    *) [[ $(<"$errors") == *"no checks reported"* ]] || { echo "NG gh pr checks が通らない: $(<"$errors")"; exit 1; } ;;
esac

gh api graphql --paginate -F owner="$owner" -F name="$name" -F pr="$pr" -f query='
query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { id isResolved path line comments(first: 1) { nodes { author { login } body } } }
      }
    }
  }
}' -q '
.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)
| "THREAD \(.id) \(.path):\(.line // "-") @\(.comments.nodes[0].author.login // "-"): \((.comments.nodes[0].body // "") | split("\n")[0] // "")"
'

gh api graphql --paginate -F owner="$owner" -F name="$name" -F pr="$pr" -f query='
query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $pr) {
      reviews(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { author { login } state body url }
      }
    }
  }
}' -q '
.data.repository.pullRequest.reviews.nodes[] | select((.body // "") != "")
| "REVIEW \(.state) @\(.author.login): \(.body | split("\n")[0]) \(.url)"
'

gh api graphql --paginate -F owner="$owner" -F name="$name" -F pr="$pr" -f query='
query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $pr) {
      comments(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { author { login } body url }
      }
    }
  }
}' -q '
.data.repository.pullRequest.comments.nodes[]
| "COMMENT @\(.author.login): \((.body // "") | split("\n")[0]) \(.url)"
'
