#!/usr/bin/env bash
# Re-scores every team in a download from the website's
# db/download-snapshots.ts, each in its own locked-down container, using the
# official template's scoring code. See README.md for usage.
set -euo pipefail

if [ $# -ne 2 ] || [ -z "${STUDENT_FILES:-}" ]; then
  echo "usage: STUDENT_FILES=\"myAI.py ...\" $0 <snapshots-dir> <official-template-repo>" >&2
  exit 1
fi

SNAPSHOTS=$(cd "$1" && pwd)
TEMPLATE=$2
EXTRA_PACKAGES=${EXTRA_PACKAGES:-}
TIMEOUT=${TIMEOUT:-3600}
MEMORY=${MEMORY:-4g}
CPUS=${CPUS:-2}
HERE=$(cd "$(dirname "$0")" && pwd)
IMAGE=wai-results

# A clean copy of the template's last commit, so local edits and untracked
# files (venvs, trained models) don't leak in
official=$(mktemp -d)
trap 'rm -rf "$official"' EXIT
git -C "$TEMPLATE" archive HEAD | tar -x -C "$official"
echo "Official template: $(git -C "$TEMPLATE" rev-parse --short HEAD)"

echo "Building $IMAGE..."
docker build --quiet --tag "$IMAGE" \
  --build-context template="$official" \
  --build-arg EXTRA_PACKAGES="$EXTRA_PACKAGES" \
  "$HERE" >/dev/null

results="$SNAPSHOTS/results.csv"
mkdir -p "$SNAPSHOTS/logs"
echo "repo,ci_score,final_score,status,edited_template_files" >"$results"

tail -n +2 "$SNAPSHOTS/manifest.csv" | while IFS=, read -r repo _ ci_score _ folder; do
  if [ -z "$folder" ] || [ ! -d "$SNAPSHOTS/$folder" ]; then
    echo "$repo,$ci_score,,no snapshot," >>"$results"
    echo "- $repo: no snapshot"
    continue
  fi

  echo "> $repo"
  out=$(docker run --rm --network none \
    --memory "$MEMORY" --cpus "$CPUS" --pids-limit 256 \
    --cap-drop ALL --security-opt no-new-privileges \
    --read-only --tmpfs /work:size=1g,mode=1777 --tmpfs /tmp:size=512m,mode=1777 \
    -e HOME=/tmp -e STUDENT_FILES="$STUDENT_FILES" -e TIMEOUT="$TIMEOUT" \
    -v "$SNAPSHOTS/$folder":/submission:ro -v "$official":/official:ro \
    "$IMAGE" </dev/null 2>"$SNAPSHOTS/logs/$folder.log") || true

  status=$(sed -n 's/^status=//p' <<<"$out")
  score=$(sed -n 's/^score=//p' <<<"$out")
  edited=$(sed -n 's/^edited=//p' <<<"$out")
  echo "$repo,$ci_score,$score,${status:-error (see log)},$edited" >>"$results"
  echo "  ${status:-error (see log)} ${score}"
done

echo
# blanks become "-" so column doesn't merge empty fields
tail -n +2 "$results" | sort -t, -k3,3gr \
  | sed -e 's/,,/,-,/g' -e 's/,,/,-,/g' -e 's/,$/,-/' | column -s, -t
echo
echo "Results: $results"
echo "Logs:    $SNAPSHOTS/logs/"
