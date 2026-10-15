## What this changes

<!-- What does this pull request change, and why? Link the issue if there is one. -->

## Testing

<!-- Only tick what you actually ran. See docs/TESTING.md. -->

- [ ] `bash tests/run-tests.sh` passes
- [ ] Dry run with a throwaway HOME: `HOME="$(mktemp -d)" ./tokyo-night-setup.sh --dry-run`
- [ ] Full install in a separate macOS user account or VM (needed if this changes what the script installs, writes or undoes)
- [ ] Undo script restores everything this change touches
- [ ] Added or updated a test in `tests/run-tests.sh` for new behavior

Tested on (macOS version, `uname -m`, how):

## Safety

- [ ] Every file the script changes is backed up first and recorded for undo
- [ ] `--dry-run` still changes no config files
- [ ] Works with macOS's built-in bash 3.2
- [ ] Paths are quoted (they can contain spaces)

## Documentation

- [ ] README **Options** table updated (if flags changed)
- [ ] README **What gets changed** table updated (if the script installs or edits something new)
- [ ] `CHANGELOG.md` updated under **Unreleased**
