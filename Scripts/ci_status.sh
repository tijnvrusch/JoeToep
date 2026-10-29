#!/usr/bin/env bash
# Toont de status van de laatste GitHub Actions-build (macOS/iOS-compilatie) voor de huidige branch,
# en bij een fout de compilerfouten. Gebruik: Scripts/ci_status.sh [branch]
set -euo pipefail
REPO=tijnvrusch/JoeToep
BRANCH=${1:-$(git rev-parse --abbrev-ref HEAD)}
run=$(gh api "repos/$REPO/actions/runs?branch=$BRANCH&per_page=1" --jq '.workflow_runs[0] | "\(.id) \(.status) \(.conclusion) \(.head_sha[0:7])"')
echo "Laatste run: $run"
id=${run%% *}
gh api "repos/$REPO/actions/runs/$id/jobs" --jq '.jobs[] | "\(.name): \(.status) \(.conclusion)"'
for job in $(gh api "repos/$REPO/actions/runs/$id/jobs" --jq '.jobs[] | select(.conclusion=="failure") | .id'); do
  echo "== fouten in job $job"
  gh api "repos/$REPO/actions/jobs/$job/logs" 2>/dev/null | grep -E "error:|FAILED|AssertionError" | sed 's/^[0-9TZ:.-]* //' | sort -u | head -80
done
