# The version: one file, everyone reads it

## What has no version

Ask one question: **can someone install a particular version of this and report a bug
against it?**

If yes, it is a shipped artifact and everything below applies. If no — the repository is
only ever read at whatever revision happens to be checked out — it has no version to be
wrong about, and claiming one costs something real:

- a version badge nobody can verify, which quietly teaches readers that badges are decoration;
- an install line pinned to a tag that lags behind the branch people actually get;
- a "requires vX" note that was true once;
- and a number that must be bumped by hand forever, or silently rot.

Such a repository carries no `VERSION` file, no version badge and no tag-pinned install
line; its install instructions clone or pull the default branch, `git pull` is the whole
upgrade path, and its changelog is dated. Skills, prompt libraries, docs-only repositories
and dotfiles trees are all in this category.

The borderline case worth naming: a repository nobody installs *yet*. It has no version
until it ships one — adding a `VERSION` file in advance does not create the promise, it
only creates something to be wrong about.

## Where the version lives

One machine-readable place: a `VERSION` file at the repository root, holding `x.y.z` and a
trailing newline. Everything else derives from it rather than repeating it:

- the package metadata reads the file (in Nix, `version = lib.fileContents ../VERSION;`,
  which strips the newline);
- the installer or the tool prints it, and installs a copy so an installed instance knows
  what it is;
- git tags are `v<x.y.z>`;
- CI cross-checks the one place it cannot read from — the changelog.

Two hand-kept copies of a version number disagree within a month, and the disagreement
reaches a user: the tool reports one version while the package metadata claims another,
and a bug report becomes unactionable. The point of the single file is not tidiness, it is
that a mismatch becomes impossible rather than merely unlikely.

## The check that keeps them together

```yaml
- name: VERSION matches CHANGELOG
  run: |
    ver=$(cat VERSION)
    grep -qF "## [$ver]" CHANGELOG.md || {
      echo "VERSION says $ver but CHANGELOG.md has no ## [$ver] heading" >&2
      exit 1
    }
```

`check-changelog.sh` does the same thing and more, and takes any changelog:

```sh
check-changelog.sh              # finds VERSION beside CHANGELOG.md by itself
check-changelog.sh -n           # assert this repository has no version
check-changelog.sh -v path/to/VERSION path/to/CHANGELOG.md
```

The release ritual bumps `VERSION` in the same commit that moves the changelog section, so
this check can only pass when both moved together — see [release.md](release.md). Whether
it runs as a gate on pull requests is the [ci](https://github.com/rokokol/ci-skill) skill's
subject.

## Choosing the number

Semver, and the part people get wrong is that the promise is about **compatibility, not
effort**:

- **Major** — something that worked stops working: a removed or renamed interface, a
  changed default that alters behaviour, a dropped platform. A rename with an alias left
  behind is not major; a rename without one is, however small the diff.
- **Minor** — new capability, everything that worked still works.
- **Patch** — a fix, with no new capability.

A week of work that changes nothing observable is a patch. A one-character change to a
default that alters what a user's config does is major. If the change is invisible from
outside, it may not need a release at all — see [changelog.md](changelog.md) on what earns
an entry.
