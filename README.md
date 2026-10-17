# secret-scan

Dependency-free credential scanner with a fail-closed git pre-push hook.

Status: pre-release. Others may try it, but nothing is promised yet: patterns, options and output can change without notice.

[![gate](https://github.com/5omeOtherGuy/secret-scan/actions/workflows/gate.yml/badge.svg?branch=main)](https://github.com/5omeOtherGuy/secret-scan/actions/workflows/gate.yml)
[![licence: MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)

## What it does

`secret-scan` is a small Bash scanner for credential-like text and sensitive
file names. It can scan a working tree, text from standard input, or file names
from standard input. The included pre-push hook checks every outgoing commit
and refuses the push on a match or on any scanner error, so a broken scanner
never lets a push through.

### Limits

Detection uses a built-in set of patterns and is not comprehensive. It may miss
new credential formats and may flag ordinary text (in particular words starting
with `sk-` followed by 20 or more allowed characters). It does not contact
credential providers or determine whether a value is active.

The tree scan checks tracked file names and recursively scans readable
working-tree content, excluding `.git` and this scanner script. When the path
is not inside a Git working tree (or Git is not installed), it checks the names
of all files on disk instead and says so on standard error. A failing file
listing is a scanner error (status 2).

The pre-push hook scans every outgoing commit. For a new branch, that means
the commits missing from the pushed-to remote's default branch
(`<remote>/HEAD`), or the branch's whole history when that is not known
locally (`git remote set-head <remote> --auto` records it).

It is not a substitute for reviewing history or using a maintained, broader
secret-detection tool.

## Install

Runtime: Bash 4 or newer, GNU-compatible `grep`, and Git for the pre-push
hook and for scanning a Git working tree. No runtime packages need to be
installed on a typical Linux system.

```sh
git clone https://github.com/5omeOtherGuy/secret-scan
cd secret-scan
./secret-scan.sh
```

To enable the pre-push guard in another Git repository, copy
`secret-scan.sh`, `hooks/pre-push`, and `install-git-hooks.sh` into the top
level of that repository with the same paths (commit them so other clones
get the scanner too), then run the installer from that repository's copy:

```sh
cd /path/to/your-repo
mkdir -p hooks
cp /path/to/secret-scan/secret-scan.sh /path/to/secret-scan/install-git-hooks.sh .
cp /path/to/secret-scan/hooks/pre-push hooks/
./install-git-hooks.sh
```

The installer writes the hook into the hooks directory of the repository it
sits in (`git rev-parse --git-path hooks`, so linked worktrees and
`core.hooksPath` are honoured), whatever the current directory is. It refuses
when `hooks/pre-push` or `secret-scan.sh` is missing or the scanner is not
executable.

## Usage

```sh
./secret-scan.sh                     # scan this repository's working tree
./secret-scan.sh /path/to/project    # scan another tree
printf '%s\n' 'ordinary example text' | ./secret-scan.sh --stdin
git diff --name-only | ./secret-scan.sh --names
./secret-scan.sh --help
```

Exit status is 0 for clean, 1 for a detected match, and 2 for a scanner error.
Callers should treat any status other than 0 as a failure.

## Configuration

There are no environment variables or configuration files. The patterns are
built in (`PAT` for content, `FILES` for file names, in `secret-scan.sh`).

## Compatibility

Supported: Linux with Bash 4 or newer, GNU grep and Git. Other platforms
(macOS with BSD grep, for example) are untested.

Last verified on 2026-10-17 with Bash 5.2.15, GNU grep 3.8, Git 2.55.0 and
Python 3.11.6 on Debian 12, and on every push in CI on the GitHub `ubuntu-24.04`
runner.

## Development

Run the gate before every push. CI runs the same command:

```sh
scripts/gate
```

It syntax-checks every Bash script, runs `tests/test_secret_scan.sh` and scans
the repository. The tests also need Git, Python 3 and standard Unix utilities
(`mktemp`, `mkdir`, `cp`, `mv`, `chmod`, `rm`). On Debian or Ubuntu:

```sh
sudo apt-get install bash grep git python3 coreutils
```

To run the hook before every push, enable the repository's hooks once:
`git config core.hooksPath .githooks`. To focus on one area of the suite,
filter its output, for example
`bash tests/test_secret_scan.sh | grep -E '^FAIL|hook:'`. The tests build all
credential-shaped inputs at runtime, discard scanner output, and use a
temporary `HOME`, XDG directories and Git configuration.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute.

## Contributing, support and security

- Bugs and feature requests: [issues](https://github.com/5omeOtherGuy/secret-scan/issues).
- Contributions: [CONTRIBUTING.md](CONTRIBUTING.md).
- Vulnerabilities: report privately as described in [SECURITY.md](SECURITY.md).
- Changes: [CHANGELOG.md](CHANGELOG.md).

## Licence

[MIT](LICENSE)
