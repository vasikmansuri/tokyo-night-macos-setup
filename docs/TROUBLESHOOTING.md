# Troubleshooting

Most problems are reported by the script itself, at the end of the run under **Manual steps still needed** or **Things to look at**. This page explains those messages and other common issues.

If something here doesn't help, [open an issue](https://github.com/vasikmansuri/tokyo-night-macos-setup/issues/new/choose) with your macOS version, `uname -m` and the error output. Remove any tokens or keys first.

- [Undoing a run](#undoing-a-run)
- [Fonts and icons](#fonts-and-icons)
- [Homebrew](#homebrew)
- [zsh and the prompt](#zsh-and-the-prompt)
- [Ghostty](#ghostty)
- [Terminal.app](#terminalapp)
- [Git and delta](#git-and-delta)
- [Node, Java, Android and Xcode](#node-java-android-and-xcode)

## Running the script

**`zsh: permission denied`.** Files downloaded with a browser aren't executable. Run `bash ~/Downloads/tokyo-night-setup.sh`, or `chmod +x` it first.

**`syntax error near unexpected token '<'`** (older copies run with `sh`). Run it with `bash`, not `sh`. Current versions restart themselves with bash.

**Don't use `sudo`.** The script refuses to run as root and asks for your password only when a step needs it.

## Undoing a run

Every run prints the path of its undo script. If you lost it, list them:

```bash
ls ~/.tokyo-night-setup/undo-*.sh
bash ~/.tokyo-night-setup/undo-<timestamp>.sh
```

If you ran the script more than once, run the undo scripts from newest to oldest. Each one restores the state from just before its own run.

**"Stopped before the end. To undo the changes made so far…"** means the run was interrupted (an error or Ctrl-C) after it had changed some files. The printed undo script restores exactly those files.

To restore one file by hand, copy its backup back:

```bash
ls ~/.zshrc.backup-*
cp -p ~/.zshrc.backup-2026-10-15 ~/.zshrc
```

## Fonts and icons

**Icons show as boxes or question marks.** The terminal isn't using a Nerd Font.

- Ghostty: the generated config sets `font-family = JetBrainsMono Nerd Font`. Open a new window after setup.
- VS Code, Cursor, Windsurf: the script sets `terminal.integrated.fontFamily`. Open a new terminal tab or restart the editor.
- JetBrains IDEs: *Settings → Editor → Color Scheme → Console Font → JetBrainsMono Nerd Font*.

**"JetBrainsMono Nerd Font files not found"** means the font cask didn't install. Run `brew install --cask font-jetbrains-mono-nerd-font`.

**"JetBrainsMono Nerd Font not found by macOS yet"** (Terminal.app step). The font was just installed and macOS hasn't registered it. Log out and back in, or open Font Book once, then run the script again with `--terminal-app`.

## Homebrew

**`brew: command not found` after Homebrew was installed.** The current window doesn't have Homebrew on its PATH yet. Open a new terminal, or run:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
eval "$(/usr/local/bin/brew shellenv)"      # Intel
```

**"brew install --cask zulu@17 failed"** (or another package). The run continues and reports the failure. Common causes are a network error or a cancelled password prompt (Zulu and some casks ask for your password). Run the failed command yourself to see the full error, then run the script again. Packages that are already installed are skipped.

**"already present (installed outside Homebrew) — skipped".** Ghostty, Android Studio or Zulu 17 already exists in `/Applications` or `/Library/Java`, so the script leaves it alone.

## zsh and the prompt

**zsh prints errors when it starts.** Check the file's syntax, then restore it if needed:

```bash
zsh -n ~/.zshrc
zsh -i -c exit        # shows start-up errors
```

If the error comes from a line you carried over from your old file, fix or remove that line. Otherwise run the undo script.

**"The reorganised ~/.zshrc failed a syntax check; keeping your original lines verbatim instead."** The script couldn't safely split your old `~/.zshrc`, so it kept all of your lines unchanged in section 3. Review that section for duplicates.

**"zsh start-up: … NOT under 0.3 s".** Find the slow part:

```bash
ZSH_PROFILE=1 zsh -i -c exit
```

Common causes are oh-my-zsh, conda, pyenv, rbenv or SDKMAN initialization, and `/usr/libexec/java_home` calls. The plan warns you about these when it finds them.

**The old prompt (Powerlevel10k) still appears.** Starship is loaded last and replaces it. If you see both, remove the Powerlevel10k lines from `~/.zshrc`.

**An alias I had is gone.** Aliases with the same name as one the setup manages (`ls`, `ll`, `cat`, `gs` and so on) are replaced. The plan and dry run list every removed line and the reason. Your old line is still in the backup.

## Ghostty

**Ghostty doesn't use the theme or font.** Ghostty also reads `~/Library/Application Support/com.mitchellh.ghostty/config`, which can override `~/.config/ghostty/config`. The plan warns if that file exists. Move your settings into one file.

**Check the config:**

```bash
/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config
```

## Terminal.app

**"Terminal.app profile failed".** macOS asked for Automation permission and it was denied. Allow it in *System Settings → Privacy & Security → Automation*, then run the script again with `--terminal-app`.

**Restoring Terminal.app settings.** Quit Terminal.app first, then run the undo script. It imports the settings that were exported before the change.

Terminal.app can only take background, text and cursor colors from a script, so its theme is simpler than Ghostty's.

## Git and delta

**"git X.Y is older than 2.35 (no zdiff3)".** The script used `merge.conflictStyle=diff3` instead. Install a newer Git with `brew install git` and run the script again.

**Diffs aren't colored.** Check that delta is the pager: `git config --global --get core.pager` should print `delta`.

## Node, Java, Android and Xcode

**"nvm was not found, so Node LTS was not installed".**

```bash
brew install nvm && mkdir -p ~/.nvm
```

Then run the script again.

**"'corepack enable' failed".** Run `npm install -g corepack && corepack enable`.

**"JAVA_HOME … does not exist yet".** Zulu 17 isn't installed. Run `brew install --cask zulu@17`, then open a new terminal.

**"Android Studio has not set up the SDK yet".** Open Android Studio once and finish the Setup Wizard. Then in *More Actions → SDK Manager*, install Android SDK Platform 35, Build-Tools 35, Command-line Tools (latest), the Emulator and Platform-Tools. Run the script again to re-check.

**"Missing Android SDK packages".** Run the `sdkmanager …` command the script printed, then `yes | sdkmanager --licenses`.

**"Xcode is not installed".** Install it from the [App Store](https://apps.apple.com/app/xcode/id497799835), open it once, then run the script again. The script never installs Xcode.

**"No iOS Simulator runtime is installed".**

```bash
xcodebuild -downloadPlatform iOS
```

Or use *Xcode → Settings → Components*.

**The React Native doctor reports problems.** The script prints a suggested fix under each failing check. For Expo projects, the usual fix is `npx expo install --fix`.
