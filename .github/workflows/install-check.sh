#!/usr/bin/env bash
# Installs every changed prebuilt package from the working-tree catalog on
# the host platform. Each package gets its own $NEM_HOME, discarded once the
# package is verified: `nem use` reinstalls anything declared but missing, so
# a shared home would hold every package at once and exhaust the runner's
# disk. Packages the manifest excludes on this platform install nothing and
# still succeed. All failures are collected so one bad manifest does not hide
# the rest.
#
# Env in:
#   PREBUILT   JSON array of {package, version} entries
set -uo pipefail

failed=()
while read -r entry; do
  [ -n "$entry" ] || continue
  echo "::group::$entry"
  NEM_HOME=$(mktemp -d)
  export NEM_HOME
  nem catalog remove official >/dev/null 2>&1 || true
  if nem catalog add official "$PWD" >/dev/null && nem use -g "$entry"; then
    nem status -g
  else
    failed+=("$entry")
  fi
  rm -rf "$NEM_HOME"
  echo "::endgroup::"
done < <(jq -r '.[] | .package + "@" + .version' <<<"$PREBUILT")

if [ ${#failed[@]} -gt 0 ]; then
  printf 'Failed to install: %s\n' "${failed[@]}" >&2
  exit 1
fi
