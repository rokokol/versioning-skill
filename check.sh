#!/usr/bin/env bash
# The gate for this repository: lint what the skill ships, hold it to its own rules, and
# prove that each of its checks can actually go red. A check that has never failed is a
# decoration, and this skill hands its checker to other repositories.
#
# Nothing here touches the network, so it is safe on pull requests.
# Needs: actionlint, shellcheck, shfmt — from the flake's dev shell, never from PATH's luck.
#
#   nix develop -c ./check.sh
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$HERE"

# One source of truth for what gets linted. A second copy of this list drifts, and a
# drifted list lies about what was checked.
scripts=(check.sh check-changelog.sh check-skill.sh check-pins.sh)
skill_name=versioning

fail() {
  echo "check: $1" >&2
  exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

missing=()
for tool in actionlint shellcheck shfmt; do
  command -v "$tool" >/dev/null || missing+=("$tool")
done
((${#missing[@]} == 0)) ||
  fail "missing: ${missing[*]} — they are pinned in the flake, so run this as: nix develop -c ./check.sh"

echo "== the scripts parse and lint"
for s in "${scripts[@]}"; do bash -n "$s"; done
shellcheck "${scripts[@]}"
shfmt -d -i 2 -ci "${scripts[@]}"

echo "== nothing here needs a bash newer than the one macOS ships"
# macOS ships bash 3.2, and this checker is meant to be dropped into other repositories'
# gates — including theirs. Two of these were found the expensive way, by a CI run on a
# machine none of this was written on: `[[ -v VAR ]]` is 4.2+, `mapfile` is 4.0+.
# `sort -V` is a separate trap: not a bash version but a GNU one, absent from BSD sort.
# Every literal below is split by a bracket expression so the pattern cannot match its own
# source line — the same trick the ci skill's secret gate uses, and for the same reason: a
# guard that reddens the commit introducing it gets deleted rather than fixed.
bash4_pattern='\[\[[^]]*[-]v [A-Za-z_]|mapfil[e] |readarra[y] |declar[e] -A|loca[l] -A|\$\{[A-Za-z_]+,[,]\}|\$\{[A-Za-z_]+\^[\^]\}|sor[t] -[A-Za-z]*V'
bash4=$(grep -nE "$bash4_pattern" "${scripts[@]}" | grep -vE ':[[:space:]]*#' || :)
[[ -z "$bash4" ]] || fail "a construct newer than bash 3.2 (or GNU-only) in a script meant to travel:"$'\n'"$bash4"

echo "== the workflows are valid, and their tools come from the lock rather than a registry"
[[ -d .github/workflows ]] || fail ".github/workflows is missing — nothing gates this repository"
actionlint
# The pin guard, copied verbatim from the ci skill: it proves on every run that it catches
# each unpinned shape and stays quiet on the pinned spellings, then scans the workflows
./check-pins.sh

echo "== no paragraph in the docs is hard-wrapped or ends on a full stop"
# GitHub soft-wraps, so a manual break means a one-word edit reflows every line after it,
# and a paragraph ends bare. The rules' home is the create-readme skill, which cannot be
# assumed present in CI, so their machine-decidable part is spelled here — over every doc
# the skill ships, not the readme alone: SKILL.md and the references are what an agent reads
docs=(README.md SKILL.md CHANGELOG.md references/*.md)
hard_wrapped() { # hard_wrapped FILE -> the offending line numbers
  awk '
    # the frontmatter is YAML, whose keys sit one per line
    NR == 1 && /^---$/ { front = 1; next }
    front { if (/^---$/) front = 0; next }
    /^```/ { fence = !fence; prev = 0; item = 0; next }
    fence { next }
    # a list item continued on an indented line is a wrapped list item
    item && /^  +[^ ]/ && !/^  +([-*+]|[0-9]+\.) / { print NR; next }
    /^[-*+] / || /^[0-9]+\. / { prev = 0; item = 1; next }
    /^[[:space:]]*$/ || /^[#|>< ]/ || /^!\[/ || /^\[/ { prev = 0; item = 0; next }
    { if (prev) print NR; prev = 1; item = 0 }
  ' "$1"
}
full_stopped() { # full_stopped FILE -> the lines of prose that end on a full stop
  awk '
    NR == 1 && /^---$/ { front = 1; next }
    front { if (/^---$/) front = 0; next }
    /^```/ { fence = !fence; next }
    fence || /^    / || /^[|]/ { next }
    # seen through the markup that can close after it: `.**` and `.)` end on a stop too
    { s = $0; sub(/[*_)`"]+$/, "", s); if (s ~ /[^.]\.$/) print NR }
  ' "$1"
}
for doc in "${docs[@]}"; do
  wrapped=$(hard_wrapped "$doc")
  [[ -z "$wrapped" ]] ||
    fail "$doc hard-wraps a paragraph at line(s): $(tr '\n' ' ' <<<"$wrapped")— one paragraph is one line"
  stopped=$(full_stopped "$doc")
  [[ -z "$stopped" ]] ||
    fail "$doc ends prose on a full stop at line(s): $(tr '\n' ' ' <<<"$stopped")— the last sentence ends bare"
done
# Both able to fail, on the shapes they claim: a wrapped paragraph and a wrapped list item,
# a full stop bare and one behind closing markup
printf 'one line of a paragraph\nand the next line of it\n\n- a list item\n  wrapped onto a second line\n' >"$work/wrapped.md"
[[ "$(hard_wrapped "$work/wrapped.md" | wc -l)" -eq 2 ]] ||
  fail "the hard-wrap check missed a wrapped paragraph or a wrapped list item"
printf 'A sentence.\n\n**A bold one.**\n\n(A parenthesis.)\n' >"$work/stopped.md"
[[ "$(full_stopped "$work/stopped.md" | wc -l)" -eq 3 ]] ||
  fail "the full-stop check missed a full stop, bare or behind markup"

echo "== SKILL.md loads, every reference is reachable, and every link and anchor resolves"
# The one gate every skill repository shares, copied verbatim from the ci skill. It proves
# each of its own checks able to fail on every run, so nothing here has to
./check-skill.sh -n "$skill_name" .

echo "== this repository's own changelog obeys the rules it hands out"
# The first repository the checker has to be right about is this one
./check-changelog.sh -n CHANGELOG.md

echo "== the checker accepts a changelog that is correct, in both shapes"
./check-changelog.sh -n tests/fixtures/good-dated.md ||
  fail "a correct dated changelog was rejected — the checker would cry wolf"
./check-changelog.sh -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-numbered.md ||
  fail "a correct numbered changelog was rejected — the checker would cry wolf"
# The case a string comparison gets backwards, which is why the ordering is done field by
# field rather than by sorting text
./check-changelog.sh -n tests/fixtures/good-double-digit.md ||
  fail "1.10.0 above 1.9.0 was called out of order — the version comparison is textual"
# The bracketed `## [Unreleased]` spelling, and a prerelease suffix both in VERSION and in
# the heading that has to match it
./check-changelog.sh -v tests/fixtures/VERSION-2.0.0-rc.1 tests/fixtures/good-prerelease.md ||
  fail "a correct changelog with a prerelease and a bracketed Unreleased was rejected"
# A release above its own candidates, and candidates above each other. The suffix used to
# be dropped before comparing, so 2.0.0 and 2.0.0-rc.1 came out equal and this — the most
# ordinary history a project that ships candidates has — was reported as out of order
./check-changelog.sh -v tests/fixtures/VERSION-2.0.0 tests/fixtures/good-release-above-its-candidates.md ||
  fail "a release above its own candidates was called out of order — prerelease precedence is wrong"

echo "== and rejects each thing it claims to catch, naming that thing"
# One fixture per rule, and the message must be the rule's own: a checker whose findings
# all come from one over-broad branch reads as thorough while testing one thing.
rejects() { # rejects FIXTURE EXPECTED-FRAGMENT [-v FILE | -n]
  local fixture="tests/fixtures/$1" want="$2"
  shift 2
  local out
  out=$(./check-changelog.sh "$@" "$fixture" 2>&1) && fail "$fixture passed the checker"
  [[ "$out" == *"$want"* ]] ||
    fail "$fixture was rejected for the wrong reason: $out"
}
rejects unreleased-without-version.md "an Unreleased section in a repository with no version" -n
rejects dates-out-of-order.md "is not older than the" -n
rejects versions-out-of-order.md "is not older than the" -n
rejects versions-double-digit.md "[1.10.0] is not older than the [1.9.0]" -n
rejects candidates-out-of-order.md "[2.0.0-rc.2] is not older than the [2.0.0-rc.1]" -n
rejects numbered-above-dated.md "a numbered heading above a dated one" -n
rejects nonsense-heading.md "is neither a version, a date, nor Unreleased" -n
rejects not-a-version-heading.md "is not a version heading — expected ## [x.y.z]" -n
rejects no-headings.md "no '## ' headings at all" -n
rejects dated-with-a-version.md "a dated heading in a repository that ships version" -v tests/fixtures/VERSION-1.2.0
rejects good-numbered.md "but no '## [9.9.9]' heading records what is in it" -v tests/fixtures/VERSION-9.9.9
# No flag at all: the VERSION beside the changelog must be found by itself. Were it not,
# this numbered changelog would pass, so the rejection is the proof that discovery ran
rejects beside-its-version/CHANGELOG.md "VERSION says 9.9.9 but no '## [9.9.9]'"
# A heading repeated is its own mistake, not an ordering one: "not older than the one above
# it" sends the reader to reorder what needs merging
rejects duplicate-dates.md "2026-09-05 appears twice" -n
rejects duplicate-versions.md "[1.2.0] appears twice" -v tests/fixtures/VERSION-1.2.0
# The heading's shape alone let a day February does not have through
rejects impossible-date.md "2026-02-30 is not a date" -n
rejects unreleased-below-release.md "an Unreleased section below a release" -v tests/fixtures/VERSION-1.2.0
# An option after the changelog is still an option. Parsing used to stop at the file, so a
# trailing -v was dropped without a word and the file was checked as if it had no version
out=$(./check-changelog.sh tests/fixtures/good-numbered.md -v tests/fixtures/VERSION-9.9.9 2>&1) &&
  fail "an option after the changelog was ignored — good-numbered.md passed a -v it cannot satisfy"
[[ "$out" == *"no '## [9.9.9]'"* ]] || fail "an option after the changelog was ignored: $out"

echo "== the bash-3.2 guard catches each construct, and never its own source"
# Both halves. A guard that matched its own file would redden the commit that introduces
# it, and would then be deleted rather than fixed; a guard that matches nothing is worse,
# because it looks like protection.
# The constructs live in a fixture rather than inline here, because spelling them in this
# file would make the guard match its own proof — which is how the first version of this
# reddened the repository on the commit that added it
planted_count=0
while IFS= read -r planted; do
  [[ -z "$planted" || "$planted" == \#* ]] && continue
  planted_count=$((planted_count + 1))
  printf '%s\n' "$planted" >"$work/planted.sh"
  grep -qE "$bash4_pattern" "$work/planted.sh" ||
    fail "the bash-3.2 guard does not catch: $planted"
done <tests/fixtures/bash4-constructs.sh
((planted_count >= 8)) || fail "only $planted_count constructs were read from the fixture — the extractor is broken"

echo "== the checker refuses rather than guessing when it is pointed at nothing"
# Exit 2 and a usage message, rather than 1 and a finding: a missing file is not a bad
# changelog, and a gate that conflated the two would report a typo as a rule violation
refuses() { # refuses WHAT EXPECTED-FRAGMENT ARGS...
  local what="$1" want="$2" status=0 out
  shift 2
  out=$(./check-changelog.sh "$@" 2>&1) || status=$?
  ((status == 2)) || fail "the checker did not refuse $what (got $status)"
  [[ "$out" == *"$want"* ]] || fail "the checker refused $what for the wrong reason: $out"
}
refuses "a changelog it cannot read" "cannot read" -n "$work/not-a-file.md"
refuses "a version file it cannot read" "cannot read" -v "$work/not-a-VERSION" tests/fixtures/good-numbered.md
refuses "an empty version file" "is empty" -v tests/fixtures/VERSION-empty tests/fixtures/good-numbered.md
refuses "-n and -v together, which contradict each other" "contradict" -n -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-dated.md
# `${2:?…}` printed bash's own message and exited 1 here, which reads as a finding
refuses "a -v with no file after it" "-v needs a file" -v
# A second file used to be ignored, so a gate given two changelogs checked one of them
refuses "two changelogs at once" "one changelog at a time" -n tests/fixtures/good-dated.md tests/fixtures/good-dated.md
# The help is the header, whole: it used to stop before the exit codes it promises
./check-changelog.sh --help | grep -q '^Exit: 0 clean' || fail "--help stops before the exit codes"

echo
echo "check: everything holds"
