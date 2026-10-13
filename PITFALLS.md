# Pitfalls

Traps in the checker and the tools around it that report a plausible success or point at the wrong cause, each with the way to reproduce it and the safe way through

---

## Autodetection trusts the first release heading

**Where it bites:** every gate that runs `check-changelog.sh` without `-t`

**Reproduction:** `./check-changelog.sh -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-release-please.md` exits 0; with `-t '## [{version}] - {date}'` added it exits 1

**Misleading result:** a changelog that moved to another template everywhere at once stays green

**Mechanism:** without `-t`, the first release heading picks the template, and a file written throughout in release-please's shape is as uniform as one written in Keep a Changelog's. Autodetection is what lets the checker take a changelog it was never configured for, so the behaviour stays

**Safe route:** a repository that keeps one shape on purpose pins it with `-t` in its gate line

---

## GNU date refuses an ordinal suffix

**Where it bites:** `calendar_oracle` in `check.sh`

**Reproduction:** GNU coreutils 9.11 answers `date -u -d 'July 20th, 2026'` with `invalid date` and `date -u -d 'July 20, 2026'` with `2026-07-20`

**Misleading result:** fed the words a changelog carries, the oracle would call every day with a suffix impossible, and the disagreement it reports would blame `long_day` in the checker

**Mechanism:** GNU date's parser takes a month name and a bare day number; `st`, `nd`, `rd` and `th` are not in its grammar

**Safe route:** the oracle asks about the ISO form of the day the words name
