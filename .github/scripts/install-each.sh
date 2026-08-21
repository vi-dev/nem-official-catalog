#!/usr/bin/env bash
# Installs the entries read from stdin ("<pkg>" or "<pkg>@<version>") against
# the catalog setup-nem already configured.
#
# Entries are installed in batches: nem installs a batch concurrently, capped
# at min(NumCPU, 8), which is several times faster than one call per entry.
# Batches are kept small because installed state is only discarded between
# them, and a run over hundreds of packages would otherwise exhaust the
# runner's disk. Override the size with NEM_INSTALL_BATCH.
#
# Discarding state has to take the declarations with the packages: `nem use`
# reinstalls anything declared but missing, so keeping them would restore
# every earlier batch. The catalog config stays — rebuilding it would re-sync
# an oci catalog from the registry once per batch.
#
# Entries excluded on this platform install nothing and still succeed. Every
# failure is collected so one bad manifest does not hide the rest.
set -uo pipefail

: "${NEM_HOME:=$HOME/.nem}"
: "${NEM_INSTALL_BATCH:=8}"

failed=()

reset_state() {
  rm -rf "$NEM_HOME/nem.toml" "$NEM_HOME/nem.lock" "$NEM_HOME/packages" "$NEM_HOME/tmp"
}

flush() {
  [ "${#batch[@]}" -gt 0 ] || return 0
  echo "::group::${batch[*]}"
  reset_state
  if nem use -g "${batch[@]}"; then
    nem status -g
  else
    # nem cancels a batch's remaining installs once one fails, so the batch
    # alone cannot say which entries were actually broken. Retry them singly.
    echo "batch failed; retrying its entries individually"
    for entry in "${batch[@]}"; do
      reset_state
      nem use -g "$entry" || failed+=("$entry")
    done
  fi
  echo "::endgroup::"
  batch=()
}

batch=()
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  batch+=("$entry")
  [ "${#batch[@]}" -lt "$NEM_INSTALL_BATCH" ] || flush
done
flush

if [ "${#failed[@]}" -gt 0 ]; then
  printf 'Failed to install: %s\n' "${failed[@]}" >&2
  exit 1
fi
