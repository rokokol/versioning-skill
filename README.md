<div align="center">

# versioning skill

**What a repository says about itself over time ⌛**

[![Agent Skill](https://img.shields.io/badge/Agent_Skill-6E56CF?style=flat)](https://agentskills.io)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
![Nix](https://img.shields.io/badge/Nix-flake-7EBAE4?style=flat&logo=nixos&logoColor=white)
[![license](https://img.shields.io/badge/MIT-3DA639?style=flat)](LICENSE)
[![ci](https://github.com/rokokol/versioning-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/rokokol/versioning-skill/actions/workflows/ci.yml)

</div>

A version is a promise: someone installed exactly this one, and can report a bug against it. A changelog is the other half — it tells that person what changed between the thing they have and the thing being offered

Both go wrong the same way, by claiming more than the repository can back: a version badge on something with no releases, an `Unreleased` section that never closes, an entry describing a refactor nobody outside could observe, a heading nobody can match to anything they installed. This skill is the set of rules that keep the claim true, plus a checker that decides the half a script can decide

## Contents

- [Install](#install)
- [The first question](#the-first-question)
- [The rules](#the-rules)
- [The checker](#the-checker)
- [Tests](#tests)
- [Layout](#layout)

## Install

```sh
git clone https://github.com/rokokol/versioning-skill ~/Projects/versioning
ln -s ~/Projects/versioning ~/.claude/skills/versioning
```

Or straight into the skills directory your agent reads:

```sh
git clone https://github.com/rokokol/versioning-skill ~/.claude/skills/versioning
```

> [!NOTE]
> This repository is one of the kind it describes: it has no version, so `git pull` is the whole upgrade path and its own changelog is dated rather than numbered

## The first question

**Can someone install a particular version of this and report a bug against it?**

Everything else follows. If yes, it is a shipped artifact: a `VERSION` file, numbered changelog headings, tags, a release ritual. If no — a skill, a prompt library, a docs-only repo, a dotfiles tree — it has no version to be wrong about, so it carries no `VERSION` file, no version badge and no tag-pinned install line, and its changelog is dated

Getting this wrong is not cosmetic. A version nobody can install is a number that cannot be checked against anything, and it disagrees with reality the first time somebody tries

## The rules

They are in [SKILL.md](SKILL.md#the-rules), one line each with a link to the reference that argues it — one list, kept where the agent reads it, rather than a second copy here

## The checker

[`check-changelog.sh`](check-changelog.sh) takes **any** changelog, which is what makes it worth more than a review comment — drop it into a repository's own gate and the rules stop depending on somebody remembering them:

```sh
check-changelog.sh                    # finds VERSION beside CHANGELOG.md by itself
check-changelog.sh -n                 # assert this repository has no version
check-changelog.sh -v path/to/VERSION path/to/CHANGELOG.md
```

It decides the mechanical half of the rules, and `--help` says what it checks. What it cannot decide is whether an entry deserved to exist, which is the half that needs a person

## Tests

```sh
nix develop -c ./check.sh
```

Lints what the skill ships, runs the [ci](https://github.com/rokokol/ci-skill) skill's `check-skill.sh` — `SKILL.md` loads, every reference is reached from it by a chain of links, every link and heading anchor resolves, and each of those checks is proven able to fail on a planted defect — and runs the checker against this repository's own changelog first, the first repository it has to be right about

Then it proves the checker can fail, one fixture per rule, each of which must be rejected **with that rule's own message**: a checker whose findings all come from one over-broad branch reads as thorough while testing one thing. The correct fixtures, in both shapes, must come back clean, because a checker that cries wolf gets switched off

## Layout

```
SKILL.md              the rules an agent reads
check-changelog.sh    the checker, which takes any changelog
references/           versioning (the VERSION file), changelog (the culture), release (the ritual)
check.sh              the self-testing gate
check-skill.sh        the gate every skill repository shares, vendored from the ci skill
check-pins.sh         the pin guard for the workflows, vendored from the ci skill
tests/fixtures/       one known-bad changelog per rule, plus the good ones
```

What gates a pull request, how a workflow is pinned and how badges are earned belongs to the [ci](https://github.com/rokokol/ci-skill) skill; what may go in a commit *message* to [ai-commit-trailers](https://github.com/rokokol/ai-commit-trailers-skill)
