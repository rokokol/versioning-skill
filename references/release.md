# Cutting a release

A release is the moment the promise is made: from here on, someone can say "I have 1.2.0"
and mean something. The ritual exists so that everything claiming to describe 1.2.0 agrees
with everything else.

## The order, and why it is that order

1. **Decide the number** from what changed, not from how much work it was — see
   [versioning.md](versioning.md).
2. **Move the changelog section and bump `VERSION` in the same commit.** The `Unreleased`
   bullets become `## [x.y.z]`, and `VERSION` changes in that same diff. This is what makes
   the CI check meaningful: it can only pass when both moved together, so neither can be
   forgotten. Two commits would leave a revision where they disagree, and that revision is
   the one somebody bisects to.
3. **Verify on that commit**, not on the branch it came from: the full suite, the
   formatter, whatever gates a merge. Whatever is tagged is what people install.
4. **Tag it `v<x.y.z>`** on that commit.
5. **Cut the release, and let its notes be that changelog section** — not a re-written
   summary. A hand-written summary beside a changelog section is a second source of truth,
   and within two releases they say different things.

```sh
gh release create "v$(cat VERSION)" --notes-file <(sed -n "/^## \[$(cat VERSION)\]/,/^## /p" CHANGELOG.md | sed '$d')
```

## What CI can and cannot enforce here

The `VERSION`↔`CHANGELOG` agreement is checkable on every commit, so it is a gate. The
tag↔`VERSION` agreement is not: a check would need the full history and only fires after
the tag exists. It stays a ritual rule, which means it belongs written down in the
repository's own `CLAUDE.md` next to the release steps, not only in somebody's memory.

## When a release was wrong

**Do not move a tag.** Somebody has already fetched it, and a moved tag makes their
checkout silently differ from yours — the failure is invisible and lasts forever.

Cut the next patch instead, and say what happened in its changelog entry. If the bad
release must be withdrawn, yank it from wherever it is distributed, keep its changelog
section, and add the new one saying it was withdrawn and why. Deleting the section would
leave the people who installed it with no record of what they have — and they are exactly
the people who need one.

The same holds for a release that was never announced: it still exists as a tag, so it
still gets an entry.

## Between releases

Work accumulates under `## Unreleased`, which is the one place that heading belongs. A
repository with no releases has no such state and uses dates instead — see
[changelog.md](changelog.md).

Long-lived `Unreleased` sections are a signal worth reading: if it holds six months of
bullets, the repository has been shipping to nobody, and either the releases or the
promise should be reconsidered.
