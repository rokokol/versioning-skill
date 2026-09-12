# The version: one file, everyone reads it

## What has no version

Ask one question: **can someone install a particular version of this and report a bug against it?**

If yes, it is a shipped artifact and everything below applies. If no — the repository is only ever read at whatever revision happens to be checked out — it has no version to be wrong about, and claiming one costs something real:

- a version badge nobody can verify, which quietly teaches readers that badges are decoration;
- an install line pinned to a tag that lags behind the branch people actually get;
- a "requires vX" note that was true once;
- and a number that must be bumped by hand forever, or silently rot

Such a repository carries no `VERSION` file, no version badge and no tag-pinned install line; its install instructions clone or pull the default branch, `git pull` is the whole upgrade path, and its changelog is dated. Skills, prompt libraries, docs-only repositories and dotfiles trees are all in this category

A skill that hands files to other repositories is no exception. What a consumer has is a copy, and the copy is pinned by the commit it was taken at, in that repository's vendor lock — which answers "which one do you have" more exactly than a number would, with nothing to bump and no tag to move. How the copies are kept current is the ci skill's [vendoring cascade](https://github.com/rokokol/ci-skill/blob/master/references/bump-cascade.md#vendored-files)

The borderline case worth naming: a repository nobody installs *yet*. It has no version until it ships one — adding a `VERSION` file in advance does not create the promise, it only creates something to be wrong about

## Where the version lives

One machine-readable place: a `VERSION` file at the repository root, holding the version — `x.y.z`, or `x.y.z-rc.1` for a prerelease — and a trailing newline. Everything else derives from it rather than repeating it:

- the package metadata reads the file (in Nix, `version = lib.fileContents ../VERSION;`, which strips the newline);
- the installer or the tool prints it, and installs a copy so an installed instance knows what it is;
- git tags are `v<version>`;
- CI cross-checks the one place it cannot read from — the changelog

Two hand-kept copies of a version number disagree within a month, and the disagreement reaches a user: the tool reports one version while the package metadata claims another, and a bug report becomes unactionable. The point of the single file is not tidiness, it is that a mismatch becomes impossible rather than merely unlikely

When the platform reads the version from its own manifest and fixes the tag's shape, the platform wins: an Obsidian plugin keeps the version in `package.json`, `npm version` derives `manifest.json` and `versions.json` from it through a `version` script, and its tags are the bare `X.Y.Z` Obsidian requires — the single source is still one file, only not `VERSION`

## The check that keeps them together

[`check-changelog.sh`](../check-changelog.sh), taken into the repository by the ci skill's [vendoring cascade](https://github.com/rokokol/ci-skill/blob/master/references/bump-cascade.md#vendored-files), is the check — one step, rather than an inline grep beside it that would be a second, weaker copy of the same rule:

```yaml
- name: VERSION matches CHANGELOG
  run: ./check-changelog.sh
```

It finds `VERSION` beside `CHANGELOG.md` by itself, requires a `## [x.y.z]` heading for it, and checks the heading shapes and their order along the way:

```sh
check-changelog.sh              # finds VERSION beside CHANGELOG.md by itself
check-changelog.sh -n           # assert this repository has no version
check-changelog.sh -v path/to/VERSION path/to/CHANGELOG.md
```

The release ritual bumps `VERSION` in the same commit that moves the changelog section, so this check can only pass when both moved together — see [release.md](release.md). Whether it runs as a gate on pull requests is the [ci](https://github.com/rokokol/ci-skill) skill's subject

## Choosing the number

Semver, and the part people get wrong is that the promise is about **compatibility, not effort**:

- **Major** — something that worked stops working: a removed or renamed interface, a changed default that alters behaviour, a dropped platform. A rename with an alias left behind is not major; a rename without one is, however small the diff
- **Minor** — new capability, everything that worked still works
- **Patch** — a fix, with no new capability
- **0.y.z** — initial development, where semver promises nothing: anything may change in any release. That is honest while the interface is still moving and a liability once people depend on it, so a project whose users would be hurt by a breaking change is overdue for 1.0.0 rather than entitled to a zero
- **Prerelease** — `x.y.z-rc.1` and its kind sort below `x.y.z`, and among themselves identifier by identifier, numbers as numbers. A prerelease is still something someone can install, so it gets its own heading and tag, and the final release goes above its candidates

A week of work that changes nothing observable is a patch. A one-character change to a default that alters what a user's config does is major. If the change is invisible from outside, it may not need a release at all — see [changelog.md](changelog.md) on what earns an entry
