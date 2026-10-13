# Workarounds

Arrangements that exist only because a defect outside this repository leaves no cleaner route, each with the check that decides when it can go. Traps that stay are in [PITFALLS.md](PITFALLS.md)

---

## Grafana's changelog is expected to fail on `[13.0.10] appears twice`

**Where:** the `grafana` line of `tests/real/sources`, which expects `fail [13.0.10] appears twice` instead of `pass`

**Symptom it prevents:** `check.sh`, and with it every `corpus-sync` run, goes red with `the real changelog grafana was rejected: tests/real/grafana.md:155: [13.0.10] appears twice — one heading per release, and the second one's entries belong under the first`

**Why it happens:** Grafana's automated changelog commit 11a7f3debe80dc41ebbc63dfda73e38a8ce05b0a wrote a second, empty `# 13.0.10 (2026-09-29)` heading into the 13.0.10 block of its `CHANGELOG.md`. The checker reports this correctly, so the checker stays as it is

**Why this works:** the corpus holds the checker to what real changelogs contain. A `fail` line keeps Grafana's changelog in the corpus and still requires the checker to name this exact defect

**Rejected alternative:** a pin on the commit before the defect keeps `pass`, but `corpus-sync` moves every pin to the latest commit each week and reverts the pin

**Removal check:**

```sh
curl -sL https://raw.githubusercontent.com/grafana/grafana/main/CHANGELOG.md | grep -E '^# [0-9]' | sort | uniq -d
```

Prints `# 13.0.10 (2026-09-29)` -> keep it. Prints nothing -> Grafana fixed the file: the next `corpus-sync` run goes red with `the real changelog grafana passed, where sources expects`, and the line goes back to `pass`

**Upstream:** not reported yet
