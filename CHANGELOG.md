# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dated rather than numbered, and with no `Unreleased` section — this repository is read at whatever revision you have checked out, so whatever is on the default branch is what every reader already has. The rule is this skill's own, in [references/changelog.md](references/changelog.md)

## 2026-09-10

### Changed

- `references/release.md` no longer says the tag↔`VERSION` agreement cannot be checked. A workflow on a tag push can compare the two on a shallow checkout and gate the job that publishes; what stays a ritual is that the tag goes on the commit that was verified. The file is also unwrapped and its paragraphs end bare, like the rest of the family
- `SKILL.md`, `references/versioning.md` and `references/changelog.md` are unwrapped and end their paragraphs bare too, and the gate holds every doc to both rules — it used to check the readme for wrapping alone
- `references/changelog.md` lists the groups in Keep a Changelog's order; `references/versioning.md` says what 0.y.z and a prerelease promise, and shows the CI check as a `check-changelog.sh` step instead of an inline grep that was a weaker copy of it
- the readme links to the rules in `SKILL.md` instead of keeping a table of them, which had drifted — only the table said a pushed tag is never moved, and `SKILL.md` says it now
- the description says "git tag" and "git-тег": a bare "tag" also means a note's tag, which is the obsidian-cli skill's

### Fixed

- **a release above its own candidates was reported out of order.** `version_lt` dropped the prerelease suffix before comparing, so `2.0.0` and `2.0.0-rc.1` came out equal, and the most ordinary history a project that ships release candidates has was reddened — in every repository this checker is copied into. It orders by semver precedence now: a release above its own prereleases, identifiers dot by dot, numeric ones as numbers and below alphanumeric ones. One fixture carries a release over its candidates and `beta.11` over `beta.2`; another has to be rejected for candidates in the wrong order. The first draft of the fix asked the two sides in the wrong order, and that fixture caught it on its first run
- **`-v` with no file exited 1**, printing bash's own `${2:?…}` message where the header promises 2 for a usage error, so a caller read a typo as a finding. It refuses with exit 2 now, and the gate holds it to that
- **the release command cut the last line off a first release's notes.** Its `sed` range ran to the end of the file when the section was the last one, and the `sed '$d'` after it removed that section's own last line; it also kept the heading, and read the dots in a version as wildcards. `references/release.md` now takes the section with `awk` on the literal heading, pushes the tag, and creates the release with `--verify-tag`, so `gh` refuses instead of tagging whatever the default branch points at
- **`check-changelog.sh` stopped reading at the changelog.** A `-v` after the file was dropped without a word and the file checked as if it had no version, and a second file was never looked at. Options go anywhere now, and a second file is refused with exit 2
- a heading repeated was reported as out of order, which sends the reader to reorder what needs merging; it is reported as appearing twice
- a date heading of the right shape for a day that does not exist, such as `2026-02-30`, passed
- an `Unreleased` section below a release passed
- `check-changelog.sh --help` stopped before the exit codes it promises

## 2026-09-07

### Added

- `check-skill.sh`, the gate every skill repository shares, copied verbatim from the [ci](https://github.com/rokokol/ci-skill) skill: `SKILL.md` loads (frontmatter closed, name valid and agreeing with the symlink, description within what an agent reads), every reference is reached from `SKILL.md` by a chain of real links, every link and anchor resolves — and each of those is proven able to fail on a planted defect every time the gate runs. It replaces this repository's own frontmatter and link sections, which checked less and never proved themselves
- `check-pins.sh`, the pin guard for the workflows, copied verbatim from the [ci](https://github.com/rokokol/ci-skill) skill in place of the inline grep `check.sh` carried: it covers every unpinned shape the ci skill names rather than the four the grep knew, proves on every run that it catches each one and stays quiet on the pinned spellings, and refuses to read as green when there is nothing to scan
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
