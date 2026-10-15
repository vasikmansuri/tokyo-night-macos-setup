# Security policy

## Supported versions

Only the latest version on the `main` branch is supported. There are no separate release branches.

## Reporting a vulnerability

Please **don't** open a public issue for a security problem.

Email **mansurivasik@gmail.com** with:

- what the problem is and which part of `tokyo-night-setup.sh` it affects
- steps to reproduce it, ideally with `--dry-run` or in a disposable environment
- the impact you expect (for example, a file overwritten without a backup, or a command run without confirmation)

You should get a reply within a week. Once a fix is ready, it will be released on `main` and credited to you unless you prefer otherwise.

## Never publish secrets

When you report a bug or ask for help, **remove secrets first**. These files can contain API keys, tokens and passwords copied from your shell configuration:

- `~/.zshrc` and its backups (`~/.zshrc.backup-*`)
- the dry-run previews in `~/.tokyo-night-setup/preview-*/`
- `~/.gitconfig` and its backups, which can include credential helpers or tokens in URLs
- terminal output that prints your environment

Replace each secret with a placeholder such as `<REDACTED>` before sharing. If you posted a secret by accident, revoke it with its provider straight away. Deleting the comment isn't enough.

## What the script does that matters for security

So you can judge the risk before running it:

- **It downloads and runs software.** If Homebrew is missing, it runs the official Homebrew installer from `raw.githubusercontent.com/Homebrew/install`. It installs Homebrew packages, downloads the bat theme from `folke/tokyonight.nvim` (and checks it is a theme file), installs Node with `nvm`, and runs `npx react-native doctor` or `npx --yes expo-doctor` in your project.
- **It uses `sudo` only for Xcode**: `xcode-select -s` and `xcodebuild -license accept`, and only when Xcode is installed and needs them. Some Homebrew casks (such as Zulu) ask for your password through their own installers. The script refuses to run as root.
- **The script itself doesn't collect or send any data.** Tools it installs or runs have their own policies. It never reads or changes your Git name, email or credentials.
- **It keeps local records** in `~/.tokyo-night-setup/` (manifests, undo scripts, previews) and backups next to each changed file. Treat these like the originals: they can contain the same secrets.
