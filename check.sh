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
scripts=(check.sh check-changelog.sh)
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

echo "== the workflows are valid, and their tools come from the lock rather than a registry"
[[ -d .github/workflows ]] || fail ".github/workflows is missing — nothing gates this repository"
actionlint
if grep -rEn 'nix (run|shell) nixpkgs#|npx +[a-z@.-]|pip +install |go +install .*@latest' .github/workflows; then
  fail "an unpinned registry lookup in a workflow — pin the tool in the flake's dev shell and use nix develop"
fi

echo "== SKILL.md carries the frontmatter an agent loads it by"
head -1 SKILL.md | grep -qx -- '---' || fail "SKILL.md does not open with a frontmatter block"
front=$(sed -n '2,/^---$/p' SKILL.md)
for key in name description license; do
  grep -q "^$key:" <<<"$front" || fail "SKILL.md frontmatter has no $key"
done
grep -qx "name: $skill_name" <<<"$front" ||
  fail "SKILL.md does not call this skill '$skill_name', which is what the readme and the symlink call it"

echo "== no paragraph in the readme is hard-wrapped"
# GitHub soft-wraps, so a manual break means a one-word edit reflows every line after it.
# The rule's home is the create-readme skill, which cannot be assumed present in CI, so the
# one machine-decidable part of it is spelled here too.
hard_wrapped() { # hard_wrapped FILE -> the offending line numbers
  awk '
    /^```/ { fence = !fence; prev = 0; next }
    fence { next }
    /^[[:space:]]*$/ || /^[#|>< ]/ || /^[-*+]/ || /^!\[/ || /^\[/ { prev = 0; next }
    { if (prev) print NR; prev = 1 }
  ' "$1"
}
wrapped=$(hard_wrapped README.md)
[[ -z "$wrapped" ]] ||
  fail "README.md hard-wraps a paragraph at line(s): $(tr '\n' ' ' <<<"$wrapped")— one paragraph is one line"

echo "== every reference is reachable, and every link and anchor resolves"
docs=(SKILL.md README.md CHANGELOG.md)
refs=()
while IFS= read -r ref; do refs+=("$ref"); done < <(find references -type f -name '*.md' | sort)
((${#refs[@]} > 0)) || fail "no references were found — the extractor is broken"
for ref in "${refs[@]}"; do
  grep -qrF "$(basename "$ref")" SKILL.md references/ ||
    fail "$ref exists but nothing links to it — it will rot unread"
done
for doc in "${docs[@]}" "${refs[@]}"; do
  dir=$(dirname "$doc")
  while IFS= read -r link; do
    target="${link%%#*}"
    anchor="${link#*#}"
    [[ "$anchor" == "$link" ]] && anchor=""
    if [[ -n "$target" ]]; then
      [[ -e "$dir/$target" ]] || fail "$doc links to $target, which does not exist"
      path="$dir/$target"
    else
      path="$doc"
    fi
    [[ -n "$anchor" && -f "$path" ]] || continue
    if ! sed -n 's/^#\{1,6\} *//p' "$path" |
      tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-\n' |
      grep -qx -- "$anchor"; then
      fail "$doc links to #$anchor in $path, where no heading has that anchor"
    fi
  done < <(grep -o '](\([^)]*\))' "$doc" | sed 's/^](//; s/)$//' | grep -v '^[a-z]*://')
done

echo "== this repository's own changelog obeys the rules it hands out"
# The first repository the checker has to be right about is this one
./check-changelog.sh -n CHANGELOG.md

echo "== the checker accepts a changelog that is correct, in both shapes"
./check-changelog.sh -n tests/fixtures/good-dated.md ||
  fail "a correct dated changelog was rejected — the checker would cry wolf"
./check-changelog.sh -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-numbered.md ||
  fail "a correct numbered changelog was rejected — the checker would cry wolf"

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
rejects numbered-above-dated.md "a numbered heading above a dated one" -n
rejects nonsense-heading.md "is neither a version, a date, nor Unreleased" -n
rejects no-headings.md "no '## ' headings at all" -n
rejects dated-with-a-version.md "a dated heading in a repository that ships version" -v tests/fixtures/VERSION-1.2.0
rejects good-numbered.md "but no '## [9.9.9]' heading records what is in it" -v tests/fixtures/VERSION-9.9.9

echo "== the checker refuses rather than guessing when it is pointed at nothing"
status=0
./check-changelog.sh -n "$work/not-a-file.md" >/dev/null 2>&1 || status=$?
((status == 2)) || fail "the checker did not refuse a changelog it cannot read (got $status)"
status=0
./check-changelog.sh -n -v tests/fixtures/VERSION-1.2.0 tests/fixtures/good-dated.md >/dev/null 2>&1 || status=$?
((status == 2)) || fail "the checker accepted -n and -v together, which contradict each other (got $status)"

echo
echo "check: everything holds"
