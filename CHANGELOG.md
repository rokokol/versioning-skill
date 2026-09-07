# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dated rather than numbered, and with no `Unreleased` section — this repository is read at whatever revision you have checked out, so whatever is on the default branch is what every reader already has. The rule is this skill's own, in [references/changelog.md](references/changelog.md)

## 2026-09-07

### Added

- `check-skill.sh`, the gate every skill repository shares, copied verbatim from the [ci](https://github.com/rokokol/ci-skill) skill: `SKILL.md` loads (frontmatter closed, name valid and agreeing with the symlink, description within what an agent reads), every reference is reached from `SKILL.md` by a chain of real links, every link and anchor resolves — and each of those is proven able to fail on a planted defect every time the gate runs. It replaces this repository's own frontmatter and link sections, which checked less and never proved themselves
- fixtures for every branch of `check-changelog.sh` that had none: a `## [v1.2]` heading is rejected as not a version, a prerelease suffix in both `VERSION` and its heading is accepted alongside the bracketed `## [Unreleased]` spelling, the `VERSION` beside a changelog is found with no flag at all, and an unreadable or empty version file is refused with exit 2 rather than reported as a finding

## 2026-09-05

### Added

- the skill itself, gathering what was scattered across three other skills: whether a repository has a version at all, where that version lives, what its changelog looks like in either case, what earns an entry, and the ritual that cuts a release
- `check-changelog.sh`, which takes **any** changelog and decides the machine-checkable half: heading shapes, newest-first ordering in both kinds, an `Unreleased` section where there is no version to release, a dated heading in a repository that ships one, and whether the current `VERSION` has a section at all
- the rule that an entry earns its place by being observable from outside, and that the entry says *what* changed while the commit body says *why* — followed for a day across six repositories before it had anywhere to be written down
- the rule that history is not edited: a change later reverted keeps both entries, because the person who installed the version in between is the reason the record has to be honest

### Fixed

- `check-changelog.sh` used `mapfile` (bash 4.0+) and `sort -V` (a GNU extension), so it would have broken in the first repository that ran it on macOS — which is every repository, since the point of this checker is that it travels. Both are gone: a read loop, and a field-by-field version comparison that also gets `1.10.0` above `1.9.0` right, which sorting text does not
- a guard now greps every shipped script for constructs a bash 3.2 or a BSD userland lacks, and both its halves are proven — every construct in the fixture is caught, and the pattern cannot match its own source. The first version failed the second half and reddened the commit that added it
