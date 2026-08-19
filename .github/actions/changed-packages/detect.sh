#!/usr/bin/env bash
# Classifies packages whose manifests differ from the published catalog
# into source-built and prebuilt (package, version) entries, one per added
# version; an updated manifest with no version delta contributes its head
# version, so content-only edits (sha fixes, install steps) still get
# verified. Requires nem on PATH (setup-nem) plus jq.
#
# Env in:
#   CATALOG_REF     published catalog ref to diff the working tree against
#   GITHUB_OUTPUT   file receiving the outputs
# Out (GITHUB_OUTPUT):
#   source, prebuilt   JSON arrays of {package, version} entries
#   any                "true" | "false"
set -euo pipefail

diff_json=$(mktemp)
nem catalog diff "$CATALOG_REF" . --json > "$diff_json"

entries='[.[] | select(.status == "new" or .status == "updated")
  | select(.source == $src)
  | . as $r
  | (if ($r.versionsAdded | length) > 0 then $r.versionsAdded[] else $r.local end)
  | {package: $r.name, version: .}]'
{
  echo "source=$(jq -c --argjson src true "$entries" "$diff_json")"
  echo "prebuilt=$(jq -c --argjson src false "$entries" "$diff_json")"
  echo "any=$(jq -r 'any(.[]; .status != "unchanged")' "$diff_json")"
} >> "$GITHUB_OUTPUT"
