---
name: versioning
description: "What it is — what a repository says about itself over time: whether it has a version at all, where that version lives, what its changelog looks like in either case, what deserves an entry, and the ritual that cuts a release. Use when writing or reviewing a CHANGELOG entry, adding or removing a VERSION file, deciding whether a repo should carry a version badge, cutting a release or a git tag, or setting either up in a new repo. Triggers: changelog, CHANGELOG.md, version, VERSION, semver, release, git tag, release tag, bump, Unreleased, чейнджлог, версия, релиз, git-тег, тег релиза, что писать в changelog, поднять версию."
license: MIT
---

# versioning

A version is a promise: someone installed exactly this one, and can report a bug against it. A changelog is the other half of that promise — it tells that person what changed between the thing they have and the thing they are being offered

Both go wrong in the same way, by claiming more than the repository can back. A version badge on something that has no releases; an `Unreleased` section that never closes; an entry describing a refactor nobody outside could observe; a heading nobody can match to anything they installed. The rules below exist to keep the claim true

[`check-changelog.sh`](check-changelog.sh) beside this file decides the machine-checkable half, and it takes **any** changelog, so the rules can be enforced in the repository they are handed to rather than remembered

## The first question: does this repository have a version?

Ask whether someone can install a particular one and report a bug against it

- **Yes** — a shipped artifact. It carries a `VERSION` file, numbered changelog headings, git tags, and a release ritual. See [references/versioning.md](references/versioning.md) and [references/release.md](references/release.md)
- **No** — a repository that is only ever read at whatever revision is checked out: a skill, a prompt library, a docs-only repo, a dotfiles tree. It has no version to be wrong about, so it carries no `VERSION` file, no version badge, and no install line pinned to a tag. Its changelog is **dated**

Getting this wrong is not cosmetic. A version nobody can install is a number that cannot be checked against anything, and it will disagree with reality the first time someone tries

## The rules

- **One place holds the version.** A `VERSION` file at the root; the package metadata reads it, the tools print it, CI cross-checks it against the changelog. Two hand-kept copies of a version number disagree within a month, and the disagreement surfaces to a user. See [references/versioning.md](references/versioning.md)
- **The changelog's shape follows from the first question.** Versioned: `## [x.y.z] - YYYY-MM-DD` headings, Keep a Changelog's own with a hyphen-minus, and `## Unreleased` on top for work waiting on the next release. Versionless: `## YYYY-MM-DD` headings and **no `Unreleased` section** — it holds work that has landed but not shipped, a state such a repository can never be in, so the section never closes and grows into an undated pile. See [references/changelog.md](references/changelog.md)
- **An entry earns its place by being observable from outside.** A user-visible change: behaviour, an interface, a default, a dependency, a removal. Not a refactor, not a rename nobody could see, not "improved the code". If you cannot say who would notice, there is nothing to write
- **The entry says what changed; the commit body says why.** A changelog is read by someone deciding whether to upgrade, not by someone reviewing the work. Keep the reasoning in the commit, where whoever is chasing that decision will look, and link the two by keeping the wording close
- **History is not edited.** A change that was later reverted keeps both entries: the one that added it and the one that removed it. That is the honest record, and the reader who tried the version in between is the reason it is honest
- **Newest first, one heading per release or day.** Dates descending, versions descending, none repeated. A repository that stopped shipping versions keeps its dated entries above its numbered history, which is the only mixture that means anything
- **The changelog has no section in the README.** It is its own file, linked, not summarised
- **Releasing is a ritual, and it is checkable.** The version bump and the changelog section move in one commit, the tag follows, the release notes are that section, and a pushed tag is never moved. See [references/release.md](references/release.md)
