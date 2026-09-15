# Pitfalls

Traps in the checker and the tools around it that report a plausible success or point at the wrong cause, each with the way to reproduce it and the safe way through

## Autodetection trusts the first release heading

- **Scope:** every gate that runs `check-changelog.sh` without `-t`
- **Observation:** a changelog that moved to another template everywhere at once stays green. Without `-t`, the first release heading picks the template, and a file written throughout in release-please's shape is as uniform as one written in Keep a Changelog's
- **Reproduction:** `./check-changelog.sh -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-release-please.md` exits 0; with `-t '## [{version}] - {date}'` added it exits 1
- **Safe way:** a repository that keeps one shape on purpose pins it with `-t` in its gate line. Nothing retires this: autodetection is what lets the checker take a changelog it was never configured for

## GNU date refuses an ordinal suffix

- **Scope:** `calendar_oracle` in `check.sh`
- **Observation:** GNU coreutils 9.11 answers `date -u -d 'July 20th, 2026'` with `invalid date` and `date -u -d 'July 20, 2026'` with `2026-07-20`. Fed the words a changelog carries, the oracle would call every day with a suffix impossible, and the disagreement it reports would blame `long_day` in the checker
- **Mechanism:** GNU date's parser takes a month name and a bare day number; `st`, `nd`, `rd` and `th` are not in its grammar
- **Safe way:** the oracle asks about the ISO form of the day the words name. Revisit when `date -u -d 'July 20th, 2026'` prints a day
