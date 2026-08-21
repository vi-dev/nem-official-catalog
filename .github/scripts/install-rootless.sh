#!/usr/bin/env bash
# Runs install-each.sh inside the rootless nem-cli image, consuming the
# catalog the way an end user's container would: non-root, minimal debian,
# resolving against $CATALOG_REF. Entries come from stdin, same contract
# as install-each.sh.
#
# Credentials reach nem via DOCKER_CONFIG so nothing here depends on the
# image's user home layout.
#
# Env in:
#   CATALOG_REF   catalog configured as "official" in the container: an OCI
#                 ref, or a dir path mounted read-only into the container
#   IMAGE         image to run (default ghcr.io/vi-dev/nem-cli:unstable-rootless)
set -euo pipefail

: "${IMAGE:=ghcr.io/vi-dev/nem-cli:unstable-rootless}"
: "${CATALOG_REF:?CATALOG_REF is required}"

args=(-v "$(cd "$(dirname "$0")" && pwd):/scripts:ro")
if [ -f "$HOME/.docker/config.json" ]; then
  args+=(-v "$HOME/.docker:/creds:ro" -e DOCKER_CONFIG=/creds)
fi
case "$CATALOG_REF" in
  /*|./*|../*|.)
    args+=(-v "$(cd "$CATALOG_REF" && pwd):/catalog:ro" -e CATALOG_REF=/catalog)
    ;;
  *)
    args+=(-e CATALOG_REF="$CATALOG_REF")
    ;;
esac

exec docker run --rm -i "${args[@]}" \
  --entrypoint bash \
  "$IMAGE" \
  -c '/scripts/configure-catalog.sh && /scripts/install-each.sh'
