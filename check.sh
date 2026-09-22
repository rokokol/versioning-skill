#!/usr/bin/env bash
# Needs bash 3.2, so behaviour mode runs unchanged under the bash a macOS runner has at
# /bin/bash. This skill hands check-changelog.sh to other
# repositories, and this is the gate that proves it before it goes out
set -euo pipefail

usage() {
  cat <<'EOF'
The gate for this repository: lints what the skill ships, holds it to its own rules, and
proves that each of its checks can actually go red — a check that has never failed is a
decoration

  check.sh [lint|behaviour|all]

Two halves, because they need different things

  lint        reads what the skill ships — the scripts, the workflows, the docs and the
              vendored copies — with the linters the flake's dev shell pins: actionlint,
              shellcheck, shfmt
  behaviour   runs check-changelog.sh against this changelog and the fixtures; needs only
              bash and POSIX tools
  all         both, and the default

  nix develop -c ./check.sh
  /bin/bash ./check.sh behaviour        # on a macOS runner, CHECK_BASH32=1

Nothing here touches the network, so it is safe on pull requests
Exit 0 clean, 1 with `check: <what>` on the first finding, 2 a usage error
EOF
}

case "${1:-}" in
  -h | --help | help)
    usage
    exit 0
    ;;
esac

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$HERE"

# One source of truth for what gets linted. A second copy of this list drifts, and a
# drifted list lies about what was checked.
scripts=(check.sh check-changelog.sh check-sh.sh check-skill.sh check-pins.sh check-prose.sh vendor-sync.sh tests/real/fetch.sh)
skill_name=versioning

fail() {
  printf 'check: %s\n' "$1" >&2
  exit 1
}

# Every script below runs under the bash running this gate, not under whatever bash its
# shebang finds: on a macOS runner the gate is started as /bin/bash to prove the 3.2 macOS
# ships, while `env bash` finds whichever bash is first on PATH — Homebrew's 5 on a Mac
# that has one
changelog() { "$BASH" "$HERE/check-changelog.sh" "$@"; }
checker() { "$BASH" "$HERE/check-sh.sh" "$@"; }
# The same copy under the same bash and tools proves itself once per run — the self-test is
# 5 s of a 5.1 s call — so every call after the first runs the checks alone, which is what
# CHECK_SH_NESTED=1 is documented for
checks() { CHECK_SH_NESTED=1 checker "$@"; }

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
  # No `bash -n` loop: check-sh.sh parses every script it is handed, and it is handed this
  # repository's own ones below. The vendored copies are byte-equal to sources that parse
  # them there, which vendor-sync.sh and the lock guarantee, so parsing them again here
  # would prove nothing about the same bytes
  shellcheck "${scripts[@]}"
  shfmt -d -i 2 -ci "${scripts[@]}"

  echo "== the Nix this repository holds is formatted"
  # A `formatter` output nothing runs is a declaration, not a rule. nixfmt rather than
  # `nix fmt`, because the second needs the flake and this is the binary the wrapper calls
  # find rather than a glob: a .nix file in a subdirectory is as much this repository's as
  # flake.nix, and a glob that misses one reads as a clean run.
  # find rather than git ls-files, because a gate that runs on a copy carrying no .git would
  # then see an empty list, which reads the same way
  local nixfiles=()
  while IFS= read -r f; do nixfiles+=("$f"); done < <(find . -name '*.nix' -type f -not -path '*/.git/*')
  ((${#nixfiles[@]})) || fail "no .nix file is tracked here, yet the flake declares a formatter"
  nixfmt --check "${nixfiles[@]}" ||
    fail "a .nix file here is not what nixfmt writes — run nix fmt"

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

  echo "== every document keeps the house rules a script can decide"
  # GitHub soft-wraps, so a manual break means a one-word edit reflows every line after it,
  # and a paragraph ends bare. Those rules and the rest of the house style live in the
  # create-readme skill (https://github.com/rokokol/create-readme-skill), and its checker
  # is vendored here rather than restated: the machine-decidable part used to be copied
  # into this gate as awk, and the copies in five repositories had drifted into two
  # spellings. Over every doc the skill ships, not the readme alone — SKILL.md and the
  # references are what an agent reads. It proves each of its own rules able to fail on
  # every run, so nothing here has to
  local docs=(README.md SKILL.md CHANGELOG.md references/*.md)
  ./check-prose.sh "${docs[@]}"

  echo "== SKILL.md loads, every reference is reachable, and every link and anchor resolves"
  # The one gate every skill repository shares, vendored from the skill-authoring skill
  # (https://github.com/rokokol/skill-authoring-skill). It proves each of its own checks
  # able to fail on every run, so nothing here has to
  ./check-skill.sh -n "$skill_name" .
}

# One fixture per rule, and the message must be the rule's own: a checker whose findings
# all come from one over-broad branch reads as thorough while testing one thing.
rejects() { # rejects FIXTURE EXPECTED-FRAGMENT [-v FILE | -n] [-t TEMPLATE]
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

# Every day of 1900 and 2100, which are not leap years, 2000, which is, and 2024 and 2026 on
# either side, with the 29th to the 31st of every month, once as YYYY-MM-DD and once in
# words. The checker must call exactly the days GNU date refuses not a date. GNU date is
# asked in UTC, so its answer cannot hang on the machine's zone, and about the ISO form only:
# it refuses an ordinal suffix outright, "July 20th, 2026" being its invalid date, and the
# words name the same day
calendar_oracle() {
  local iso="$work/oracle-iso.md" words="$work/oracle-words.md" out
  local y m d day suffix line=1 want="" got stray
  local -a names=(January February March April May June July August September October November December)
  local -a short=(Jan Feb Mar Apr May Jun Jul Aug Sept Oct Nov Dec) month
  printf '# Changelog\n' >"$iso"
  printf '# Changelog\n' >"$words"
  for y in 2100 2026 2024 2000 1900; do
    for ((m = 12; m >= 1; m--)); do
      for ((d = 31; d >= 1; d--)); do
        line=$((line + 1))
        day=$(printf '%04d-%02d-%02d' "$y" "$m" "$d")
        case $d in 1 | 21 | 31) suffix=st ;; 2 | 22) suffix=nd ;; 3 | 23) suffix=rd ;; *) suffix=th ;; esac
        printf '## %s\n' "$day" >>"$iso"
        # The edge centuries in cut month names, the rest in full ones
        month=${names[m - 1]}
        [[ $y == 2000 || $y == 2100 ]] && month=${short[m - 1]}
        # Versions count down with the lines, so no ordering finding joins the date ones
        printf '## 0.0.%d (%s %d%s, %d)\n' $((1862 - line)) "$month" "$d" "$suffix" "$y" >>"$words"
        TZ=UTC0 date -u -d "$day" +%F >/dev/null 2>&1 || want="$want $line"
      done
    done
  done
  for file in "$iso" "$words"; do
    out=$(changelog -n "$file" 2>&1) && fail "a calendar holding days that do not exist passed the checker"
    got=$(printf '%s\n' "$out" | awk -F: '/is not a date/ { printf " %s", $2 }')
    stray=$(printf '%s\n' "$out" | awk '!/is not a date/')
    [[ -z "$stray" ]] || fail "the calendar drew findings that are not about dates: $stray"
    [[ "$got" == "$want" ]] ||
      fail "the checker and GNU date disagree on which days exist in ${file##*/} — the checker:$got; GNU date:$want"
  done
}

check_behaviour() {
  echo "== the checker keeps its header's promises: its help, its flags, its codes, its bash 3.2 claim"
  # The bash-best-practices skill's checker, vendored: it reads check-changelog.sh's flag
  # parser and exit codes out of the source and holds the help to them, and greps the
  # script for constructs newer than the bash 3.2 its header claims — the grep that used to
  # live here, now labelled as the proxy it is, with the proof being this half under 3.2. It
  # plants its own defects on this first call, so nothing here has to prove it can fail
  checker check-changelog.sh
  # The gate itself, for its parse and its bash 3.2 claim: it has no dispatcher and no
  # flags, so the checker reads it by the proxy alone
  checks check.sh
  checks tests/real/fetch.sh

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
  # Dated entries above the numbered history, where a repository stopped shipping versions.
  # The mixture rule used to fire on exactly this and let its reverse through, and the
  # fixture meant to catch the reverse held the good order under the bad one's name
  changelog -n tests/fixtures/good-stopped-shipping.md ||
    fail "dated entries above the last numbered release were refused, where a repository stopped shipping versions"
  # And the other way round, where a repository started shipping them: its dated history stays
  # below the first release rather than being rewritten, VERSION beside it or not
  changelog -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-started-shipping.md ||
    fail "dated history below the first numbered release was refused, where a repository started shipping versions"
  changelog tests/fixtures/good-started-shipping.md ||
    fail "dated history below the first numbered release was refused with no VERSION beside it"

  echo "== it accepts the heading templates popular changelogs write, each one throughout a file"
  # One fixture per shape the help's table names, since the table is what the checker reads
  changelog -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-release-please.md ||
    fail "release-please's heading, a compare link in the brackets, was rejected"
  changelog -n tests/fixtures/good-level-one.md ||
    fail "level-one release headings with no title above them, angular's shape, were rejected"
  changelog -n tests/fixtures/good-level-one-titled.md ||
    fail "a title above level-one release headings was read as a release"
  changelog -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-bare.md ||
    fail "bare v-prefixed versions under a lowercase unreleased, bat's shape, were rejected"
  changelog -n tests/fixtures/good-date-in-words.md ||
    fail "a date in words, react's and tokio's shape, was rejected"
  changelog -n tests/fixtures/good-abbreviated-months.md ||
    fail "a month cut to three or four letters, which react and tokio write too, was rejected"
  changelog -v tests/fixtures/VERSION-2.0.0 tests/fixtures/good-conventional-levels.md ||
    fail "conventional-changelog's releases at three levels, with vite's <small>, were rejected"
  changelog -n tests/fixtures/good-multi-branch.md ||
    fail "release lines interleaved by day, angular's shape, were called out of order"
  changelog -n tests/fixtures/good-lines-by-version.md ||
    fail "release lines kept in blocks by version, grafana's shape, were called out of order"
  changelog -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-fenced.md ||
    fail "a heading-like line inside a code fence was read as a heading"
  changelog -n tests/fixtures/good-setext.md ||
    fail "setext headings, ripgrep's shape, were rejected or went unseen"
  # A numbered changelog with no VERSION beside it keeps its version somewhere else, a
  # package.json or a Cargo.toml, so its Unreleased section is where work waits
  changelog tests/fixtures/good-numbered.md ||
    fail "Unreleased in a numbered changelog with no VERSION file beside it was refused"
  changelog -n tests/fixtures/good-calver.md ||
    fail "a two-part calendar version, helix's shape, was rejected"
  changelog -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-yanked.md ||
    fail "Keep a Changelog's [YANKED] marker was rejected"
  changelog -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-unreleased-spellings.md ||
    fail "a lowercase unreleased, the way bat spells it, was rejected"
  # Pinned, the house shapes still pass: -t narrows the table to one line, it does not add one
  changelog -t '## [{version}] - {date}' -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-numbered.md ||
    fail "a numbered changelog was rejected under the very template it follows"
  changelog -t '## {date}' -n tests/fixtures/good-dated.md ||
    fail "a dated changelog was rejected under the very template it follows"

  echo "== and rejects each thing it claims to catch, naming that thing"
  rejects unreleased-without-version.md "an Unreleased section in a repository with no version" -n
  rejects dates-out-of-order.md "is not older than the" -n
  rejects versions-out-of-order.md "is newer than the [1.0.0] above it, by version and by day" -n
  rejects versions-double-digit.md "[1.10.0] is not older than the [1.9.0]" -n
  rejects candidates-out-of-order.md "[2.0.0-rc.2] is not older than the [2.0.0-rc.1]" -n
  rejects numbered-above-dated.md "a numbered heading above a dated one" -n
  # The two kinds meet once, where versions started or stopped; a second meeting is a mix
  rejects interleaved-kinds.md "the two kinds meet once"
  rejects nonsense-heading.md "matches none of the heading templates" -n
  rejects not-a-version-heading.md "matches none of the heading templates" -n
  rejects no-headings.md "no release headings at all" -n
  rejects dated-with-a-version.md "a dated heading in a repository that ships version" -v tests/fixtures/VERSION-1.2.0
  rejects good-numbered.md "VERSION says 9.9.9 but no release heading records what is in it" -v tests/fixtures/VERSION-9.9.9
  # No flag at all: the VERSION beside the changelog must be found by itself. Were it not,
  # this numbered changelog would pass, so the rejection is the proof that discovery ran
  rejects beside-its-version/CHANGELOG.md "VERSION says 9.9.9 but no release heading"
  # Each shape is fine alone; two in one file are two conventions, and the reader cannot tell
  # which one the next release will follow
  rejects mixed-templates.md "does not follow this changelog's heading template '[{version}] - {date}', set by line 3" -n
  # A release below the release level, or inside an HTML tag, is read, not taken for a section
  rejects conventional-levels-impossible-dates.md "2026-02-30 is not a date" -n
  rejects conventional-levels-impossible-dates.md "2026-02-31 is not a date" -n
  # An underlined heading is a heading: read, and held to the same rules
  rejects setext-impossible-date.md "2026-02-30 is not a date" -n
  # With no VERSION and no numbered heading, nothing says the repository has a version
  rejects unreleased-without-version.md "an Unreleased section in a repository with no version"
  rejects good-release-please.md "does not follow the heading template -t gives" -t '## [{version}] - {date}' -n
  # A date in words is read, not waved through: a template taking any text in the
  # parentheses would have passed both
  rejects long-date-impossible.md "February 30, 2026 is not a date" -n
  rejects long-date-misspelt.md "matches none of the heading templates" -n
  # A heading repeated is its own mistake, not an ordering one: "not older than the one above
  # it" sends the reader to reorder what needs merging
  rejects duplicate-dates.md "2026-09-05 appears twice" -n
  rejects duplicate-versions.md "[1.2.0] appears twice" -v tests/fixtures/VERSION-1.2.0
  # The heading's shape alone let a day February does not have through
  rejects impossible-date.md "2026-02-30 is not a date" -n
  # A release heading is read whole. Everything after the bracket used to go unread, so an
  # em dash, a missing day and a day that does not exist all passed
  rejects release-em-dash.md "matches none of the heading templates" -v tests/fixtures/VERSION-1.2.0
  rejects release-em-dash.md "does not follow the heading template -t gives" -t '## [{version}] - {date}' -v tests/fixtures/VERSION-1.2.0
  rejects release-without-date.md "matches none of the heading templates" -v tests/fixtures/VERSION-1.2.0
  rejects release-impossible-date.md "2026-02-30 is not a date" -v tests/fixtures/VERSION-1.2.0
  rejects unreleased-below-release.md "an Unreleased section below a release" -v tests/fixtures/VERSION-1.2.0
  # An option after the changelog is still an option. Parsing used to stop at the file, so a
  # trailing -v was dropped without a word and the file was checked as if it had no version
  local out
  out=$(changelog tests/fixtures/good-numbered.md -v tests/fixtures/VERSION-9.9.9 2>&1) &&
    fail "an option after the changelog was ignored — good-numbered.md passed a -v it cannot satisfy"
  [[ "$out" == *"VERSION says 9.9.9"* ]] || fail "an option after the changelog was ignored: $out"

  echo "== it reads the real changelogs in tests/real the way their sources file says it must"
  # Popular projects' changelogs at pinned commits, cut to what the checker reads. The
  # fixtures above are written for one rule each; these are what the rules meet out there
  local name expect
  while read -r name _ _ _ expect; do
    case "$name" in '' | '#'*) continue ;; esac
    if [[ "$expect" == pass ]]; then
      out=$(changelog "tests/real/$name.md" 2>&1) || fail "the real changelog $name was rejected: $out"
    else
      out=$(changelog "tests/real/$name.md" 2>&1) &&
        fail "the real changelog $name passed, where sources expects: $expect"
      [[ "$out" == *"${expect#fail }"* ]] ||
        fail "the real changelog $name was rejected, but not for what sources expects: $out"
    fi
  done <tests/real/sources

  echo "== its calendar agrees with GNU date's on every day of the years the leap rules split"
  # real_day and long_day are arithmetic of the checker's own, so they get an oracle where one
  # exists. Not on macOS, whose BSD date parses differently: there this block says so and the
  # Linux runner carries it
  if TZ=UTC0 date -u -d 2024-02-29 +%F >/dev/null 2>&1; then
    calendar_oracle
  else
    echo "   no GNU date here, so the calendar is not checked against one on this machine"
  fi

  echo "== the checker refuses rather than guessing when it is pointed at nothing"
  refuses "a changelog it cannot read" "cannot read" -n "$work/not-a-file.md"
  refuses "a version file it cannot read" "cannot read" -v "$work/not-a-VERSION" tests/fixtures/good-numbered.md
  refuses "an empty version file" "is empty" -v tests/fixtures/VERSION-empty tests/fixtures/good-numbered.md
  refuses "-n and -v together, which contradict each other" "contradict" -n -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-dated.md
  # `${2:?…}` printed bash's own message and exited 1 here, which reads as a finding
  refuses "a -v with no file after it" "-v needs a file" -v
  refuses "a -t with no template after it" "-t needs a template" -t
  # A template is refused whole rather than read as a literal heading nothing will match,
  # which would turn a typo in a gate into a red run blaming the changelog
  refuses "a template with neither a version nor a date" "needs {version} or a date" -t '## Release' tests/fixtures/good-dated.md
  refuses "a placeholder it does not know" "unknown placeholder {text}" -t '## {version} ({text})' tests/fixtures/good-dated.md
  refuses "a template with no heading level" "starts with # or ##" -t '[{version}] - {date}' tests/fixtures/good-dated.md
  # A second file used to be ignored, so a gate given two changelogs checked one of them
  refuses "two changelogs at once" "one changelog at a time" -n tests/fixtures/good-dated.md tests/fixtures/good-dated.md
  # The help is the header, whole: it used to stop before the exit codes it promises
  # <<< rather than a pipe: `grep -q` stops at its match and the help would die of SIGPIPE
  grep -q '^Exit: 0 clean' <<<"$(changelog --help)" || fail "--help stops before the exit codes"

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
