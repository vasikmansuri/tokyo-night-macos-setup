# Changelog

Notable changes to this project. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The project doesn't publish numbered releases yet, so entries are grouped by date.

## Unreleased

### Fixed
- A run that stops part-way (an error or Ctrl-C) now still writes an undo script for the files it already changed, and prints its path. Before, the undo script was only written at the very end.
- The `podi`, `podclean` and `gradleclean` aliases now run in a subshell, so a missing `ios/` or `android/` folder no longer moves you to the parent directory.
- The plan said the kept lines from your old `~/.zshrc` go into section 2 of the new file; they go into section 3.

### Added
- `tests/run-tests.sh`: a test suite that runs in a throwaway `HOME` and covers options, backups, symlinks, paths with spaces, undo, the `~/.zshrc` merge and the dry run.
- A GitHub Actions workflow with ShellCheck, `bash -n` and the test suite on macOS.
- `.shellcheckrc`, plus small ShellCheck clean-ups. Script behavior is unchanged apart from the fixes above.
- Documentation: a rewritten README, `docs/TESTING.md`, `docs/TROUBLESHOOTING.md`, `docs/VIDEO_DEMO.md`, `CONTRIBUTING.md`, `SECURITY.md`, issue and pull request templates, and a social preview image.

## 2026-10-14

### Added
- First public version of `tokyo-night-setup.sh`: Ghostty, Starship, zsh, CLI tools, Git delta, editor terminal fonts, an optional Terminal.app profile, and a React Native toolchain, with a dry run, automatic backups and an undo script.

### Changed
- README rewritten to present the project as a general macOS developer setup.
