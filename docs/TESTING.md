# Testing

This project changes real dotfiles and installs software, so testing is split into three levels. Run them in order, and only move to the next level when the previous one passes.

| Level | Where | Changes your machine? | Who runs it |
| --- | --- | --- | --- |
| [1. Static checks and test suite](#level-1-static-checks-and-test-suite) | Any Mac (some checks on any OS) | No | Everyone, before every pull request. CI runs it too. |
| [2. Dry run](#level-2-dry-run) | macOS | No config files | Everyone |
| [3. Full install](#level-3-full-install-in-a-disposable-environment) | A separate macOS user account or a VM | Yes, inside that environment | Changes to apply, backup or undo logic |

**Never test a full install on the Mac you use every day.** Use level 3's disposable environment instead.

## Level 1: static checks and test suite

```bash
bash -n tokyo-night-setup.sh          # syntax only
shellcheck tokyo-night-setup.sh tests/run-tests.sh
git diff --check                      # whitespace errors in your changes
bash tests/run-tests.sh               # everything above, plus the sandboxed tests
```

Install ShellCheck with `brew install shellcheck`. The repository's `.shellcheckrc` turns off two warnings that only affect text printed to the user. If ShellCheck isn't installed, the test suite skips it and says so.

`tests/run-tests.sh` loads the script's functions into a new bash process whose `HOME` is a temporary folder. It never reads or writes your real dotfiles, and it installs nothing. It checks:

| Area | What is verified |
| --- | --- |
| Command line | `--help` works; unknown options and `--project` without a folder are rejected |
| Backups | An existing backup is never overwritten (`-2` suffix); `install_file` backs up, writes and records each change |
| Existing config | A symlinked file keeps its link and the new content is written through it; paths with spaces work |
| Undo | The undo script restores changed files and removes created ones; a run that stops early still leaves a working undo script |
| `~/.zshrc` merge | User lines and `if` blocks are kept; duplicate and managed lines are removed; managed aliases are replaced; the result passes `zsh -n` |
| Dry run (macOS only) | Exits 0, leaves `~/.zshrc` unchanged, creates no config files or backups, and writes only previews to `~/.tokyo-night-setup/preview-*` |

Expected result:

```text
13 passed, 0 failed, 0 skipped
```

On Linux the dry-run test is skipped (`needs macOS`). The `~/.zshrc` merge uses `awk`, and macOS's awk behaves differently from GNU awk and mawk, so treat results on other systems as a guide only. CI runs the suite on macOS.

### Documentation checks

- Every relative link in the Markdown files should point to a file that exists. A quick check from the repository root:

  ```bash
  for f in *.md docs/*.md; do
    grep -oE '\]\([^) #]+\)' "$f" | sed 's/^](//; s/)$//' | grep -vE '^(https?:|mailto:)' |
      while read -r link; do [ -e "$(dirname "$f")/$link" ] || echo "$f: broken link $link"; done
  done
  ```

- Every flag in the README's Options table should appear in `parse_args` in `tokyo-night-setup.sh`, and the reverse.
- When you change what the script installs or edits, update the README's **What gets changed** table.

### Continuous integration

`.github/workflows/checks.yml` runs on every pull request and on pushes to `main`:

- **Lint** (Ubuntu): `bash -n`, ShellCheck and `git diff --check`.
- **Sandboxed tests** (macOS): `bash tests/run-tests.sh`.

CI never runs the installer for real. It can't test Homebrew installs, Xcode, Terminal.app or a real login shell.

## Level 2: dry run

A dry run builds the new configs and prints the plan without changing any config file. To be completely sure it touches nothing of yours, point `HOME` at a throwaway folder:

```bash
SANDBOX="$(mktemp -d)"
cp ~/.zshrc "$SANDBOX/.zshrc"         # optional: test the merge with your real file
HOME="$SANDBOX" ./tokyo-night-setup.sh --dry-run
```

Check that:

- the run ends with `Dry run — nothing was changed.` and exits with code 0
- the "lines removed or de-duplicated" list contains nothing you want to keep
- `"$SANDBOX/.tokyo-night-setup/preview-"*/zshrc.new` contains your PATH, exports and aliases
- `zsh -n "$SANDBOX/.tokyo-night-setup/preview-"*/zshrc.new` prints nothing

Then delete the sandbox: `rm -rf "$SANDBOX"`. Your `.zshrc` copy may contain secrets, so don't leave it lying around.

A dry run with your real `HOME` is also safe: it only writes previews to `~/.tokyo-night-setup/preview-<timestamp>/`.

## Level 3: full install in a disposable environment

Use one of these:

- **A new macOS user account**: *System Settings → Users & Groups → Add User*, as an Administrator. Homebrew and casks are shared across users, so this tests config changes well but not a first-time Homebrew install. Delete the account afterwards.
- **A macOS virtual machine** (for example UTM or Tart on Apple Silicon). This is the only way to test a completely fresh Mac, including installing Homebrew. Take a snapshot first so you can roll back.

Prepare the environment with the kind of config you want to test, for example an existing `~/.zshrc` with aliases and an `if` block, a symlinked `~/.zshrc` pointing into a dotfiles folder, an oh-my-zsh setup, or a VS Code `settings.json` with comments.

### Install

```bash
./tokyo-night-setup.sh --dry-run      # read the plan
./tokyo-night-setup.sh                # answer y; choose whether to add the Terminal.app profile
```

### What to check after the install

**Files and backups**

- [ ] Every file listed in the summary has a `.backup-YYYY-MM-DD` copy, or is marked as new
- [ ] `~/.tokyo-night-setup/manifest-<timestamp>.tsv` lists the same files
- [ ] A symlinked `~/.zshrc` is still a symlink, and the file it points to has the new content
- [ ] VS Code / Cursor `settings.json` kept its other settings and comments

**Shell, PATH and environment** (in a new terminal)

```bash
zsh -n ~/.zshrc && echo "syntax ok"
zsh -i -c exit                        # should print nothing
echo $JAVA_HOME $ANDROID_HOME
print -l $path | head -20             # Homebrew, Ruby and JDK paths first; no duplicates
command -v starship eza bat fzf zoxide delta
git config --global --get core.pager  # delta
```

- [ ] The script's own **Verification** step shows no warnings, or only expected ones (for example, no Android SDK yet)
- [ ] Start-up time is under 0.3 s, or the warning names a tool you expected to be slow

**Apps**

- [ ] Ghostty opens with the Tokyo Night theme, the two-line prompt and icons
- [ ] `/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config` passes
- [ ] Terminal.app has a "Tokyo Night" profile (only if you chose it)

**Optional toolchain** (only when you changed these steps)

```bash
node -v && npm -v && corepack --version
java -version                         # Zulu 17
xcode-select -p                       # /Applications/Xcode.app/Contents/Developer
pod --version
sdkmanager --list_installed           # if the Android SDK is set up
```

### Run it again on the same day

- [ ] The second run creates `-2` backups and never overwrites the first ones
- [ ] Your aliases and exports are still there, with no duplicates

### Undo

```bash
bash ~/.tokyo-night-setup/undo-<timestamp>.sh   # newest first if you ran it twice
```

- [ ] Every changed file is back to its backup, and files the run created are removed
- [ ] Terminal.app settings are restored (quit Terminal.app first)

### Error handling

- [ ] Press Ctrl-C while packages are installing. The script prints `Stopped before the end` with an undo script path, and that undo script restores the files changed so far.
- [ ] Run with no network. The bat theme download fails with a warning and the rest of the run continues.
- [ ] Run with `sudo`. The script refuses to start.

### Apple Silicon and Intel

The script picks paths by architecture (`uname -m`):

| | Apple Silicon (`arm64`) | Intel (`x86_64`) |
| --- | --- | --- |
| Homebrew prefix | `/opt/homebrew` | `/usr/local` |
| Suggested Android system image | `arm64-v8a` | `x86_64` |

A shell running under Rosetta on Apple Silicon reports `x86_64` and uses the Intel paths. Test both architectures when you change anything path-related.

## Recording results

Add a short report to your pull request:

```text
Tested on:   macOS 26.0.1, arm64, system bash 3.2
Level 1:     bash tests/run-tests.sh → 13 passed, 0 failed, 0 skipped
Level 2:     dry run with sandbox HOME → OK, plan reviewed
Level 3:     new user account / UTM VM / not run (reason)
             install: OK | undo: OK | re-run same day: OK | Ctrl-C: OK
Notes:       anything unexpected
```

Only report a level as passing if you ran it.
