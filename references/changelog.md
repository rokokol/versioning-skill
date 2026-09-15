# The changelog

A changelog is written for one person: someone deciding whether to move from the thing they have to the thing being offered. Everything below follows from that reader existing — and from noticing when they do not

## The two shapes

**A shipped artifact** — someone installed a particular version and can report a bug against it — is numbered:

```markdown
## Unreleased

### Added

- what is waiting for the next release

## [1.2.0] - 2026-09-05

### Changed

- what went out in 1.2.0
```

**A repository read at whatever revision is checked out** — a skill, a prompt library, a docs-only repo — is dated:

```markdown
## 2026-09-05

### Added

- what landed that day
```

The dated shape has **no `Unreleased` section**, and the reason is not stylistic. `Unreleased` holds work that has landed but has not shipped. Such a repository cannot be in that state: whatever is on the default branch is what every reader already has, from the moment it is pushed. Left in place, the section never closes — it accumulates months of undated bullets and answers "when did this change?" with nothing. The day is the unit of release, so the day is the heading

In the numbered shape `Unreleased` sits on top, above every release. Below one it is a pile of unshipped work filed under something that already shipped, where the reader deciding whether to upgrade will not look

Where a repository stops shipping versions, its dated entries sit **above** its numbered history. That is the only mixture that means anything, and it reads correctly: newest first, and the point where the promise changed is visible

## What earns an entry

The test is whether anyone outside the repository could notice. A user-visible change: behaviour, an interface, a default value, a dependency, a removal, a new requirement, a fixed bug someone could have hit

Not: a refactor, an internal rename, a reformat, a test added for existing behaviour, a comment. Those are real work and belong in the git history, which is where somebody looking for them will look. A changelog padded with them stops being scannable, and the entry that mattered gets missed

The reliable way to write one: name what someone would have to change, or what stops happening to them

## The entry says what; the commit says why

The two documents have different readers. The changelog reader is deciding whether to upgrade and has thirty seconds. The commit-body reader is chasing a decision and wants the argument that produced it

So the entry states the change and its consequence, and the reasoning — what was tried, what broke, why this shape and not the other — stays in the commit body. Keep the wording close enough that `git log --grep` finds one from the other

A worked pair:

> **Entry**: `flaky` ignored the `logdir` its repository names in `tests/t.conf`, writing where `run` would not. It reads the same policy now
>
> **Commit body**: the paragraph explaining that the two subcommands had drifted because `flaky` predated the config file, and why the fix is to call the same loader rather than to duplicate the default

## History is not edited

An entry for something later reverted stays, and gets a second entry for the reversal. Both are true, and the person who installed the version in between is the reason they have to be

This feels wrong the first time — the repository ends up advertising a feature it no longer has. It is still right: a changelog is a record of what happened, not a description of the current state. The current state is the code, and the README describes it

The same applies to a mistake in an old entry: correct it in a new one that says what was wrong, rather than editing the old text. Somebody has already read the old text

## Ordering, and the rest of the shape

- **Newest first**, always. Dates descending, versions descending
- **One heading per release or day.** A second heading for the same one splits its entries in two; the second one's bullets belong under the first
- **One kind of heading** — versions or dates, not both, except for the transition above
- **Group by kind** in Keep a Changelog's order — `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security` — and drop the groups that are empty rather than writing "none"
- **No section in the README.** The changelog is its own file, linked, never summarised — a summary drifts, and then the two disagree in public

## Reconstructing one after the fact

A repository that has run for a while without a changelog can still get an honest one: read the history, group by the day the work landed, and say so in the header — that the entries were written after the fact, so they state what changed and leave the reasoning to the commit bodies. Do not date entries by when you wrote them

`check-changelog.sh` decides the mechanical half of all of this — the heading shapes, real dates, the ordering, a heading repeated, `Unreleased` where it does not belong or below a release, and whether the current `VERSION` has a section. What it cannot decide is whether an entry deserved to exist, which is the half that needs you
