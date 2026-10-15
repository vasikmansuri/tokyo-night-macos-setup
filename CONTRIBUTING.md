# Contributing

Thanks for helping improve Tokyo Night macOS Setup. This script edits people's dotfiles, so every change has to be safe, tested and easy to undo.

## Reporting a problem

1. Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) and the existing [issues](https://github.com/vasikmansuri/tokyo-night-macos-setup/issues).
2. Open a [bug report](https://github.com/vasikmansuri/tokyo-night-macos-setup/issues/new/choose). Include:
   - your macOS version (`sw_vers -productVersion`) and architecture (`uname -m`)
   - the exact command you ran
   - the error output, or the **Things to look at** section from the end of the run
3. **Remove secrets first.** Your `~/.zshrc`, its backups and the dry-run previews can contain API keys and tokens. Never attach them unedited.

Security problems go through [SECURITY.md](SECURITY.md), not public issues.

## Suggesting a feature

Open a [feature request](https://github.com/vasikmansuri/tokyo-night-macos-setup/issues/new/choose) and describe the problem it solves. New tools and settings should fit the project's goal: a clean, fast Tokyo Night developer setup that keeps the user's own configuration.

## Making a change

1. Fork the repository and create a branch from `main`.
2. Make your change in `tokyo-night-setup.sh`, and update the docs in the same pull request:
   - the README's **Options** table if you add or change a flag
   - the README's **What gets changed** table if the script installs or edits something new
   - [CHANGELOG.md](CHANGELOG.md), under **Unreleased**
3. Test it (see below).
4. Open a pull request and fill in the template, including what you tested.

### Rules for the script

- **Keep it compatible with macOS's built-in bash 3.2.** Don't use `mapfile`, associative arrays, `${var,,}` or other bash 4+ features.
- **Back up before every change.** Write files with `install_file`, or call `backup_file` before editing one in place, so the change is recorded in the manifest and the undo script can reverse it.
- **The plan comes first.** Anything that changes the machine must happen after the user confirms, and must be shown in the plan or the dry run.
- **`--dry-run` must not change any config file.**
- **Quote every path.** Paths can contain spaces (`~/Library/Application Support/...`).
- **Keep the user's configuration.** Don't remove a user's lines without listing them in the plan.
- **No new remote scripts** piped into a shell. Downloads should come from well-known sources and be checked before use, as the bat theme download is.

## Testing

Run the safe test suite before every pull request:

```bash
bash tests/run-tests.sh
```

It runs `bash -n`, ShellCheck (if installed) and sandboxed tests that use a throwaway `HOME`, so it never touches your dotfiles. If you add behavior, add a test for it in `tests/run-tests.sh`.

If you change what the script installs, writes or undoes, also test a full install in a separate macOS user account or a VM. **Don't test a full install on the Mac you use every day.** [docs/TESTING.md](docs/TESTING.md) has the full checklist and a template for reporting your results.
