# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dated rather than numbered, and with no `Unreleased` section — this repository is read at whatever revision you have checked out, so whatever is on the default branch is what every reader already has. The rule is this skill's own, in [references/changelog.md](references/changelog.md)

## 2026-09-05

### Added

- the skill itself, gathering what was scattered across three other skills: whether a repository has a version at all, where that version lives, what its changelog looks like in either case, what earns an entry, and the ritual that cuts a release
- `check-changelog.sh`, which takes **any** changelog and decides the machine-checkable half: heading shapes, newest-first ordering in both kinds, an `Unreleased` section where there is no version to release, a dated heading in a repository that ships one, and whether the current `VERSION` has a section at all
- the rule that an entry earns its place by being observable from outside, and that the entry says *what* changed while the commit body says *why* — followed for a day across six repositories before it had anywhere to be written down
- the rule that history is not edited: a change later reverted keeps both entries, because the person who installed the version in between is the reason the record has to be honest
