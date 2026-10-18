# AGENTS.md

## Profile
- Purpose: dependency-free credential scanner with a fail-closed git pre-push hook
- Stage: pre-release (repository standard 2026-10-18)
- Gate: `scripts/gate` (CI job `gate`)
- Landing: direct to main after a green gate; agents land: yes
- Release: none; agents release: no
- Outside issues and PRs: agents triage; outside PRs merge: owner approves
- Sensitive paths: `secret-scan.sh`, `hooks/`, `install-git-hooks.sh`, `scripts/gate`, `.githooks/`, `.agents/`, `.github/workflows/`, `.github/dependabot.yml`, `AGENTS.md`

Deliberate deviations from the standard: none.

## Map

- `secret-scan.sh`: the scanner. Modes: tree (default, optional path), `--stdin`, `--names`. Patterns live in `PAT` (content) and `FILES` (file names).
- `hooks/pre-push`: the product hook users install. It scans every outgoing commit's patch and file names, and fails closed.
- `install-git-hooks.sh`: installs `hooks/pre-push` into the hooks directory of the repository the script sits in.
- `tests/test_secret_scan.sh`: the only test suite, covering scanner modes, tree mode, the installer, and the hook driven through `git push` to local bare remotes.
- `scripts/gate`: the gate. It runs `bash -n` on every tracked Bash script, the tests and `./secret-scan.sh`.
- `.githooks/pre-push`: the development hook for this checkout. It runs the gate, then `hooks/pre-push`.
- `.agents/setup`: orb setup. It enables `.githooks`.
- `.github/workflows/gate.yml`: CI. It runs `scripts/gate` in job `gate`.

## Landing (pre-release)

1. Enable the hooks once per checkout: `git config core.hooksPath .githooks` (`.agents/setup` does it).
2. `git fetch origin && git rebase origin/main`, then `scripts/gate`.
3. `git push origin HEAD:main`. The pre-push hook runs the gate again. If the push is rejected, repeat from step 2.
4. Use a PR instead for public-interface changes (CLI modes, arguments, exit codes, output that callers parse, the hook's or installer's contract), CI or release configuration, changes to the sensitive paths in the profile, work spanning several sessions, and anything another person sends. Squash-merge it once the `gate` run on the head commit concluded `success`: `gh pr merge <n> --squash --delete-branch --match-head-commit <sha>`. CI, release, public-interface and sensitive-path changes need an independent review first, recorded on the PR against the reviewed head; a later push needs a new one.
5. Record user-visible changes under `## [Unreleased]` in `CHANGELOG.md`.
6. Commit subjects follow Conventional Commits. Commit as `5omeOtherGuy <268151429+5omeOtherGuy@users.noreply.github.com>`. Personal addresses and `Co-authored-by` trailers carrying them must not reach this public repository, including squash commits (pass `--author-email` and an explicit `--body`).

## Rules

- Fail closed. Every scanner or Git error is exit 2 in the scanner and a refusal in the hook, never a silent "clean". Keep the exit codes 0 (clean), 1 (hit) and 2 (error).
- Stay dependency-free. The tool needs only Bash, GNU grep and Git; Python 3 is allowed only in tests.
- Never commit a credential-shaped literal, not even in tests. Build every test vector from parts at runtime, and discard scanner and `git push` output in tests, since it echoes the matching line.
- Tests are hermetic. They use a temporary `HOME`, XDG directories and Git config, and local bare remotes only. There is no network, there are no credentials, and nothing live.
- Do not run `./install-git-hooks.sh` in this checkout. With `core.hooksPath=.githooks`, it would overwrite the tracked `.githooks/pre-push`. Test the installer through the test suite instead.
- A new credential format needs a positive test at a realistic length and a negative test for the nearest ordinary text.

## Focused checks

- One scanner mode by hand: `printf '%s\n' 'ordinary text' | ./secret-scan.sh --stdin` (exit 0) or `printf 'a.pem\n' | ./secret-scan.sh --names` (exit 1).
- One area of the suite: `bash tests/test_secret_scan.sh | grep -E '^FAIL|hook:'` (use `tree:`, `installer:`, `positive:` or `negative:` for other areas).
