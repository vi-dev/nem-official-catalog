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

# Where pkgs/ is read from: the repo checkout by default, or a mounted
# out-of-tree catalog when the caller sets it explicitly.
: "${CATALOG_DIR:=.}"

failed=()
tested=0
entries_seen=0

reset_state() {
  nem clean --all --yes
  rm -f "$NEM_HOME/nem.toml" "$NEM_HOME/nem.lock"
}

# Runs each entry's declared test steps against what was just installed.
# A pinned entry tests at its named version, since nem catalog test would
# otherwise resolve latest, testing a version other than the one just
# installed. A missing manifest is reported via ::warning:: rather than
# silently skipped; entries_seen/tested below catch every entry warning at
# once, so a broken CATALOG_DIR still fails the job instead of going green.
test_entries() {
  local entry name manifest args
  for entry in "$@"; do
    name="${entry%@*}"
    manifest="$CATALOG_DIR/pkgs/$name/pkg.yaml"
    if [ ! -f "$manifest" ]; then
      echo "::warning::no manifest at $manifest; ran no tests for $entry"
      continue
    fi
    args=("$manifest")
    [ "$entry" = "$name" ] || args+=(--version "${entry#*@}")
    tested=$((tested + 1))
    nem catalog test "${args[@]}" || failed+=("$entry (test)")
  done
}

flush() {
  [ "${#batch[@]}" -gt 0 ] || return 0
  echo "::group::${batch[*]}"
  reset_state
  if nem use -g "${batch[@]}"; then
    nem status -g
    test_entries "${batch[@]}"
  else
    # nem cancels a batch's remaining installs once one fails, so the batch
    # alone cannot say which entries were actually broken. Retry them singly.
    echo "batch failed; retrying its entries individually"
    for entry in "${batch[@]}"; do
      reset_state
      if nem use -g "$entry"; then
        test_entries "$entry"
      else
        failed+=("$entry")
      fi
    done
  fi
  echo "::endgroup::"
  batch=()
}

batch=()
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  entries_seen=$((entries_seen + 1))
  batch+=("$entry")
  [ "${#batch[@]}" -lt "$NEM_INSTALL_BATCH" ] || flush
done
flush

if [ "$entries_seen" -gt 0 ] && [ "$tested" -eq 0 ]; then
  echo "::error::processed $entries_seen entries but ran zero test steps (CATALOG_DIR=$CATALOG_DIR); every manifest lookup missed" >&2
  exit 1
fi

if [ "${#failed[@]}" -gt 0 ]; then
  printf 'Failed to install: %s\n' "${failed[@]}" >&2
  exit 1
fi
