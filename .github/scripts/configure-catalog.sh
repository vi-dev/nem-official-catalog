#!/usr/bin/env bash
# Points the "official" catalog at $CATALOG_REF. nem's first run writes a
# default official entry; replace it so the caller resolves against exactly
# the requested ref, and nothing else. Dir catalogs have no OCI mirror to
# sync.
set -euo pipefail

: "${CATALOG_REF:?CATALOG_REF is required}"

nem catalog remove official 2>/dev/null || true
nem catalog add official "$CATALOG_REF"
case "$CATALOG_REF" in
  /*|./*|../*|.) ;;
  *) nem catalog update ;;
esac
