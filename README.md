<p align="center">
  <img src=".github/nem-icon.svg" alt="nem logo" width="110" height="110">
</p>

<h1 align="center">nem-official-catalog</h1>

<p align="center">
  The official package catalog for <a href="https://github.com/vi-dev/nem-cli">nem</a>.
</p>

<p align="center">
  <a href="https://github.com/vi-dev/nem-official-catalog/actions/workflows/ci.yml"><img src="https://github.com/vi-dev/nem-official-catalog/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="pkgs/"><img src="https://img.shields.io/github/directory-file-count/vi-dev/nem-official-catalog/pkgs?type=dir&label=packages&color=d8843a" alt="Packages"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/vi-dev/nem-official-catalog?color=blue" alt="License: MIT"></a>
</p>

> [!IMPORTANT]
> Like [`nem`](https://github.com/vi-dev/nem-cli) itself, this catalog is in
> active development and is provided **as is**, without warranty of any kind.
> Packages may change or disappear without notice.

The official public package catalog for
[`nem`](https://github.com/vi-dev/nem-cli), a CLI for managing per-directory
developer environments.

This repository contains only `pkg.yaml` package manifests under
[`pkgs/`](pkgs/). It carries no code — the manifest schema and all install
behaviour are defined by `nem` itself. The catalog is published as an OCI
image to **`ghcr.io/vi-dev/nem-official-catalog`** on every change to `main`.

## Using this catalog

`nem` configures this catalog on first run — no `nem catalog add` step. Just
start using packages:

```sh
nem search kubectl
nem use kubectl
```

> [!TIP]
> The `:v2` tag moves with every release. For reproducible setups, pin the
> catalog to a digest instead:
>
> ```sh
> nem catalog remove official
> nem catalog add official ghcr.io/vi-dev/nem-official-catalog@sha256:…
> ```

To opt out of the official catalog entirely, run
`nem catalog disable official` (or `nem catalog remove official`).

## Contributing a package

Each package is a single manifest at `pkgs/<name>/pkg.yaml`. Validate your
change before opening a pull request:

```sh
nem catalog lint .
```

Every pull request is checked in CI on Linux (amd64, arm64) and macOS: all
manifests are linted, source-built packages you touch are built without
publishing, and prebuilt packages you touch are installed straight from the
PR's working tree.

Source-built packages (those with a `build:` section) support darwin/arm64,
linux/arm64, and linux/amd64; prebuilt packages may support all four
platforms. Build dependencies resolve from the *published* catalog, not the
PR — a new source-built package whose `build.deps` are also new must land in
dependency order, one PR each.

## Publishing

Merges to `main` that touch `pkgs/**` are published automatically by
[`.github/workflows/publish.yml`](.github/workflows/publish.yml):

1. Changed source-built packages are built and their archives pushed, one
   platform at a time.
2. The whole catalog index is staged to the `v2-staging` tag — staging fails
   if any package is missing a platform archive.
3. Changed packages are installed from staging on all three CI platforms.
4. `v2-staging` is retagged to `v2`, a digest-preserving promotion. A failed
   run never moves `:v2`.

A [weekly smoke workflow](.github/workflows/smoke.yml) additionally installs
every package at its latest version from the live `:v2` tag.

## Runbook

### Roll back a bad release

Revert the offending commit on `main` — the publish workflow rebuilds and
republishes the previous state. For an immediate rollback, retag the previous
index digest (listed under the package's versions on GHCR):

    oras tag ghcr.io/vi-dev/nem-official-catalog@sha256:<previous-digest> v2

### Rebuild a package's archives / force a republish

    gh workflow run publish.yml -f packages="<name> [<name>...]"

An empty `packages` input republishes the catalog index without rebuilding
any archives.

### nem regression escape hatch

CI runs nem's `unstable` channel. If a nem regression blocks publishing, pin
`NEM_VERSION` in
[`.github/actions/setup-nem/action.yml`](.github/actions/setup-nem/action.yml)
to the last good release tag until nem-cli fixes forward.

## License

[MIT](LICENSE)
