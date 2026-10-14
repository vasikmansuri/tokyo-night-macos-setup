# Tokyo Night macOS Setup

A one-command script that turns a Mac into a clean, fast developer workstation with a **Tokyo Night** theme. It sets up the terminal, shell, prompt, Git and editor terminals. It also installs a ready-to-use **mobile development toolchain** (Node, Java, Android and iOS tools) for React Native. Your existing config is kept.

It shows you a full plan before it does anything. It backs up every file before changing it, and it writes an undo script when it finishes.

![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![Platform](https://img.shields.io/badge/platform-macOS-000000?logo=apple&logoColor=white)
![Theme](https://img.shields.io/badge/theme-Tokyo%20Night-7aa2f7)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Features

**Terminal & shell**
- [Ghostty](https://ghostty.org) with the Tokyo Night theme and JetBrains Mono Nerd Font
- Two-line [Starship](https://starship.rs) prompt in Tokyo Night colors (shows Git, Node, Ruby and Kotlin)
- A reorganized `~/.zshrc`. **Your own PATH, exports, tools and aliases are kept.**
- Modern CLI tools: `eza`, `bat`, `fd`, `fzf`, `zoxide`, `btop`, `git-delta`
- zsh autosuggestions and syntax highlighting
- Git diffs through `delta` with `zdiff3` conflict style. Your Git name, email and credentials are not touched.
- Optional Tokyo Night profile for the built-in Terminal.app
- Editor terminals in VS Code, Cursor, Windsurf, VS Code Insiders and VSCodium get the Nerd Font so icons show there too. Your other settings and comments are kept.

**Developer toolchain (Node, Java, Android, iOS)**
- Watchman, CocoaPods, Ruby, Android Studio and Zulu JDK 17
- Node LTS through `nvm`, with `corepack` enabled
- `JAVA_HOME`, `ANDROID_HOME` and `PATH` set up in a "Mobile / React Native" section of `~/.zshrc`
- Checks Xcode and the Android SDK (it never installs Xcode for you)
- Runs `npx react-native doctor` (or `npx expo-doctor` for Expo projects) at the end, with a suggested fix for each failing check

**Safety**
- Pre-flight checks, then a full **plan with diffs** before anything changes
- `--dry-run` mode that only shows the plan
- Every file is backed up first as `<file>.backup-YYYY-MM-DD`. Existing backups are never overwritten.
- Checks that zsh starts with no errors, in under 0.3 seconds
- Writes a one-step **undo script**

---

## Requirements

- macOS (Apple Silicon or Intel)
- An admin account (Homebrew is installed if it is missing)
- Xcode from the App Store, if you want to build for iOS

---

## Quick start

```bash
git clone https://github.com/vasikmansuri/tokyo-night-macos-setup.git
cd tokyo-night-macos-setup
chmod +x tokyo-night-setup.sh

# Preview first: shows the plan and changes nothing
./tokyo-night-setup.sh --dry-run

# Apply
./tokyo-night-setup.sh
```

When it finishes, open a new terminal window (or Ghostty) to see the new setup.

---

## Options

| Flag | What it does |
| --- | --- |
| *(none)* | Interactive mode: shows the plan and asks before applying (recommended) |
| `-n`, `--dry-run` | Shows the plan and diffs only. Nothing is changed. |
| `-y`, `--yes` | Skips the confirmation prompts |
| `--terminal-app` | Also creates the Tokyo Night profile for Terminal.app |
| `--no-terminal-app` | Skips the Terminal.app profile |
| `--project <dir>` | React Native project to run the doctor in (default: current folder) |
| `-h`, `--help` | Shows help |

---

## What gets changed

| File | Change |
| --- | --- |
| `~/.config/ghostty/config` | Ghostty theme, font and window settings |
| `~/.config/starship.toml` | Tokyo Night prompt |
| `~/.zshrc` | Reorganized into sections. Your existing PATH, exports and aliases are carried over. |
| `~/.gitconfig` | `delta` pager and `zdiff3` merge style only |
| Editor `settings.json` | `terminal.integrated.fontFamily` only |
| Terminal.app | New "Tokyo Night" profile (optional; your current settings are exported first) |

Setup records (the list of changed files, the undo script and the plan preview) are saved in `~/.tokyo-night-setup/`.

---

## Shell shortcuts

**General**

| Alias | Command |
| --- | --- |
| `ls` / `ll` / `la` / `lt` | `eza` listings with icons and Git status (`lt` = tree view) |
| `cat` | `bat --paging=never` |
| `top` | `btop` |
| `gs` / `gl` / `gd` / `gco` | git status / log graph / diff / checkout |
| `reload` | `source ~/.zshrc` |

**Mobile development (React Native)**

| Alias | Command |
| --- | --- |
| `rn` | `npx react-native` |
| `rns` / `rnsc` | Start Metro / start Metro with a reset cache |
| `rna` / `rni` | Run on Android / iOS |
| `podi` | `bundle exec pod install` in `ios/` |
| `podclean` | Removes Pods, the lock file and the build folder, then reinstalls |
| `gradleclean` | `./gradlew clean` in `android/` |
| `adbr` | `adb reverse tcp:8081 tcp:8081` |
| `emus` / `sims` | List Android emulators / iOS simulators |
| `emu [name]` | Starts an Android emulator (the first one if no name is given) |
| `expo` | `npx expo` |

---

## Undo

Each run writes its own undo script, and its path is printed at the end:

```bash
bash ~/.tokyo-night-setup/undo-<timestamp>.sh
```

This puts every changed file back to its backup and removes files that the run created. You can also restore any single file from its `.backup-YYYY-MM-DD` copy.

---

## Manual steps

The script prints anything it can't do for you. Usually this means:

- **JetBrains IDEs** (Android Studio, IntelliJ): set the terminal font to *JetBrainsMono Nerd Font* in *Settings → Editor → Color Scheme → Console Font*.
- **Android SDK**: open Android Studio once and install the SDK, platform tools and an emulator from *SDK Manager* and *Device Manager*.
- **Xcode**: install it from the App Store, open it once, and accept the license.

---

## Credits

- [Tokyo Night](https://github.com/folke/tokyonight.nvim) color scheme by folke
- [Ghostty](https://ghostty.org), [Starship](https://starship.rs), [eza](https://github.com/eza-community/eza), [bat](https://github.com/sharkdp/bat), [delta](https://github.com/dandavison/delta)

## License

[MIT](LICENSE)
