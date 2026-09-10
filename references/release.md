# Cutting a release

A release is the moment the promise is made: from here on, someone can say "I have 1.2.0" and mean something. The ritual exists so that everything claiming to describe 1.2.0 agrees with everything else

## The order, and why it is that order

1. **Decide the number** from what changed, not from how much work it was — see [versioning.md](versioning.md)
2. **Move the changelog section and bump `VERSION` in the same commit.** The `Unreleased` bullets become `## [x.y.z]`, and `VERSION` changes in that same diff. This is what makes the CI check meaningful: it can only pass when both moved together, so neither can be forgotten. Two commits would leave a revision where they disagree, and that revision is the one somebody bisects to
3. **Verify on that commit**, not on the branch it came from: the full suite, the formatter, whatever gates a merge. Whatever is tagged is what people install
4. **Tag it `v<x.y.z>` on that commit, and push the tag.** A tag that exists only locally is not a release anyone can fetch
5. **Cut the release, and let its notes be that changelog section** — not a re-written summary. A hand-written summary beside a changelog section is a second source of truth, and within two releases they say different things

```sh
v=$(cat VERSION)
git tag "v$v"
git push origin "v$v"
gh release create "v$v" --verify-tag --notes-file <(awk -v h="## [$v]" 'index($0, h) == 1 { f = 1; next } f && /^## / { exit } f' CHANGELOG.md)
```

`--verify-tag` makes `gh` refuse when the tag is not on the remote, instead of creating one on whatever the default branch points at, which need not be the commit that was verified. The notes are everything under the release's own heading up to the next one: the heading itself is left out, since the release page already carries the title, and the heading is matched literally, so the dots in a version are dots rather than wildcards. The `sed` range this replaced dropped the last line of the section whenever that section was the last in the file — which is every first release

## What CI can and cannot enforce here

The `VERSION`↔`CHANGELOG` agreement is checkable on every commit, so it is a gate. The tag↔`VERSION` agreement is checkable too, only later: a workflow on `push: tags: ['v*']` compares `${GITHUB_REF_NAME#v}` with `cat VERSION` on the tagged commit — a shallow checkout is enough — and the job that publishes the release waits on it. What no check can do is stop a tag from being pushed onto the wrong commit, since it fires only once the tag exists. That part stays a ritual rule, written down in the repository's own agent instructions next to the release steps, not only in somebody's memory

## When a release was wrong

**Do not move a tag.** Somebody has already fetched it, and a moved tag makes their checkout silently differ from yours — the failure is invisible and lasts forever

Cut the next patch instead, and say what happened in its changelog entry. If the bad release must be withdrawn, yank it from wherever it is distributed, keep its changelog section, and add the new one saying it was withdrawn and why. Deleting the section would leave the people who installed it with no record of what they have — and they are exactly the people who need one

The same holds for a release that was never announced: it still exists as a tag, so it still gets an entry

## Between releases

Work accumulates under `## Unreleased`, which is the one place that heading belongs. A repository with no releases has no such state and uses dates instead — see [changelog.md](changelog.md)

Long-lived `Unreleased` sections are a signal worth reading: if it holds six months of bullets, the repository has been shipping to nobody, and either the releases or the promise should be reconsidered
