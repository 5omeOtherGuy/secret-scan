# Contributing

Thanks for helping. Small fixes (a typo, a missed credential format, a clearer
error) are welcome directly as a pull request. For larger changes, open an
issue first so we can agree on the approach.

## Before you open a pull request

Run the gate; it must pass:

```sh
scripts/gate
```

It syntax-checks every Bash script, runs `tests/test_secret_scan.sh` and scans
the repository for secrets. To have it run before every push, enable the
repository's hooks once per checkout:

```sh
git config core.hooksPath .githooks
```

Tests must never contain a real or literal credential-shaped string: build
every test vector from parts at runtime and discard scanner output, as the
existing tests do. The tool stays dependency-free (Bash, GNU grep, Git;
Python 3 only in tests) and keeps its exit codes: 0 clean, 1 hit, 2 scanner
error.

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) for
the pull request title, for example `fix: detect sk_test_ keys`. Pull
requests are squash-merged.

## Triage and review

The project is in `pre-release`: issues and pull requests are triaged and
reviewed on a best-effort basis.

## Security issues

Please do not report vulnerabilities in public issues; see
[SECURITY.md](SECURITY.md).

## Licence

Contributions are licensed under the repository's [MIT licence](LICENSE).
There is no contributor licence agreement.
