# Local development setup

This repository is hosted at [alex-1974/wikidata-d](https://github.com/alex-1974/wikidata-d). The original portable Git bundle was only used for initial research hand-off and is no longer the standard installation path.

## New checkout

On Ubuntu, install Git, a D compiler (DMD 2.111.0 or LDC 1.41.0 baseline), DUB, and the libcurl development package. Use the D toolchain manager or your existing D installation for the compiler and DUB.

```bash
sudo apt-get install -y git libcurl4-openssl-dev pkg-config

git clone https://github.com/alex-1974/wikidata-d.git
cd wikidata-d
git switch develop

git remote -v
git status --short --branch
dub test --compiler=dmd --force
```

To verify the other baseline compiler, use `dub test --compiler=ldc2 --force` after installing LDC.

The tests are offline. Do not execute `examples/lookup.d` until its live Wikidata User-Agent identifies a genuine application contact.

## Existing local working copy

If you already have a local clone with an `origin` remote, **do not reclone, remove `origin`, or overwrite local changes**:

```bash
cd /path/to/your/wikidata-d

git remote -v
git branch -avv
git status --short --branch
git fetch origin
```

The normal development branch is `develop`; `main` is reserved for release integration. Before switching branches or merging, inspect local modifications. Uncommitted example edits and locally maintained reference catalogues must not be lost or included inadvertently.

To check whether GitHub Actions passed for your current branch:

```bash
gh run list --repo alex-1974/wikidata-d --branch develop --limit 10
```

## Working with changes

Develop changes on a branch off `develop`; propose them back to `develop` through a pull request. The fast CI matrix runs DMD 2.111.0 and LDC 1.41.0. Promotion to `main` goes through the separate release-gate matrix.

Do not commit copyrighted external wordlists, personal research caches, or generated Wikidata responses unless their source, provenance, and distribution rights have been reviewed. The application keeps complete reference catalogues independent of the presence or absence of Wikidata matches.

For architecture and current scope, see the [README](README.md) and [core production boundary](README.md).
