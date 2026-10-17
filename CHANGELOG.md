# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions will
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `install-git-hooks.sh` installs the hook into the repository it sits in,
  from any working directory and from linked worktrees. Before, it looked one
  directory too high and failed or wrote into an enclosing repository. It now
  refuses clearly when `hooks/pre-push` or `secret-scan.sh` is missing or the
  scanner is not executable.
