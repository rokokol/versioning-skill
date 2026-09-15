#!/usr/bin/env bash
# Reaches GitHub, so it is no part of the gate. Needs bash 3.2, POSIX tools and curl.
set -euo pipefail

usage() {
  cat <<'EOF'
fetch.sh — rebuild the real-changelog corpus from the list in sources beside this file.

  fetch.sh [-u] [-o DIR]

  -u       first move each commit in sources to the latest one that touched its changelog
  -o DIR   where the excerpts go (default: this script's own directory)

Each line of sources names an excerpt, a repository, a changelog in it and the commit it
is read at. The changelog is fetched at that commit and cut down to what the checker
reads: headings, the line above a setext underline, code fences and the hashed lines
inside them, and blank lines. Every other line becomes `- …`, a run of them one, so a
test carries the shape of a real changelog and not its prose. An excerpt ends after
MAX_LINES lines, and opens with a line naming where it came from

Environment: MAX_LINES caps each excerpt (default 600); GITHUB_TOKEN, when set, lifts the
rate limit on the GitHub API that -u asks.
Exit 0 done, 1 when a fetch or a lookup fails, 2 on a usage error.
EOF
}

fail() { # the thing asked about is wrong
  printf 'fetch.sh: %s\n' "$1" >&2
  exit 1
}

die() { # the request itself is wrong
  printf 'fetch.sh: %s\n' "$1" >&2
  exit 2
}

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

out="$HERE"
update=""
while (($#)); do
  case "$1" in
    -u)
      update=1
      shift
      ;;
    -o)
      # Not ${2:?}: that exits 1 with bash's own message, and a usage error is 2
      (($# >= 2)) || die "-o needs a directory"
      out="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "no such flag: $1" ;;
  esac
done
[[ -d "$out" ]] || die "$out is not a directory"

# The cut, in one pass with the previous line held back: whether it stays is known only
# once the next line says whether it underlines it
reduce() { # reduce MAX_LINES < CHANGELOG
  awk -v max="$1" '
    # Past the cap it stops printing but reads on: an early exit closes the pipe on the
    # printf feeding it, which dies of SIGPIPE, and pipefail makes that the script`s 141
    function put(s) {
      if (s == "- …" && last == s) return
      if (s == "" && last == "") return
      if (n >= max) return
      n++
      print s
      last = s
    }
    function release() { if (held) put("- …"); held = 0 }
    fence != "" {
      release()
      if (index($0, fence) == 1 && $0 ~ /^(```+|~~~+)[ \t]*$/) { put($0); fence = ""; next }
      put($0 ~ /^#/ ? $0 : "- …")
      next
    }
    /^```/ || /^~~~/ { release(); put($0); fence = substr($0, 1, 3); next }
    /^(=+|-+)[ \t]*$/ { if (held) put(prev); held = 0; put($0); next }
    /^#/ { release(); put($0); next }
    /^[ \t]*$/ { release(); put(""); next }
    { release(); prev = $0; held = 1 }
    END { release() }
  '
}

# Every commit in sources moved to the latest that touched its changelog, in place. The
# commit is the one field of its width on a line, so swapping it keeps the columns aligned;
# a commit that did not touch the changelog never becomes a pin, so an unchanged changelog
# leaves its line alone
move_pins() {
  local tmp row name repo path commit latest reply
  local -a auth=()
  [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  tmp=$(mktemp "${TMPDIR:-/tmp}/sources.XXXXXX")
  while IFS= read -r row; do
    read -r name repo path commit _ <<<"$row"
    case "$name" in '' | '#'*)
      printf '%s\n' "$row" >>"$tmp"
      continue
      ;;
    esac
    # Not "${auth[@]}": an empty array under set -u is an unbound variable before bash 4.4
    reply=$(curl -fsSL ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/$repo/commits?path=$path&per_page=1") || {
      rm -f "$tmp"
      fail "cannot ask GitHub which commit last touched $path in $repo"
    }
    # From a variable, not a pipe: sed quitting at the first match would kill curl with
    # SIGPIPE, and pipefail would make that the script's exit
    latest=$(sed -n '/"sha"/{s/.*"sha": *"\([0-9a-f]\{40\}\)".*/\1/p;q;}' <<<"$reply")
    [[ -n "$latest" ]] || {
      rm -f "$tmp"
      fail "GitHub names no commit that touched $path in $repo"
    }
    printf '%s\n' "${row/$commit/$latest}" >>"$tmp"
  done <"$HERE/sources"
  mv "$tmp" "$HERE/sources"
}

[[ -z "$update" ]] || move_pins

max="${MAX_LINES:-600}"
while read -r name repo path commit _; do
  case "$name" in '' | '#'*) continue ;; esac
  file="$out/$name.md"
  body=$(curl -fsSL "https://raw.githubusercontent.com/$repo/$commit/$path") ||
    fail "cannot fetch $path from $repo at $commit"
  {
    printf 'Excerpt of %s from %s at %s, cut by tests/real/fetch.sh\n\n' "$path" "$repo" "$commit"
    printf '%s\n' "$body" | reduce "$max"
  } >"$file"
  printf '%s: %s lines\n' "$name" "$(wc -l <"$file" | tr -d ' ')" >&2
done <"$HERE/sources"
