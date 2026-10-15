# YouTube demo plan

A 2½-minute video that shows what the project does, how safe it is, and the finished setup.

**Record the install in a clean environment**, such as a new macOS user account or a VM (see [TESTING.md](TESTING.md#level-3-full-install-in-a-disposable-environment)). That way the demo shows a real first run, and none of your personal files, paths or tokens appear on screen. Don't say the install worked in the video unless the recording shows it working.

## Before you record

**Screen**
- Record at 1920 × 1080 (or 2560 × 1440 scaled down). Hide the Dock and desktop icons, and turn on Do Not Disturb.
- Terminal font size: **18–20 pt** for the install (Ghostty: `font-size = 20` in the demo account's config, or **Cmd +**). Viewers on phones need large text.
- Browser zoom: **125–150 %** for the GitHub pages.
- Run `clear` before each scene.

**Privacy check**
- Use a demo account with a neutral name such as `demo`, so paths read `/Users/demo`.
- Close other apps, browser tabs and notifications. Sign out of anything you don't need.
- Make sure no `.zshrc`, `.gitconfig` or environment output on screen contains tokens.
- Review the recording before publishing. Blur anything private.

**Cursor and pacing**
- Move the cursor slowly and deliberately, and keep it still while you talk about something.
- Enable a cursor highlight in your recording tool if it has one.
- **Pause 2–3 seconds** after each command appears, so viewers can read it before it runs.
- Speed up long installs (Homebrew downloads) 4–8× in editing, with a small "sped up" label.

**Transitions**
- Use simple cuts or a short 0.3-second cross-fade. Avoid flashy transitions.
- Zoom in (in editing) on the command you're typing and on key parts of the plan output.

## Outline

| Time | Scene | On screen |
| --- | --- | --- |
| 0:00–0:12 | Hook | The finished Ghostty setup: prompt, icons, `ll`, a colored `git diff` |
| 0:12–0:25 | Intro | The README banner and the one-line description |
| 0:25–0:45 | Repository tour | README: features, the "What gets changed" table, the undo section |
| 0:45–1:00 | Clone | `git clone` and `cd` in a plain terminal |
| 1:00–1:30 | Dry run | `./tokyo-night-setup.sh --dry-run`; scroll through the plan and diffs |
| 1:30–2:00 | Install | `./tokyo-night-setup.sh`, answer `y`, sped-up install, the summary |
| 2:00–2:20 | Result | Open Ghostty: prompt, `ll`, `lt`, `cat`, `git diff` through delta |
| 2:20–2:35 | Backups and undo | The summary's backup list and the undo script path |
| 2:35–2:45 | Call to action | The GitHub URL on screen |

## Commands for each scene

```bash
# Clone (0:45)
git clone https://github.com/vasikmansuri/tokyo-night-macos-setup.git
cd tokyo-night-macos-setup

# Dry run (1:00)
./tokyo-night-setup.sh --dry-run

# Install (1:30)
./tokyo-night-setup.sh

# Result, in Ghostty (2:00)
cd ~/tokyo-night-macos-setup
ll
lt
cat README.md
echo "# demo" >> README.md && git diff && git checkout README.md

# Backups and undo (2:20)
ls ~/.zshrc.backup-*
ls ~/.tokyo-night-setup/
```

## Narration script

Read it at a relaxed pace. Each paragraph matches one scene.

**[0:00 Hook]**
"This is my terminal. A Tokyo Night theme, a clean two-line prompt, icons, and Git diffs that are actually easy to read. And it took one command to set up."

**[0:12 Intro]**
"It's called Tokyo Night macOS Setup. It's a free, open-source script that sets up Ghostty, zsh, the Starship prompt, modern command-line tools and Git delta, plus an optional Node, Java, Android and iOS toolchain."

**[0:25 Repository tour]**
"Here's the repository. The README lists every feature, and this table shows exactly which files it changes. Your own PATH, exports and aliases are kept. And this part matters most: every file is backed up first, and you get an undo script."

**[0:45 Clone]**
"Let's try it on a fresh Mac. First, clone the repository and go into the folder."

*(Pause while the clone finishes.)*

**[1:00 Dry run]**
"Before changing anything, I'll run it with dash-dash-dry-run. This shows the full plan: which packages it would install, which files it would back up, the Git settings it would change, and a diff of every new config file. Nothing on my system changes. I'd recommend always starting here."

*(Scroll slowly. Pause on the backup list and on the zshrc diff.)*

**[1:30 Install]**
"Happy with the plan? Run it again without the flag. It shows the plan once more and asks before it does anything. I'll say yes."

*(Sped-up section.)*

"It installs what's missing with Homebrew, writes the new configs, and then checks its own work: that zsh starts with no errors, and how fast it starts."

**[2:00 Result]**
"Let's open Ghostty. There's the new prompt, with the folder, the Git branch, and the time on the right. `ll` lists files with icons and Git status. `lt` shows a tree. `cat` now has syntax highlighting. And Git diffs go through delta, with line numbers and colors."

**[2:20 Backups and undo]**
"If you don't like it, going back is easy. Every changed file has a dated backup next to it, and the script wrote a one-line undo command that restores all of them."

**[2:35 Call to action]**
"The link is in the description. Run the dry run, see what it would do, and if it helps you, a star on GitHub is much appreciated. Thanks for watching."

## After publishing

When the video is live, add it to the README (replace the "Demo video" comment above the Contributing section):

```markdown
## Demo

[![Watch the demo on YouTube](https://img.youtube.com/vi/<VIDEO_ID>/maxresdefault.jpg)](https://www.youtube.com/watch?v=<VIDEO_ID>)
```

Replace `<VIDEO_ID>` with the real ID from the video's URL.

## Suggested YouTube details

- **Title:** Tokyo Night macOS Setup: a beautiful developer terminal in one command
- **Description:** start with the GitHub link, then a short list of what it sets up and the dry-run tip. Add chapters using the outline's timestamps.
- **Thumbnail:** `docs/images/social-preview.png` works as a starting point, or a close-up of the finished Ghostty window.
