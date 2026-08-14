# nem-official-catalog

The official package catalog for [nem](https://github.com/vi-dev/nem-cli),
published to `ghcr.io/vi-dev/nem-official-catalog`.

## Consuming

nem configures this catalog by default. To add it explicitly:

    nem catalog add official ghcr.io/vi-dev/nem-official-catalog:v2

Tags: `:v2` moves with every release; immutable `v2.<UTC-timestamp>` tags pin
a release; a digest pin (`@sha256:…`) freezes it entirely.

## Contributing

Packages live at `pkgs/<name>/pkg.yaml`. CI validates every PR; merging to
`main` publishes the catalog. Every publish stamps an immutable
`v2.<UTC-timestamp>` tag, and a failed run never moves `:v2`.

Source-built packages (those with a `build:` section) support darwin/arm64,
linux/arm64, and linux/amd64; prebuilt packages may support all four
platforms. A new source-built package whose `build.deps` are also new must
land in dependency order, one PR each — build deps resolve from the
*published* catalog, not the PR.

## Runbook

### Roll back a bad release

A `v2.<timestamp>` tag is stamped for every attempted publish, including runs
that never promoted, so check the workflow run history for the release that
actually reached `:v2` before retagging.

    oras repo tags ghcr.io/vi-dev/nem-official-catalog   # find the previous release tag
    oras tag ghcr.io/vi-dev/nem-official-catalog:v2.<previous-timestamp> v2

### Rebuild a package's archives / force a republish

    gh workflow run publish.yml -f packages="<name> [<name>...]"

An empty `packages` input republishes the catalog index without rebuilding
any archives.

### nem regression escape hatch

CI runs nem's `unstable` channel. If a nem regression blocks publishing,
pin `NEM_VERSION` in `.github/actions/setup-nem/action.yml` to the last
good release tag until nem-cli fixes forward.
