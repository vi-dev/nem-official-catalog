#!/usr/bin/env bash
# Runs install-each.sh inside the rootless nem-cli image, consuming the
# catalog the way an end user's container would: non-root, minimal debian,
# resolving against $CATALOG_REF. Entries come from stdin, same contract
# as install-each.sh.
#
# Credentials reach nem via DOCKER_CONFIG so nothing here depends on the
# image's user home layout.
#
# CATALOG_DIR tells install-each.sh where pkgs/<name>/pkg.yaml live: the
# checkout mounted at /checkout by default, or the separately mounted
# /catalog when CATALOG_REF names an out-of-tree dir catalog.
#
# Env in:
#   CATALOG_REF   catalog configured as "official" in the container: an OCI
#                 ref, or a dir path mounted read-only into the container
#   IMAGE         image to run (default ghcr.io/vi-dev/nem-cli:unstable-rootless)
set -euo pipefail

: "${IMAGE:=ghcr.io/vi-dev/nem-cli:unstable-rootless}"
: "${CATALOG_REF:?CATALOG_REF is required}"

scripts=$(cd "$(dirname "$0")" && pwd)
checkout=$(cd "$scripts/../.." && pwd)
args=(-v "$checkout:/checkout:ro" -e CATALOG_DIR=/checkout)
if [ -f "$HOME/.docker/config.json" ]; then
  args+=(-v "$HOME/.docker:/creds:ro" -e DOCKER_CONFIG=/creds)
fi
case "$CATALOG_REF" in
  /*|./*|../*|.)
    args+=(-v "$(cd "$CATALOG_REF" && pwd):/catalog:ro" -e CATALOG_REF=/catalog -e CATALOG_DIR=/catalog)
    ;;
  *)
    args+=(-e CATALOG_REF="$CATALOG_REF")
    ;;
esac

exec docker run --rm -i "${args[@]}" \
  --entrypoint bash \
  "$IMAGE" \
  -c '/checkout/.github/scripts/configure-catalog.sh && /checkout/.github/scripts/install-each.sh'
