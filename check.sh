#!/usr/bin/env bash
# The gate for this repository: lint what the skill ships, hold it to its own rules, and
# prove that each of its checks can actually go red. A check that has never failed is a
# decoration, and this skill hands its checker to other repositories.
#
# Nothing here touches the network, so it is safe on pull requests.
#
#   check.sh [lint|behaviour|all]
#
# Two halves, because they need different things. `lint` reads what the skill ships — the
# scripts, the workflows, the docs and the vendored copies — with the linters the flake's
# dev shell pins: actionlint, shellcheck, shfmt. `behaviour` runs check-changelog.sh
# against this changelog and the fixtures and needs only bash and POSIX tools, so it runs
# under the bash 3.2 macOS ships, which is what check-changelog.sh claims to run on. `all`,
# the default, is both.
#
#   nix develop -c ./check.sh
#   /bin/bash ./check.sh behaviour        # on a macOS runner, CHECK_BASH32=1
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$HERE"

# One source of truth for what gets linted. A second copy of this list drifts, and a
# drifted list lies about what was checked.
scripts=(check.sh check-changelog.sh check-sh.sh check-skill.sh check-pins.sh vendor-sync.sh)
skill_name=versioning

fail() {
  printf 'check: %s\n' "$1" >&2
  exit 1
}

# Every script below runs under the bash running this gate, not under whatever bash its
# shebang finds: on a macOS runner the gate is started as /bin/bash to prove the 3.2 macOS
# ships, while `env bash` would find Homebrew's 5
changelog() { "$BASH" "$HERE/check-changelog.sh" "$@"; }
checker() { "$BASH" "$HERE/check-sh.sh" "$@"; }

# With a template, so a crashed run's leftovers say whose they are
work=$(mktemp -d "${TMPDIR:-/tmp}/check.XXXXXX")
trap 'rm -rf "$work"' EXIT

mode="${1:-all}"
case "$mode" in
  lint | behaviour | all) ;;
  *)
    printf 'check: no such mode: %s — lint, behaviour or all\n' "$mode" >&2
    exit 2
    ;;
esac

tools=()
[[ "$mode" == behaviour ]] || tools+=(actionlint shellcheck shfmt)
missing=()
for tool in "${tools[@]+"${tools[@]}"}"; do
  command -v "$tool" >/dev/null || missing+=("$tool")
done
((${#missing[@]} == 0)) ||
  fail "missing: ${missing[*]} — they are pinned in the flake, so run this as: nix develop -c ./check.sh"

check_lint() {
  echo "== the scripts parse and lint"
  for s in "${scripts[@]}"; do bash -n "$s"; done
  shellcheck "${scripts[@]}"
  shfmt -d -i 2 -ci "${scripts[@]}"

  echo "== the workflows are valid, and their tools come from the lock rather than a registry"
  [[ -d .github/workflows ]] || fail ".github/workflows is missing — nothing gates this repository"
  actionlint
  # The checkers and macos.yml are vendored from the ci and bash-best-practices skills:
  # every copy must still be the blob .github/vendor.lock records, so one edited here
  # instead of at its source fails by name
  ./vendor-sync.sh check
  # The pin guard proves on every run that it catches each unpinned shape and stays quiet on
  # the pinned spellings, then scans the workflows
  ./check-pins.sh

  echo "== no paragraph in the docs is hard-wrapped or ends on a full stop"
  # GitHub soft-wraps, so a manual break means a one-word edit reflows every line after it,
  # and a paragraph ends bare. The rules' home is the create-readme skill, which cannot be
  # assumed present in CI, so their machine-decidable part is spelled here — over every doc
  # the skill ships, not the readme alone: SKILL.md and the references are what an agent reads
  local docs=(README.md SKILL.md CHANGELOG.md references/*.md) doc wrapped stopped
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
}

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

# One fixture per rule, and the message must be the rule's own: a checker whose findings
# all come from one over-broad branch reads as thorough while testing one thing.
rejects() { # rejects FIXTURE EXPECTED-FRAGMENT [-v FILE | -n]
  local fixture="tests/fixtures/$1" want="$2"
  shift 2
  local out
  out=$(changelog "$@" "$fixture" 2>&1) && fail "$fixture passed the checker"
  [[ "$out" == *"$want"* ]] ||
    fail "$fixture was rejected for the wrong reason: $out"
}

# Exit 2 and a usage message, rather than 1 and a finding: a missing file is not a bad
# changelog, and a gate that conflated the two would report a typo as a rule violation
refuses() { # refuses WHAT EXPECTED-FRAGMENT ARGS...
  local what="$1" want="$2" status=0 out
  shift 2
  out=$(changelog "$@" 2>&1) || status=$?
  ((status == 2)) || fail "the checker did not refuse $what (got $status)"
  [[ "$out" == *"$want"* ]] || fail "the checker refused $what for the wrong reason: $out"
}

check_behaviour() {
  echo "== the checker keeps its header's promises: its help, its flags, its codes, its bash 3.2 claim"
  # The bash-best-practices skill's checker, vendored: it reads check-changelog.sh's flag
  # parser and exit codes out of the source and holds the help to them, and greps the
  # script for constructs newer than the bash 3.2 its header claims — the grep that used to
  # live here, now labelled as the proxy it is, with the proof being this half under 3.2. It
  # plants its own defects on every run, so nothing here has to prove it can fail
  checker check-changelog.sh

  echo "== this repository's own changelog obeys the rules it hands out"
  # The first repository the checker has to be right about is this one
  changelog -n CHANGELOG.md

  echo "== the checker accepts a changelog that is correct, in both shapes"
  changelog -n tests/fixtures/good-dated.md ||
    fail "a correct dated changelog was rejected — the checker would cry wolf"
  changelog -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-numbered.md ||
    fail "a correct numbered changelog was rejected — the checker would cry wolf"
  # The case a string comparison gets backwards, which is why the ordering is done field by
  # field rather than by sorting text
  changelog -n tests/fixtures/good-double-digit.md ||
    fail "1.10.0 above 1.9.0 was called out of order — the version comparison is textual"
  # The bracketed `## [Unreleased]` spelling, and a prerelease suffix both in VERSION and in
  # the heading that has to match it
  changelog -v tests/fixtures/VERSION-2.0.0-rc.1 tests/fixtures/good-prerelease.md ||
    fail "a correct changelog with a prerelease and a bracketed Unreleased was rejected"
  # A release above its own candidates, and candidates above each other. The suffix used to
  # be dropped before comparing, so 2.0.0 and 2.0.0-rc.1 came out equal and this — the most
  # ordinary history a project that ships candidates has — was reported as out of order
  changelog -v tests/fixtures/VERSION-2.0.0 tests/fixtures/good-release-above-its-candidates.md ||
    fail "a release above its own candidates was called out of order — prerelease precedence is wrong"

  echo "== and rejects each thing it claims to catch, naming that thing"
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
  # A release heading is Keep a Changelog's `## [x.y.z] - YYYY-MM-DD`, whole. Everything
  # after the bracket used to go unread, so an em dash, a missing day and a day that does
  # not exist all passed
  rejects release-em-dash.md "is not a release heading — expected ## [x.y.z] - YYYY-MM-DD" -v tests/fixtures/VERSION-1.2.0
  rejects release-without-date.md "is not a release heading — expected ## [x.y.z] - YYYY-MM-DD" -v tests/fixtures/VERSION-1.2.0
  rejects release-impossible-date.md "2026-02-30 is not a date" -v tests/fixtures/VERSION-1.2.0
  rejects unreleased-below-release.md "an Unreleased section below a release" -v tests/fixtures/VERSION-1.2.0
  # An option after the changelog is still an option. Parsing used to stop at the file, so a
  # trailing -v was dropped without a word and the file was checked as if it had no version
  local out
  out=$(changelog tests/fixtures/good-numbered.md -v tests/fixtures/VERSION-9.9.9 2>&1) &&
    fail "an option after the changelog was ignored — good-numbered.md passed a -v it cannot satisfy"
  [[ "$out" == *"no '## [9.9.9]'"* ]] || fail "an option after the changelog was ignored: $out"

  echo "== the checker refuses rather than guessing when it is pointed at nothing"
  refuses "a changelog it cannot read" "cannot read" -n "$work/not-a-file.md"
  refuses "a version file it cannot read" "cannot read" -v "$work/not-a-VERSION" tests/fixtures/good-numbered.md
  refuses "an empty version file" "is empty" -v tests/fixtures/VERSION-empty tests/fixtures/good-numbered.md
  refuses "-n and -v together, which contradict each other" "contradict" -n -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-dated.md
  # `${2:?…}` printed bash's own message and exited 1 here, which reads as a finding
  refuses "a -v with no file after it" "-v needs a file" -v
  # A second file used to be ignored, so a gate given two changelogs checked one of them
  refuses "two changelogs at once" "one changelog at a time" -n tests/fixtures/good-dated.md tests/fixtures/good-dated.md
  # The help is the header, whole: it used to stop before the exit codes it promises
  changelog --help | grep -q '^Exit: 0 clean' || fail "--help stops before the exit codes"

  # check-changelog.sh claims bash 3.2, and a grep for newer syntax is a proxy; the
  # mechanism is this half under the real 3.2, with two constructs planted that only a 3.2
  # rejects. Under a newer bash they are no defect at all, so this block runs only where
  # CHECK_BASH32 says which bash this is, and first checks that claim
  if [[ -n "${CHECK_BASH32:-}" ]]; then
    echo "== this bash is the 3.2 the proof is about"
    ((BASH_VERSINFO[0] == 3)) ||
      fail "CHECK_BASH32 is set, but this is bash $BASH_VERSION — on macOS, run: /bin/bash ./check.sh behaviour"
    ! "$BASH" -c 'declare -A m' >/dev/null 2>&1 || fail "CHECK_BASH32 is set, but this bash accepts declare -A"
    # Both plants go right after the set line and exit 70 when refused: check-changelog.sh
    # runs without -e, since it counts its findings, so a refused builtin would otherwise
    # be a message it runs straight past
    local plant status
    for plant in 'declare -A check_changelog_probe' 'mapfile -t check_changelog_probe </dev/null'; do
      awk -v line="$plant || exit 70" '{ print } /^set -[a-z]*o pipefail$/ && !done { print line; done = 1 }' \
        check-changelog.sh >"$work/probe.sh"
      grep -qF "$plant || exit 70" "$work/probe.sh" || fail "the plant '$plant' did not land in check-changelog.sh"
      status=0
      "$BASH" "$work/probe.sh" -n CHANGELOG.md >/dev/null 2>&1 || status=$?
      ((status == 70)) || fail "a check-changelog.sh running '$plant' ran under this bash (got $status) — this is not a 3.2"
    done
  fi
}

case "$mode" in
  lint) check_lint ;;
  behaviour) check_behaviour ;;
  all)
    check_lint
    check_behaviour
    ;;
esac

echo
echo "check: everything holds"
