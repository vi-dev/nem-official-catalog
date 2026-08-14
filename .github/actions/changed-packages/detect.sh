#!/usr/bin/env bash
# Classifies pkg.yaml changes into source-built and prebuilt package lists.
# Runs on ubuntu runners only (bash >= 5; yq and jq preinstalled).
#
# Env in:
#   BASE, HEAD      diff endpoints; BASE empty or all-zeros disables the diff
#   THREE_DOT       "true" = merge-base diff (pull requests), else two-dot
#   PACKAGES        space-separated override; when set the diff is skipped
#   GITHUB_OUTPUT   file receiving the outputs
# Out (GITHUB_OUTPUT):
#   source, prebuilt, all   JSON arrays of package names
#   any                     "true" | "false"
set -euo pipefail

zeros=0000000000000000000000000000000000000000
if [ -n "${PACKAGES:-}" ]; then
  names="$PACKAGES"
elif [ -z "${BASE:-}" ] || [ "$BASE" = "$zeros" ]; then
  # First push to a branch (or a dispatch without an override) has no
  # meaningful diff base; publish still runs and is idempotent.
  names=""
elif ! git cat-file -e "${BASE}^{commit}" 2>/dev/null; then
  # A force-push can leave the old head unreachable; treat as no-diff so
  # the run still republishes instead of dying under set -e on git diff.
  names=""
else
  sep=".."
  if [ "${THREE_DOT:-false}" = "true" ]; then sep="..."; fi
  names=$(git diff --name-only "${BASE}${sep}${HEAD}" -- 'pkgs/*/pkg.yaml' \
    | cut -d/ -f2 | sort -u | tr '\n' ' ')
fi

read -ra requested <<< "$names"
source_pkgs=()
prebuilt_pkgs=()
all_pkgs=()
for name in "${requested[@]}"; do
  f="pkgs/$name/pkg.yaml"
  [ -f "$f" ] || continue # deleted or unknown package: nothing to build or smoke
  all_pkgs+=("$name")
  if yq -e '.build' "$f" >/dev/null 2>&1; then
    source_pkgs+=("$name")
  else
    prebuilt_pkgs+=("$name")
  fi
done

json() { jq -cn '$ARGS.positional' --args -- "$@"; }
{
  echo "source=$(json "${source_pkgs[@]}")"
  echo "prebuilt=$(json "${prebuilt_pkgs[@]}")"
  echo "all=$(json "${all_pkgs[@]}")"
  if [ ${#all_pkgs[@]} -gt 0 ]; then echo "any=true"; else echo "any=false"; fi
} >> "$GITHUB_OUTPUT"
