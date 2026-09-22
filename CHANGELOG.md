# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dated rather than numbered, and with no `Unreleased` section — this repository is read at whatever revision you have checked out, so whatever is on the default branch is what every reader already has. The rule is this skill's own, in [references/changelog.md](references/changelog.md)

## 2026-09-23

### Changed

- `check-changelog.sh` braces every expansion that carries a base prefix, `10#${x}` rather than `10#$x`, because tree-sitter's bash grammar rejects the bare form. The five sites are the version comparison and the date it builds from a written month, and both answer what they answered before on every value the suite feeds them, leading zeros included. The file now parses as a tree here and, once the cascade lands, in every repository that vendors it

## 2026-09-22

### Added

- `check-prose.sh`, vendored from [create-readme](https://github.com/rokokol/create-readme-skill), replaces the two prose rules this gate carried as its own awk. Five repositories held that copy in two spellings that had drifted apart, and the vendored file decides more than they did: the admonition shape, a typographic quotation mark and a heading that duplicates a file

## 2026-09-18

### Fixed

- `check-changelog.sh` read its own help through `usage | awk`, and that awk program exits once it has the template table. A producer whose reader stops early dies of SIGPIPE, and `pipefail` makes that the status of a pipeline that did its job, so the checker could fail with every template present. The help reaches awk through `<<<` now, which has no producer to kill

### Added

- the dev shell carries `jq`, ahead of the checker that will need it: the vendored `check-sh.sh` is moving off its awk lexer to reading the script it is given as a tree, out of `shfmt --to-json`, with jq flattening that tree into the rows its rules read. It lands before the cascade delivers that checker, so a new copy does not arrive to a missing tool and a red verify

## 2026-09-17

### Fixed

- `check-changelog.sh`'s header opened with a bare predicate, `Never edits its copy in place: a fix belongs in rokokol/versioning-skill`, whose subject had moved into the help. The header now names the cascade whole, and the help no longer repeats where the file comes from — that fact is the header's, since it changes nothing a caller types, expects or where they run the script
- the network line of `check-changelog.sh --help` and two lines of `tests/real/fetch.sh --help` ended their paragraph with a full stop, where the house rule leaves the last line bare

## 2026-09-16

### Changed

- `check.sh` no longer parses every script with its own `bash -n` loop: `check-sh.sh` reports a script it cannot parse, and the gate hands it `check-changelog.sh`, `tests/real/fetch.sh` and itself. The vendored copies are byte-equal to sources that parse them there, which `vendor-sync.sh` and the lock guarantee

## 2026-09-15

### Added

- `check-changelog.sh` takes the heading templates popular changelogs write, not Keep a Changelog's alone: release-please's compare link in the brackets, `1.2.3 (2026-09-05)`, a bare version with or without a `v`, a date in words, full or cut to `Jan`, that it reads and checks, `Version 1.2.3`, two-part calendar versions and the `[YANKED]` marker. The table is in its `--help`, which the checker reads back, so the two cannot disagree
- one template per changelog: the first release heading picks it, and a release in another is a finding. `-t TEMPLATE` pins one in a repository's gate
- a release may sit at any level, as conventional-changelog writes a major, a minor and a patch at `#`, `##` and `###`; a heading that follows no template is a finding at the highest level a release sits at and a section below it. Underlined headings are read, HTML tags such as vite's `<small>` are read past, and nothing inside a code fence counts as a heading
- a release is out of order only when it is newer than the one above it by version and, where its template carries a day, by day as well, so a changelog keeping several release lines passes whether it interleaves them by day, as angular does, or keeps them in blocks by version, as grafana, react and tokio do
- the gate runs the checker on excerpts of popular projects' changelogs in `tests/real`, pinned to commits in `tests/real/sources`, cut to their headings by `tests/real/fetch.sh` and moved to each changelog's latest commit on green by a weekly `corpus-sync` workflow, and holds its calendar to GNU date's on every day of 1900, 2000, 2024, 2026 and 2100 wherever GNU date exists
- `PITFALLS.md`, starting with a whole changelog moved to another template, which autodetection lets through

### Changed

- `check-changelog.sh` prints its help from a heredoc instead of reading its own header back, which under `bash <(…)` is the pipe bash reads the script from and printed nothing; the network and bash claims and the note on where the file comes from stay in the header comment and are no longer part of `--help`
- `check-changelog.sh` reads a release heading whole: it must be Keep a Changelog's `## [x.y.z] - YYYY-MM-DD`, with a hyphen-minus and a day that exists. Everything after the bracket used to go unread, so an em dash, a missing date and 2026-02-30 all passed. The example in `references/changelog.md` used the em dash itself and now uses the hyphen; a repository that vendors the checker and dates no release, or dates one with an em dash, goes red on the next cascade
- a release heading needs a date only when its template carries one, which most popular changelogs' templates do not; a heading that fits no template is reported as such, with `--help` named as the list
- a numbered changelog with no `VERSION` beside it counts as versioned, its version kept in a manifest the checker does not read, so its `Unreleased` section is no longer a finding; `-n` still says otherwise
- `check-skill.sh` is vendored from the [skill-authoring](https://github.com/rokokol/skill-authoring-skill) skill, where the rules it checks now live, and reports the rules a skill can break without breaking as warnings on stdout, the exit code unchanged: a `Layout` or install section in runtime, `used to`, a `path:line` citation, a link to a sibling skill, a concrete model id, and the rest its `--help` lists
- the description's triggers say `VERSION file` where `VERSION` stood beside `version`, the same word twice to a matcher that reads by meaning
- dated and numbered headings may meet once in either order: numbered above dated too, where a repository started shipping versions and kept its dated history below its first release. Only the two interleaved is a finding, and a `VERSION` file puts the releases on top while `-n` puts the dated entries there
- `check-changelog.sh` and `tests/real/fetch.sh` keep only what an editor needs in their headers now and move what a caller acts on into `--help`, the network line included for the former and the GitHub-reaching fact for the latter, both left in the header by an entry earlier today; `check.sh`, the gate, answers `--help` too, with its two modes, what each needs and its exit codes

### Fixed

- the rule on mixing dated and numbered headings fired on dated entries above the numbered history, the one mixture the skill calls meaningful, and let the reverse through; its fixture held the good order under the bad one's name

## 2026-09-12

### Added

- a `macos` workflow and its badge, vendored from the [bash-best-practices](https://github.com/rokokol/bash-best-practices-skill) skill's template: `check-changelog.sh` claims the bash 3.2 macOS ships, and the behaviour half of the gate, `check.sh behaviour`, now runs under the real `/bin/bash` 3.2 on a macOS runner, with constructs planted that only a 3.2 rejects. The claim used to rest on a proxy grep alone

### Changed

- where the version lives yields to a platform that reads it from its own manifest and fixes the tag's shape: an Obsidian plugin keeps it in `package.json`, derives `manifest.json` and `versions.json` through `npm version`, and tags the bare `X.Y.Z`

## 2026-09-11

### Changed

- `check-changelog.sh` is held to its own header by the [bash-best-practices](https://github.com/rokokol/bash-best-practices-skill) skill's `check-sh.sh`, vendored: every flag its parser accepts and every code it exits with must be in the help, and the grep for constructs newer than bash 3.2 now lives there, applied because the header says `Needs bash 3.2 and POSIX tools only` — the line the header was missing. The gate's own bash-4 pattern and `tests/fixtures/bash4-constructs.sh` are gone with it

## 2026-09-10

### Changed

- `references/release.md` no longer says the tag↔`VERSION` agreement cannot be checked. A workflow on a tag push can compare the two on a shallow checkout and gate the job that publishes; what stays a ritual is that the tag goes on the commit that was verified. The file is also unwrapped and its paragraphs end bare, like the rest of the family
- `SKILL.md`, `references/versioning.md` and `references/changelog.md` are unwrapped and end their paragraphs bare too, and the gate holds every doc to both rules — it used to check the readme for wrapping alone
- `references/changelog.md` lists the groups in Keep a Changelog's order; `references/versioning.md` says what 0.y.z and a prerelease promise, and shows the CI check as a `check-changelog.sh` step instead of an inline grep that was a weaker copy of it
- the readme links to the rules in `SKILL.md` instead of keeping a table of them, which had drifted — only the table said a pushed tag is never moved, and `SKILL.md` says it now
- the description says "git tag" and "git-тег": a bare "tag" also means a note's tag, which is the obsidian-cli skill's
- `SKILL.md` says how another repository takes `check-changelog.sh`: through the ci skill's vendoring cascade, never by hand, with a fix going here rather than into a copy. The checker's own header says the same, so every copy carries it
- `references/versioning.md` says that a skill which hands files to other repositories still has no version: its copies are pinned by the commit they were taken at
- `SKILL.md` and the readme no longer point at huix-standard for the Nix family's concretes: that skill links here for its version rules, and a general skill naming a particular one was a dependency in the wrong direction

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
