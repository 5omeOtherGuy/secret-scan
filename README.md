# secret-scan

`secret-scan` is a small Bash scanner for credential-like text and sensitive
file names. It can scan a working tree, text from standard input, or file names
from standard input. The included pre-push hook checks every outgoing commit.

## Requirements

Runtime: Bash 4 or newer, GNU-compatible `grep`, and Git for tree scanning or
the pre-push hook. No runtime packages need to be installed on a typical Linux
system.

Tests additionally require Python 3 and standard Unix utilities (`mktemp`,
`mkdir`, `rm`). On Debian or Ubuntu, install the packages with:

```sh
sudo apt-get install bash grep git python3 coreutils
```

## Install and use

Clone the repository, then scan its working tree:

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
executable. The hook scans outgoing commit patches and changed file names and
refuses a push on a match or scanner error.

## Configuration and modes

There are no environment variables or configuration files. Pass a root path to
scan a different tree:

```sh
./secret-scan.sh /path/to/project
```

Other modes:

```sh
printf '%s\n' 'ordinary example text' | ./secret-scan.sh --stdin
git diff --name-only | ./secret-scan.sh --names
```

Exit status is 0 for clean, 1 for a detected match, and 2 for a scanner error.
Callers should treat status 2 as a failure.

## Limits and caveats

Detection uses a built-in set of patterns and is not comprehensive. It may miss
new credential formats and may flag ordinary text (in particular words starting
with `sk-` followed by 20 or more allowed characters). It does not contact
credential providers or determine whether a value is active. The tree scan
checks tracked file names and recursively scans readable working-tree content,
excluding `.git` and this scanner script. It is not a substitute for reviewing
history or using a maintained, broader secret-detection tool.

## Tests

Run the test suite with:

```sh
bash tests/test_secret_scan.sh
```

The tests construct all credential-shaped inputs at runtime, discard scanner
output, and use a temporary `HOME` and XDG configuration/cache directories.
