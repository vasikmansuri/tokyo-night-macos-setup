#!/usr/bin/env bash
# =============================================================================
#  tokyo-night-setup.sh  —  clean, professional macOS terminal (Tokyo Night)
#
#  What it does (in order):
#    0. Pre-flight checks, then SHOWS YOU A PLAN (diffs, backups, packages)
#       and asks before touching anything.
#    1. Homebrew (installed if missing) + apps, CLI tools, bat Tokyo Night theme
#    2. ~/.config/ghostty/config
#    3. ~/.config/starship.toml      (two-line Tokyo Night prompt)
#    4. ~/.zshrc                     (reorganised; YOUR PATH/exports/tools KEPT)
#    5. git config --global          (delta + zdiff3; name/email/credentials untouched)
#    6. Optional Terminal.app "Tokyo Night" profile (settings exported first)
#    7. React Native (Android + iOS): Xcode checks (Xcode is never installed by this
#       script), watchman, cocoapods, ruby, Android Studio, Zulu 17, Node LTS via
#       nvm + corepack, a "Mobile / React Native" section + aliases + emu() in
#       ~/.zshrc, Android SDK check, Ruby/Kotlin in the prompt, then
#       `npx react-native doctor` (or `npx expo-doctor`) from a new shell
#    8. Editor terminals: VS Code, Cursor, Windsurf (and Insiders/VSCodium) use their
#       own terminal font; their settings.json gets the Nerd Font so icons show there
#       too (other settings and comments kept). JetBrains IDEs: manual step listed.
#    9. Verifies: zsh starts with no errors, in < 0.3 s
#   10. Prints every changed file + its backup, and writes an UNDO script.
#
#  Every file is backed up BEFORE it is changed:  <file>.backup-YYYY-MM-DD
#  (never overwrites an existing backup; adds -2, -3 … if you run it twice a day)
#
#  Usage:
#    chmod +x tokyo-night-setup.sh
#    ./tokyo-night-setup.sh                 # interactive (recommended)
#    ./tokyo-night-setup.sh --dry-run       # only show the plan, change nothing
#    ./tokyo-night-setup.sh --yes           # no confirmation prompts
#    ./tokyo-night-setup.sh --terminal-app  # also create the Terminal.app profile
#    ./tokyo-night-setup.sh --no-terminal-app
#    ./tokyo-night-setup.sh --project ~/code/MyApp   # where to run the doctor
#                                                    # (default: current folder)
# =============================================================================
set -uo pipefail

TODAY="$(date +%Y-%m-%d)"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
STATE_DIR="$HOME/.tokyo-night-setup"
MANIFEST="$STATE_DIR/manifest-$STAMP.tsv"
UNDO_SCRIPT="$STATE_DIR/undo-$STAMP.sh"
PREVIEW_DIR="$STATE_DIR/preview-$STAMP"
THEME_URL="https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/sublime/tokyonight_night.tmTheme"
DIFF_MAX=250

FORMULAE=(starship eza bat fd fzf zoxide btop git-delta zsh-autosuggestions zsh-syntax-highlighting
          watchman cocoapods ruby)
CASKS=(ghostty font-jetbrains-mono-nerd-font android-studio zulu@17)
JDK17_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
ANDROID_SDK="$HOME/Library/Android/sdk"
PROJECT_DIR=""
XCODE_PREV_PATH=""
XCODE_CHANGED=0

ASSUME_YES=0
DRY_RUN=0
TERMINAL_APP="ask"        # ask | yes | no
WORK=""
INSTALLED_NOW=""
TERMINAL_BACKUP=""
SPLIT_FALLBACK=0
GIT_CFG=""
EDITOR_FONT="JetBrainsMono Nerd Font"
# Editors whose built-in terminal reads "terminal.integrated.*" from their user settings.json.
EDITOR_APPS=("Code|VS Code" "Code - Insiders|VS Code Insiders" "Cursor|Cursor" "Windsurf|Windsurf" "VSCodium|VSCodium")

# ----------------------------------------------------------------------------- output helpers
if [[ -t 1 ]]; then
  B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'
else
  B=""; G=""; Y=""; R=""; D=""; N=""
fi
say()  { printf '%s\n' "$*"; }
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '%s✔%s %s\n' "$G" "$N" "$*"; }
note() { printf '%s•%s %s\n' "$D" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*" >&2; printf '%s\n' "$*" >> "$WORK/warnings.log"; }
die()  { printf '%s✘ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
todo() { printf '%s→%s %s\n' "$Y" "$N" "$*"; printf '%s\n' "$*" >> "$WORK/todo.log"; }

confirm() {   # confirm "prompt [y/N]" default
  local prompt=$1 def=${2:-n} a=""
  if (( ASSUME_YES )); then return 0; fi
  if [[ -r /dev/tty ]]; then read -r -p "$prompt " a </dev/tty || a=""; fi
  a=${a:-$def}
  [[ $a == [yY]* ]]
}

usage() { awk 'NR==1{next} /^# =+$/{c++; if(c==2) exit} {sub(/^# ?/,""); print}' "$0"; }

parse_args() {
  while (( $# )); do
    case "$1" in
      -y|--yes)            ASSUME_YES=1 ;;
      -n|--dry-run)        DRY_RUN=1 ;;
      --terminal-app)      TERMINAL_APP="yes" ;;
      --no-terminal-app)   TERMINAL_APP="no" ;;
      --project)           shift; PROJECT_DIR="${1:-}"; [[ -n $PROJECT_DIR ]] || die "--project needs a folder" ;;
      -h|--help)           usage; exit 0 ;;
      *)                   die "Unknown option: $1 (try --help)" ;;
    esac
    shift
  done
}

# ----------------------------------------------------------------------------- backups & manifest
next_backup_path() {   # pure: prints the first free <file>.backup-DATE[-N]
  local f=$1 b="$1.backup-$TODAY" n=1
  while [[ -e $b || -L $b ]]; do n=$((n + 1)); b="$f.backup-$TODAY-$n"; done
  printf '%s' "$b"
}

record_change() { printf '%s\t%s\n' "$1" "$2" >> "$MANIFEST"; }

backup_file() {   # backup_file <path>   (records it in the manifest)
  local f=$1 b
  if [[ -e $f || -L $f ]]; then
    b="$(next_backup_path "$f")"
    cp -pL "$f" "$b" || die "Could not back up $f"
    record_change "$f" "$b"
    ok "Backed up $f → $b"
  else
    record_change "$f" ""
  fi
}

install_file() {  # install_file <source> <dest>   (backup first, write through symlinks)
  local src=$1 dest=$2
  mkdir -p "$(dirname "$dest")" || die "Cannot create $(dirname "$dest")"
  if [[ -L $dest ]]; then
    warn "$dest is a symlink → $(readlink "$dest"); the new content is written through the link."
  fi
  backup_file "$dest"
  cat "$src" > "$dest" || die "Could not write $dest"
  ok "Wrote $dest"
}

# ----------------------------------------------------------------------------- generators
gen_ghostty() {
  cat <<'EOF'
# Ghostty — Tokyo Night  (generated by tokyo-night-setup.sh)
theme = TokyoNight Night
font-family = JetBrainsMono Nerd Font
font-size = 14
font-thicken = true
adjust-cell-height = 10%
window-padding-x = 14
window-padding-y = 10
window-padding-balance = true
window-save-state = always
macos-titlebar-style = tabs
background-opacity = 0.96
background-blur = 20
cursor-style = bar
cursor-style-blink = true
mouse-hide-while-typing = true
copy-on-select = clipboard
macos-option-as-alt = left
shell-integration = zsh
keybind = cmd+d=new_split:right
keybind = cmd+shift+d=new_split:down
keybind = cmd+alt+left=goto_split:left
keybind = cmd+alt+right=goto_split:right
EOF
}

gen_starship() {
  cat <<'EOF'
# Starship — Tokyo Night two-line prompt  (generated by tokyo-night-setup.sh)
"$schema" = 'https://starship.rs/config-schema.json'

add_newline = true
command_timeout = 800

# Line 1: context   |   Line 2: ❯ input
format = """
$directory\
$git_branch\
$git_state\
$git_status\
$nodejs\
$php\
$python\
$java\
$kotlin\
$ruby\
$docker_context\
$cmd_duration
$character"""

# Time (HH:MM) on the right
right_format = "$time"

[directory]
style = "bold #7aa2f7"
truncation_length = 4
truncation_symbol = "…/"
truncate_to_repo = false

[git_branch]
symbol = "\ue0a0 "
style = "bold #bb9af7"
format = "[on](#565f89) [$symbol$branch(:$remote_branch)]($style) "

[git_state]
style = "#ff9e64"
format = '[\($state( $progress_current/$progress_total)\)]($style) '

[git_status]
style = "#e0af68"
format = '([\[$all_status$ahead_behind\]]($style) )'

[nodejs]
symbol = "\ue718 "
style = "#9ece6a"
format = "[via](#565f89) [$symbol($version )]($style)"

[php]
symbol = "\ue608 "
style = "#7dcfff"
format = "[via](#565f89) [$symbol($version )]($style)"

[python]
symbol = "\ue73c "
style = "#e0af68"
format = '[via](#565f89) [${symbol}${pyenv_prefix}(${version} )(\($virtualenv\) )]($style)'

[java]
symbol = "\ue256 "
style = "#ff9e64"
format = "[via](#565f89) [$symbol($version )]($style)"

[kotlin]
symbol = "\ue634 "
style = "#ff9e64"
format = "[via](#565f89) [$symbol($version )]($style)"

[ruby]
symbol = "\ue791 "
style = "#f7768e"
format = "[via](#565f89) [$symbol($version )]($style)"

[docker_context]
symbol = "\uf308 "
style = "#7dcfff"
format = "[via](#565f89) [$symbol$context]($style) "

[cmd_duration]
min_time = 2000
style = "#e0af68"
format = "[took](#565f89) [$duration]($style) "

[character]
success_symbol = "[❯](bold #9ece6a)"
error_symbol = "[❯](bold #f7768e)"
vimcmd_symbol = "[❮](bold #7aa2f7)"

[time]
disabled = false
time_format = "%H:%M"
style = "#565f89"
format = "[$time]($style)"
EOF
}

# --- awk program: splits the old ~/.zshrc into "kept" parts, drops what the new
#     setup already manages, and removes exact duplicates. Block-aware
#     (if/for/while/case/functions, multi-line strings, line continuations).
write_split_awk() {
  cat > "$WORK/split.awk" <<'AWK'
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }

function scan_quotes(s,   i, n, c, prev) {
  n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (q == 0) {
      if (c == "\\") { i++; continue }
      if (c == "'") q = 1
      else if (c == "\"") q = 2
      else if (c == "#") {
        prev = (i == 1) ? " " : substr(s, i - 1, 1)
        if (prev == " " || prev == "\t") break
      }
    } else if (q == 1) {
      if (c == "'") q = 0
    } else {
      if (c == "\\") { i++; continue }
      if (c == "\"") q = 0
    }
  }
}

function depth_update(t,   starter) {
  starter = (t ~ /^(if|for|while|until|case|select)[ \t(]/)
  if (starter && t ~ /[;[:space:]](fi|done|esac)[ \t]*;?[ \t]*$/) return
  if (starter || t ~ /^function[ \t]/ || t ~ /\{[ \t]*$/) { depth++; return }
  if (t ~ /^(fi|done|esac)([ \t;]|$)/ || t ~ /^\}/) { depth--; if (depth < 0) depth = 0 }
}

function is_managed(t) {
  if (t ~ /starship init/) return 1
  if (t ~ /zsh-autosuggestions/) return 1
  if (t ~ /zsh-syntax-highlighting/) return 1
  if (t ~ /zoxide init/) return 1
  if (t ~ /fzf --zsh/) return 1
  if (t ~ /\.fzf\.zsh/) return 1
  if (t ~ /compinit/) return 1
  if (t ~ /brew shellenv/) return 1
  if (t ~ /typeset -U/) return 1
  if (t ~ /nvm\.sh/) return 1
  if (t ~ /NVM_DIR/ && t ~ /bash_completion/) return 1
  if (t ~ /opt\/nvm\/etc\/bash_completion/) return 1
  return 0
}

function alias_name(t,   s) {
  s = t
  sub(/^alias[ \t]+/, "", s)
  while (s ~ /^-[A-Za-z]+[ \t]+/) sub(/^-[A-Za-z]+[ \t]+/, "", s)
  sub(/=.*/, "", s)
  return s
}

function dedupable(t) {
  if (t ~ /^(export|source|eval|setopt|autoload|bindkey|zstyle)[ \t]/) return 1
  if (t ~ /^(path|PATH|fpath|FPATH)\+?=/) return 1
  if (t ~ /^\.[ \t]/ || t ~ /^\[/) return 1
  return 0
}

function out(b, s) { if (b == "alias") print s > alias_out; else print s > env_out }

function emit(b, s) {
  if (pendblank && started[b]) out(b, "")
  pendblank = 0
  out(b, s)
  started[b] = 1
}

function flush_comments(b) { if (cbuf != "") { emit(b, cbuf); cbuf = "" } }

function logrm(s, why) {
  gsub(/\n/, "\n      ", s)
  print "  - " s (why != "" ? "    [" why "]" : "") > rm_out
}

function process_unit(s,   t, single, drop, why, bucket, name, v) {
  single = (index(s, "\n") == 0)
  t = trim(s)
  if (single && t ~ /^#/) { cbuf = cbuf (cbuf == "" ? "" : "\n") s; return }

  bucket = "env"; drop = 0; why = ""
  if (single && t ~ /^plugins=\(/) {
    gsub(/zsh-autosuggestions|zsh-syntax-highlighting/, "", s)
    gsub(/[ \t]+\)/, ")", s)
    flush_comments("env"); emit("env", s); return
  }
  if (single && t ~ /^(export[ \t]+)?(JAVA_HOME|ANDROID_HOME)=/) {
    v = t
    sub(/^(export[ \t]+)?(JAVA_HOME|ANDROID_HOME)=/, "", v)
    sub(/[ \t]+#.*$/, "", v)
    gsub(/["']/, "", v)
    if (v ~ /zulu-17\.jdk\/Contents\/Home\/?$/ || v ~ /\/Library\/Android\/sdk\/?$/) {
      if (cbuf != "") { logrm(cbuf, ""); cbuf = "" }
      logrm(s, "same value is set in the new Mobile / React Native section"); return
    }
    if (t in seen) { logrm(s, "duplicate"); return }
    seen[t] = 1
    flush_comments("env")
    emit("env", "# [tokyo-night-setup " today "] older value kept for reference; the Mobile / React Native section sets this now:\n# " t)
    logrm(s, "commented out (kept as a comment, not deleted)")
    return
  }
  if (is_managed(s)) { drop = 1; why = "now handled by the new setup" }
  else if (t ~ /^(export[ \t]+)?(HISTFILE|HISTSIZE|SAVEHIST)=/) { drop = 1; why = "history is set in the new History section" }
  else if (single && t ~ /^alias[ \t]/) {
    name = alias_name(t)
    if (name in mgd) { drop = 1; why = "replaced by the new alias" }
    else if (t in seen) { drop = 1; why = "duplicate" }
    else { seen[t] = 1; bucket = "alias" }
  }
  else if (single && dedupable(t)) {
    if (t in seen) { drop = 1; why = "duplicate" } else seen[t] = 1
  }

  if (drop) {
    if (cbuf != "") { logrm(cbuf, ""); cbuf = "" }
    logrm(s, why)
    return
  }
  flush_comments(bucket)
  emit(bucket, s)
}

BEGIN {
  n = split("ls ll la lt cat top .. ... gs gl gd gco reload rn rns rnsc rna rni podi podclean gradleclean adbr emus sims expo", names, " ")
  for (i = 1; i <= n; i++) mgd[names[i]] = 1
  q = 0; depth = 0; inunit = 0; u = ""; cbuf = ""; pendblank = 0
  printf "" > env_out; printf "" > alias_out; printf "" > rm_out
}

{
  line = $0
  sub(/\r$/, "", line)
  if (!inunit) {
    if (trim(line) == "") { flush_comments("env"); pendblank = 1; next }
    u = line; inunit = 1
  } else {
    u = u "\n" line
  }
  qb = q
  scan_quotes(line)
  t = trim(line)
  if (qb == 0 && t != "" && t !~ /^#/) depth_update(t)
  cont = (q == 0 && t !~ /^#/ && line ~ /\\$/)
  if (q == 0 && depth == 0 && !cont) { process_unit(u); inunit = 0; u = "" }
}

END {
  if (inunit) { flush_comments("env"); emit("env", u) }
  flush_comments("env")
}
AWK
}

split_zshrc() {
  : > "$WORK/env.part"; : > "$WORK/alias.part"; : > "$WORK/removed.log"
  [[ -f $HOME/.zshrc ]] || return 0
  write_split_awk
  awk -v today="$TODAY" -v env_out="$WORK/env.part" -v alias_out="$WORK/alias.part" -v rm_out="$WORK/removed.log" \
      -f "$WORK/split.awk" "$HOME/.zshrc" \
    || { warn "Could not parse ~/.zshrc; keeping it verbatim."; SPLIT_FALLBACK=1; }
}

assemble_zshrc() {
  local out="$WORK/zshrc"
  {
    cat <<EOF
# ==============================================================================
#  ~/.zshrc  ·  Tokyo Night developer setup  ·  generated $TODAY
#  Your previous file is saved as ~/.zshrc.backup-$TODAY (see ~/.tokyo-night-setup
#  for the undo script).  Sections: PATH · Mobile / React Native · Your env ·
#  Node · History · Completion · Tools · bat · Aliases · Prompt & plugins
# ==============================================================================

# Optional start-up profiler:  ZSH_PROFILE=1 zsh -i -c exit
if [[ -n \${ZSH_PROFILE-} ]]; then zmodload zsh/zprof; fi

# ── 1. PATH & Homebrew ────────────────────────────────────────────────────────
# Remove duplicate entries from PATH / FPATH automatically.
typeset -U path PATH fpath

# Homebrew environment (static copy of the 'brew shellenv' output: faster start)
if [[ -d $BREW_PREFIX ]]; then
  export HOMEBREW_PREFIX="$BREW_PREFIX"
  export HOMEBREW_CELLAR="$BREW_PREFIX/Cellar"
  export HOMEBREW_REPOSITORY="$BREW_REPO"
  fpath[1,0]="$BREW_PREFIX/share/zsh/site-functions"
  path=("$BREW_PREFIX/bin" "$BREW_PREFIX/sbin" \$path)
  [[ -z "\${MANPATH-}" ]] || export MANPATH=":\${MANPATH#:}"
  export INFOPATH="$BREW_PREFIX/share/info:\${INFOPATH:-}"
fi

EOF
    cat <<'EOF'
# ── 2. Mobile / React Native (Android + iOS) ─────────────────────────────────
# Placed BEFORE your own exports below, so older lines that use $JAVA_HOME or
# $ANDROID_HOME keep working. Older JAVA_HOME / ANDROID_HOME lines were kept as comments.
export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"   # JDK 17 (React Native recommended)
export ANDROID_HOME="$HOME/Library/Android/sdk"
path+=("$ANDROID_HOME/emulator" "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/cmdline-tools/latest/bin")
if [[ -d $JAVA_HOME/bin ]]; then path=("$JAVA_HOME/bin" $path); fi
# Homebrew Ruby (keg-only) first, so `bundle exec pod install` does not use macOS's old system Ruby
if [[ -d ${HOMEBREW_PREFIX:-/opt/homebrew}/opt/ruby/bin ]]; then
  path=("${HOMEBREW_PREFIX:-/opt/homebrew}/opt/ruby/bin" ${HOMEBREW_PREFIX:-/opt/homebrew}/lib/ruby/gems/*/bin(N) $path)
fi

EOF
    if [[ -s $WORK/env.part ]]; then
      cat <<'EOF'
# ── 3. Your environment (carried over from your previous ~/.zshrc) ───────────
# PATH entries, exports and tool set-up (Java, Android, Python, …) kept as-is;
# exact duplicates were removed.
EOF
      cat "$WORK/env.part"
      printf '\n'
    fi
    cat <<'EOF'
# ── 4. Node (nvm): detected automatically, loaded ONCE and only when needed ──
# The default Node version is put on PATH instantly; nvm itself is sourced the
# first time you run `nvm` (keeps shell start-up fast).
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
_nvm_sh=""
for _f in "$NVM_DIR/nvm.sh" "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/nvm/nvm.sh"; do
  if [[ -s $_f ]]; then _nvm_sh=$_f; break; fi
done
unset _f
if [[ -n $_nvm_sh ]]; then
  () {
    emulate -L zsh
    setopt null_glob numeric_glob_sort
    local ver=default dirs i
    # follow the nvm alias chain: default → lts/* → lts/<name> → v22.x.y
    for i in 1 2 3 4 5; do
      if [[ -r $NVM_DIR/alias/$ver ]]; then ver=$(<"$NVM_DIR/alias/$ver"); else break; fi
    done
    [[ $ver == default ]] && ver=""
    ver="v${ver#v}"
    dirs=( "$NVM_DIR"/versions/node/${ver}*(/on) )
    (( $#dirs )) || dirs=( "$NVM_DIR"/versions/node/v*(/on) )
    if (( $#dirs )); then
      path=( "${dirs[-1]}/bin" $path )
      typeset -g _nvm_default_added=1
    fi
  }
  _nvm_lazy() {
    unset -f nvm node npm npx 2>/dev/null
    if [[ -z ${_NVM_LOADED-} ]]; then
      _NVM_LOADED=1
      source "$_nvm_sh"
    fi
  }
  nvm() { _nvm_lazy; nvm "$@"; }
  if [[ -z ${_nvm_default_added-} ]]; then
    node() { _nvm_lazy; node "$@"; }
    npm()  { _nvm_lazy; npm "$@"; }
    npx()  { _nvm_lazy; npx "$@"; }
  fi
fi

# ── 5. History ────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE \
       HIST_REDUCE_BLANKS AUTO_CD INTERACTIVE_COMMENTS NO_BEEP

# ── 6. Completion ─────────────────────────────────────────────────────────────
if [[ -n ${HOMEBREW_PREFIX-} && -d $HOMEBREW_PREFIX/share/zsh/site-functions ]]; then
  FPATH="$HOMEBREW_PREFIX/share/zsh/site-functions:$FPATH"
fi
zmodload zsh/complist
autoload -Uz compinit
compinit -C
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive

# ── 7. Tools: zoxide · fzf ────────────────────────────────────────────────────
if command -v zoxide >/dev/null 2>&1; then eval "$(zoxide init zsh)"; fi

export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS=" \
  --height 40% --layout=reverse --border \
  --color=bg+:#283457,bg:#16161e,hl:#2ac3de,fg:#c0caf5,pointer:#ff007c,marker:#ff007c,prompt:#2ac3de,header:#ff9e64,info:#545c7e"
if command -v fzf >/dev/null 2>&1; then source <(fzf --zsh); fi

# ── 8. bat ────────────────────────────────────────────────────────────────────
export BAT_THEME="tokyonight_night"

# ── 9. Aliases ────────────────────────────────────────────────────────────────
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --git --group-directories-first'
alias la='eza -lah --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons --git-ignore'
alias cat='bat --paging=never'
alias top='btop'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias gco='git checkout'
alias reload='source ~/.zshrc'

# Mobile / React Native
alias rn='npx react-native'
alias rns='npx react-native start'
alias rnsc='npx react-native start --reset-cache'
alias rna='npx react-native run-android'
alias rni='npx react-native run-ios'
alias podi='cd ios && bundle exec pod install; cd ..'
alias podclean='cd ios && rm -rf Pods Podfile.lock build && bundle exec pod install --repo-update; cd ..'
alias gradleclean='cd android && ./gradlew clean; cd ..'
alias adbr='adb reverse tcp:8081 tcp:8081'
alias emus='emulator -list-avds'
alias sims='xcrun simctl list devices available'
alias expo='npx expo'

# emu            → start the first Android emulator in the background
# emu <name>     → start that emulator (see `emus` for the names)
emu() {
  if ! command -v emulator >/dev/null 2>&1; then
    echo "emulator not found — install the Android SDK (Android Studio → SDK Manager → Android Emulator)." >&2
    return 1
  fi
  local avd=${1:-$(emulator -list-avds 2>/dev/null | grep -Ev '^(INFO|WARNING|ERROR)[[:space:]]*\|' | head -n 1)}
  if [[ -z $avd ]]; then
    echo "No Android emulators yet — create one in Android Studio → Device Manager." >&2
    return 1
  fi
  echo "Starting emulator: $avd"
  emulator -avd "$avd" -no-snapshot-load &>/dev/null &!
}

EOF
    if [[ -s $WORK/alias.part ]]; then
      cat <<'EOF'
# Your other aliases (carried over)
EOF
      cat "$WORK/alias.part"
      printf '\n'
    fi
    cat <<'EOF'
# ── 10. Prompt & plugins — KEEP THIS LAST (order matters) ─────────────────────
if command -v starship >/dev/null 2>&1; then eval "$(starship init zsh)"; fi

_brew_pfx="${HOMEBREW_PREFIX:-/opt/homebrew}"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#565f89'
[[ -r $_brew_pfx/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source "$_brew_pfx/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
# zsh-syntax-highlighting must be sourced last
[[ -r $_brew_pfx/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
  && source "$_brew_pfx/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
unset _brew_pfx

if [[ -n ${ZSH_PROFILE-} ]]; then zprof; fi
EOF
  } > "$out"
}

build_zshrc() {
  split_zshrc
  assemble_zshrc
  if ! zsh -n "$WORK/zshrc" 2> "$WORK/zsh-n.err"; then
    warn "The reorganised ~/.zshrc failed a syntax check; keeping your original lines verbatim instead."
    SPLIT_FALLBACK=1
    if [[ -f $HOME/.zshrc ]]; then cp "$HOME/.zshrc" "$WORK/env.part"; else : > "$WORK/env.part"; fi
    : > "$WORK/alias.part"
    printf '  - (nothing removed: original kept verbatim — review for duplicates)\n' > "$WORK/removed.log"
    assemble_zshrc
  fi
}

# ----------------------------------------------------------------------------- brew
load_brew() {
  local p
  command -v brew >/dev/null 2>&1 && return 0
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x $p ]]; then eval "$("$p" shellenv)"; return 0; fi
  done
  return 1
}

git_ready() { xcode-select -p >/dev/null 2>&1 || [[ -x $BREW_PREFIX/bin/git ]]; }

detect_gitconfig() {
  local xdg="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
  if   [[ -e $HOME/.gitconfig ]]; then GIT_CFG="$HOME/.gitconfig"
  elif [[ -e $xdg ]];             then GIT_CFG="$xdg"
  else                                 GIT_CFG="$HOME/.gitconfig"; fi
}

# ----------------------------------------------------------------------------- plan
show_diff() {   # show_diff <label> <current> <new> <max-lines>
  local label=$1 cur=$2 new=$3 max=$4 total
  printf '\n%s── %s ──%s\n' "$B" "$label" "$N"
  if [[ -e $cur ]] && diff -q "$cur" "$new" >/dev/null 2>&1; then say "(identical — no change)"; return; fi
  [[ -e $cur ]] || cur=/dev/null
  diff -u --label "current: $label" --label "new: $label" "$cur" "$new" > "$WORK/diff.out" 2>&1
  total=$(wc -l < "$WORK/diff.out" | tr -d ' ')
  head -n "$max" "$WORK/diff.out"
  if (( total > max )); then
    say "… ($((total - max)) more lines — full preview in $PREVIEW_DIR)"
  fi
}

find_nvm_sh() {
  local d="${NVM_DIR:-$HOME/.nvm}" c
  for c in "$d/nvm.sh" "$BREW_PREFIX/opt/nvm/nvm.sh"; do
    if [[ -s $c ]]; then printf '%s' "$c"; return 0; fi
  done
  return 1
}

detect_project() {
  local d="${PROJECT_DIR:-$PWD}"
  if [[ -f $d/package.json ]] && grep -Eq '"(react-native|expo)"' "$d/package.json" 2>/dev/null; then
    PROJECT_DIR="$d"
  elif [[ -n $PROJECT_DIR ]]; then
    warn "--project $PROJECT_DIR does not look like a React Native / Expo project (no react-native or expo in package.json)."
    PROJECT_DIR=""
  fi
}

plan_mobile() {
  local rt
  printf '\n%sReact Native (Android + iOS)%s\n' "$B" "$N"
  if [[ -d /Applications/Xcode.app ]]; then
    say "  Xcode: found. Selected developer dir now: $(xcode-select -p 2>/dev/null || echo none)"
    say "         Will run (asks for your password, only if needed):"
    say "           xcode-select --install   (only if the Command Line Tools are missing)"
    say "           sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    say "           sudo xcodebuild -license accept"
    if xcode-select -p >/dev/null 2>&1; then
      rt="$(xcrun simctl list runtimes 2>/dev/null | grep 'SimRuntime.iOS' | grep -v unavailable)"
      if [[ -n $rt ]]; then say "         iOS Simulator runtime: present"; else say "         iOS Simulator runtime: NONE found (you'll get the exact install command)"; fi
    fi
  else
    say "  Xcode: NOT found in /Applications. It is never installed by this script — you'll get App Store instructions."
  fi
  if find_nvm_sh >/dev/null; then say "  Node: nvm found → nvm install --lts; nvm alias default 'lts/*'; corepack enable"
  else say "  Node: nvm NOT found → Node step skipped (you'll get the fix)"; fi
  say "  Homebrew adds: watchman, cocoapods, ruby, android-studio (cask), zulu@17 (cask — may ask for your password)"
  say "  ~/.zshrc: new 'Mobile / React Native' section (JAVA_HOME, ANDROID_HOME, PATH), 12 aliases, emu()"
  say "           an older JAVA_HOME / ANDROID_HOME line is kept as a comment, not deleted"
  say "  Android SDK: only CHECKED (you'll get exact commands for anything missing)"
  say "  Starship: + Ruby (#f7768e) and Kotlin/Java versions, only inside projects that use them; command_timeout = 800"
  if [[ -n $PROJECT_DIR ]]; then say "  Doctor: will run in $PROJECT_DIR from a new shell"
  else say "  Doctor: no React Native/Expo project here → skipped (re-run from the project folder or use --project DIR)"; fi
}

show_plan() {
  local f s key val cur b
  step "PLAN — nothing has been changed yet"

  mkdir -p "$PREVIEW_DIR"
  cp "$WORK/zshrc" "$PREVIEW_DIR/zshrc.new"
  cp "$WORK/starship.toml" "$PREVIEW_DIR/starship.toml.new"
  cp "$WORK/ghostty.config" "$PREVIEW_DIR/ghostty.config.new"
  say "Full previews of the new files: $PREVIEW_DIR"

  printf '\n%sHomebrew & packages%s\n' "$B" "$N"
  if load_brew; then say "  Homebrew: found ($(command -v brew))"; else say "  Homebrew: NOT installed → will be installed first"; fi
  local missing_f="" missing_c=""
  for f in "${FORMULAE[@]}"; do
    if command -v brew >/dev/null 2>&1 && brew list --formula "$f" >/dev/null 2>&1; then :; else missing_f="$missing_f $f"; fi
  done
  for f in "${CASKS[@]}"; do
    if command -v brew >/dev/null 2>&1 && brew list --cask "$f" >/dev/null 2>&1; then :; else missing_c="$missing_c $f"; fi
  done
  say "  Formulae to install:${missing_f:- (all already installed)}"
  say "  Casks to install:   ${missing_c:- (all already installed)}"
  say "  bat theme:          tokyonight_night  (+ bat cache --build)"

  plan_mobile
  printf '\n%sFiles that will be backed up, then replaced/created%s\n' "$B" "$N"
  detect_gitconfig
  for f in "$HOME/.zshrc" "$HOME/.config/ghostty/config" "$HOME/.config/starship.toml" "$GIT_CFG"; do
    if [[ -e $f || -L $f ]]; then b="$(next_backup_path "$f")"; printf '  %s\n      backup → %s\n' "$f" "$b"
    else printf '  %s\n      (new file — nothing to back up)\n' "$f"; fi
  done
  printf '  (bat theme file: new)\n'
  local elabel efile
  while IFS=$'\t' read -r elabel efile; do
    [[ -n $efile ]] || continue
    if [[ -e $efile ]]; then printf '  %s  (%s: terminal font only, other settings kept)\n      backup → %s\n' "$efile" "$elabel" "$(next_backup_path "$efile")"
    else printf '  %s  (%s: new file)\n' "$efile" "$elabel"; fi
  done < <(editor_settings_files)

  printf '\n%sgit config --global (name, email and credentials are NOT touched)%s\n' "$B" "$N"
  if git_ready; then
    for s in "core.pager|delta" "interactive.diffFilter|delta --color-only" "delta.navigate|true" \
             "delta.line-numbers|true" "delta.syntax-theme|tokyonight_night" "merge.conflictStyle|zdiff3"; do
      key=${s%%|*}; val=${s#*|}
      cur="$(git config --global --get "$key" 2>/dev/null || true)"
      printf '  %-26s %s → %s\n' "$key" "${cur:-(unset)}" "$val"
    done
  else
    say "  (Xcode Command Line Tools not installed yet — will be set after Homebrew installs them)"
  fi

  printf '\n%s~/.zshrc: lines removed or de-duplicated%s\n' "$B" "$N"
  if [[ -s $WORK/removed.log ]]; then cat "$WORK/removed.log"
  else say "  (nothing removed)"; fi
  if [[ -s $WORK/env.part ]]; then
    say "  Everything else from your old file is kept (section 2 of the new file)."
  fi

  # heads-ups
  if [[ -f $HOME/.zshrc ]]; then
    grep -q 'oh-my-zsh' "$HOME/.zshrc" 2>/dev/null && note "oh-my-zsh detected: kept as-is, but it slows start-up and may fight with the Starship prompt."
    grep -Eq 'p10k|powerlevel10k' "$HOME/.zshrc" 2>/dev/null && note "Powerlevel10k detected: Starship (loaded last) will replace its prompt."
    grep -q 'java_home' "$HOME/.zshrc" 2>/dev/null && note "'/usr/libexec/java_home' in your .zshrc costs ~100 ms per shell; consider hard-coding JAVA_HOME."
    grep -Eq 'conda initialize|pyenv init|rbenv init|sdkman-init' "$HOME/.zshrc" 2>/dev/null && note "Python/Ruby/SDK managers detected: kept, but they add to shell start-up time."
  fi
  if [[ -e "$HOME/Library/Application Support/com.mitchellh.ghostty/config" ]]; then
    note "Found a Ghostty config in ~/Library/Application Support/com.mitchellh.ghostty/ — it is loaded too and can override the XDG file."
  fi

  show_diff "~/.config/ghostty/config" "$HOME/.config/ghostty/config" "$WORK/ghostty.config" "$DIFF_MAX"
  show_diff "~/.config/starship.toml"  "$HOME/.config/starship.toml"  "$WORK/starship.toml"  "$DIFF_MAX"
  show_diff "~/.zshrc"                 "$HOME/.zshrc"                 "$WORK/zshrc"           "$DIFF_MAX"
}

# ----------------------------------------------------------------------------- apply steps
ensure_brew() {
  step "Homebrew"
  if load_brew; then ok "Homebrew found: $(command -v brew)"; return 0; fi
  say "Installing Homebrew (you may be asked for your password and to press RETURN)…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Homebrew installation failed."
  load_brew || die "Homebrew installed but 'brew' was not found in $BREW_PREFIX/bin."
  ok "Homebrew installed"
}

cask_present_path() {
  case "$1" in
    ghostty)        printf '%s' "/Applications/Ghostty.app" ;;
    android-studio) printf '%s' "/Applications/Android Studio.app" ;;
    zulu@17)        printf '%s' "/Library/Java/JavaVirtualMachines/zulu-17.jdk" ;;
    *)              printf '%s' "" ;;
  esac
}

install_packages() {
  local f p
  step "Installing apps and CLI tools"
  say "(Zulu 17 and Android Studio are large downloads; Zulu may ask for your password.)"
  export HOMEBREW_NO_ENV_HINTS=1
  for f in "${CASKS[@]}"; do
    p="$(cask_present_path "$f")"
    if brew list --cask "$f" >/dev/null 2>&1; then ok "$f already installed"
    elif [[ -n $p && -e $p ]]; then ok "$f already present ($p, installed outside Homebrew) — skipped"
    elif brew install --cask "$f"; then ok "installed $f"; INSTALLED_NOW="$INSTALLED_NOW --cask $f"
    else warn "brew install --cask $f failed"; fi
  done
  for f in "${FORMULAE[@]}"; do
    if brew list --formula "$f" >/dev/null 2>&1; then ok "$f already installed"
    elif brew install "$f"; then ok "installed $f"; INSTALLED_NOW="$INSTALLED_NOW $f"
    else warn "brew install $f failed"; fi
  done
}

install_bat_theme() {
  step "bat theme: tokyonight_night"
  command -v bat >/dev/null 2>&1 || { warn "bat not available — theme skipped"; return 0; }
  local dir theme tmp
  dir="$(bat --config-dir)/themes"
  theme="$dir/tokyonight_night.tmTheme"
  tmp="$WORK/tokyonight_night.tmTheme"
  if ! curl -fsSL "$THEME_URL" -o "$tmp" || ! grep -q '<plist' "$tmp"; then
    warn "Could not download the bat theme from $THEME_URL"; return 0
  fi
  mkdir -p "$dir"
  backup_file "$theme"
  cp "$tmp" "$theme" && ok "Installed $theme"
  bat cache --build >/dev/null 2>&1 && ok "bat cache rebuilt" || warn "'bat cache --build' failed"
}

configure_git() {
  step "git config --global"
  command -v git >/dev/null 2>&1 || { warn "git not found — git settings skipped"; return 0; }
  detect_gitconfig
  backup_file "$GIT_CFG"
  local ver major minor conflict="zdiff3"
  ver="$(git --version | sed -E 's/[^0-9]*([0-9]+)\.([0-9]+).*/\1 \2/')"
  major=${ver% *}; minor=${ver#* }
  if (( major < 2 || (major == 2 && minor < 35) )); then
    conflict="diff3"
    warn "git $major.$minor is older than 2.35 (no zdiff3) → using merge.conflictStyle=diff3. Run 'brew install git' to get zdiff3."
  fi
  git config --global core.pager delta
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  git config --global delta.syntax-theme tokyonight_night
  git config --global merge.conflictStyle "$conflict"
  ok "git configured (delta + $conflict)"
}

pick_terminal_font() {
  cat > "$WORK/font.js" <<'JS'
ObjC.import('AppKit');
function run(argv) {
  for (var i = 0; i < argv.length; i++) {
    try {
      var f = $.NSFont.fontWithNameSize(argv[i], 14);
      if (f && !f.isNil()) return ObjC.unwrap(f.fontName);
    } catch (e) {}
  }
  return '';
}
JS
  osascript -l JavaScript "$WORK/font.js" JetBrainsMonoNF-Regular JetBrainsMonoNerdFont-Regular \
            JetBrainsMonoNFM-Regular "JetBrainsMono Nerd Font" 2>/dev/null
}

hex16() { printf '%d' $((0x$1 * 257)); }   # 8-bit hex → 16-bit int (AppleScript colour)

setup_terminal_app() {
  step "Terminal.app profile “Tokyo Night”"
  mkdir -p "$STATE_DIR"
  TERMINAL_BACKUP="$(next_backup_path "$STATE_DIR/com.apple.Terminal.plist")"
  if defaults export com.apple.Terminal "$TERMINAL_BACKUP" 2>/dev/null; then
    ok "Exported current Terminal settings → $TERMINAL_BACKUP"
  else
    warn "Could not export Terminal settings — skipping the Terminal.app profile to stay safe."
    TERMINAL_BACKUP=""; return 0
  fi

  local font bg fg fontline
  font="$(pick_terminal_font)"
  bg="$(hex16 1a), $(hex16 1b), $(hex16 26)"      # #1a1b26
  fg="$(hex16 c0), $(hex16 ca), $(hex16 f5)"      # #c0caf5
  if [[ -n $font ]]; then fontline="set font name of s to \"$font\""
  else fontline=""; warn "JetBrainsMono Nerd Font not found by macOS yet — Terminal profile created without the font (log out/in or open Font Book once, then re-run)."; fi

  if osascript <<OSA 2>"$WORK/osa.err"
tell application "Terminal"
  if not (exists settings set "Tokyo Night") then
    make new settings set with properties {name:"Tokyo Night"}
  end if
  set s to settings set "Tokyo Night"
  set background color of s to {$bg}
  set normal text color of s to {$fg}
  set bold text color of s to {$fg}
  set cursor color of s to {$fg}
  $fontline
  set font size of s to 14
  set default settings to s
  set startup settings to s
end tell
OSA
  then
    ok "Terminal.app profile “Tokyo Night” created and set as default${font:+ (font: $font)}"
    note "Terminal.app can only set background/text/cursor colours via scripting — Ghostty is the full Tokyo Night experience."
  else
    warn "Terminal.app profile failed: $(tr '\n' ' ' < "$WORK/osa.err"). If macOS asked for Automation permission, allow it and re-run with --terminal-app."
  fi
}

# ----------------------------------------------------------------------------- editor terminals
editor_settings_files() {   # prints "<label>\t<settings.json>" for each installed editor
  local entry dir label
  for entry in "${EDITOR_APPS[@]}"; do
    dir=${entry%%|*}; label=${entry#*|}
    [[ -d "$HOME/Library/Application Support/$dir/User" ]] || continue
    printf '%s\t%s\n' "$label" "$HOME/Library/Application Support/$dir/User/settings.json"
  done
}

write_editor_font() {   # write_editor_font <settings.json>   (text edit: keeps comments and every other key)
  python3 - "$1" "$EDITOR_FONT" <<'PY'
import os, re, sys
path, font = sys.argv[1], sys.argv[2]
want = {
    "terminal.integrated.fontFamily": '"%s"' % font,
    "terminal.integrated.fontSize": "13",
    "terminal.integrated.lineHeight": "1.15",
}
text = open(path).read() if os.path.exists(path) else ""
if not text.strip():
    text = "{\n}\n"
missing = []
for key, value in want.items():
    pat = re.compile(r'("%s"\s*:\s*)("(?:[^"\\]|\\.)*"|[^,\n}]+)' % re.escape(key))
    if pat.search(text):
        text = pat.sub(lambda m: m.group(1) + value, text, count=1)
    else:
        missing.append('    "%s": %s' % (key, value))
if missing:
    end = text.rstrip().rfind("}")
    if end < 0:
        sys.exit("no closing brace")
    head = text[:end].rstrip()
    # The comma goes after the last value, never inside a trailing // or /* */ comment.
    last = head
    while True:
        trimmed = re.sub(r'(//[^\n]*|/\*.*?\*/)\s*$', '', last, flags=re.S).rstrip()
        if trimmed == last:
            break
        last = trimmed
    sep = "" if last.endswith("{") or last.endswith(",") else ","
    text = last + sep + head[len(last):] + "\n" + ",\n".join(missing) + "\n" + text[end:]
open(path, "w").write(text)
PY
}

setup_editor_terminals() {
  step "Editor terminals (icons need the Nerd Font there too)"
  local label file found=0
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'pass' >/dev/null 2>&1; then
    warn "python3 is not available, so editor settings were not changed. Set \"terminal.integrated.fontFamily\": \"$EDITOR_FONT\" by hand."
    return 0
  fi
  while IFS=$'\t' read -r label file; do
    [[ -n $file ]] || continue
    found=1
    backup_file "$file"
    if write_editor_font "$file" 2>"$WORK/editor.err"; then
      ok "$label: terminal font → $EDITOR_FONT (size 13, line height 1.15)"
    else
      warn "$label: could not update $file ($(tr '\n' ' ' < "$WORK/editor.err")). Restore from the backup above if needed."
    fi
  done < <(editor_settings_files)
  (( found )) || note "No VS Code, Cursor or Windsurf settings found; nothing to change."
  if ls -d /Applications/Android\ Studio.app /Applications/WebStorm.app /Applications/IntelliJ\ IDEA*.app >/dev/null 2>&1; then
    todo "JetBrains IDEs (Android Studio, WebStorm…): Settings → Editor → Color Scheme → Console Font → \"$EDITOR_FONT\""
  fi
  if ! ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi 'JetBrainsMonoNerdFont'; then
    warn "JetBrainsMono Nerd Font files not found in ~/Library/Fonts or /Library/Fonts; the icons will not show until it is installed."
  fi
  note "Open a new terminal tab in each editor (or restart it) to see the icons."
}

# ----------------------------------------------------------------------------- React Native
setup_xcode() {
  step "Xcode (iOS)"
  local xc=/Applications/Xcode.app dev=/Applications/Xcode.app/Contents/Developer cur rt
  if [[ ! -d $xc ]]; then
    todo "Xcode is not installed. Install it from the App Store (https://apps.apple.com/app/xcode/id497799835), open it once so it finishes its setup, then re-run this script. (This script never installs Xcode.)"
    return 0
  fi
  ok "Xcode found at $xc"

  if ! xcode-select -p >/dev/null 2>&1; then
    say "Command Line Tools are not selected → xcode-select --install (a macOS dialog will appear)"
    xcode-select --install 2>/dev/null || true
    todo "Finish the Command Line Tools dialog that macOS opened, then re-run this script."
  fi

  cur="$(xcode-select -p 2>/dev/null || true)"
  XCODE_PREV_PATH="$cur"
  if [[ $cur == "$dev" ]]; then ok "Xcode is already the selected developer directory"
  else
    say "Selecting full Xcode (sudo — enter your password if asked)…"
    if sudo xcode-select -s "$dev"; then ok "xcode-select → $dev"; XCODE_CHANGED=1
    else warn "'sudo xcode-select -s $dev' failed — run it yourself in a terminal."; fi
  fi

  if xcodebuild -license check >/dev/null 2>&1; then ok "Xcode license already accepted"
  else
    say "Accepting the Xcode license (sudo)…"
    if sudo xcodebuild -license accept; then ok "Xcode license accepted"
    else warn "'sudo xcodebuild -license accept' failed — run it yourself in a terminal."; fi
  fi

  if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    todo "Xcode's first-launch components are not installed. Fix: sudo xcodebuild -runFirstLaunch   (or just open Xcode once)"
  fi

  rt="$(xcrun simctl list runtimes 2>/dev/null | grep 'SimRuntime.iOS' | grep -v unavailable)"
  if [[ -n $rt ]]; then ok "iOS Simulator runtime found: $(printf '%s\n' "$rt" | head -n 1 | sed 's/ - com\..*//')"
  else
    todo "No iOS Simulator runtime is installed. Fix: xcodebuild -downloadPlatform iOS   (or Xcode → Settings → Components → iOS Simulator → Get)"
  fi
}

setup_node() {
  step "Node LTS (nvm) + corepack"
  local nvm_sh nvm_dir rc
  if nvm_sh="$(find_nvm_sh)"; then
    nvm_dir="${NVM_DIR:-$HOME/.nvm}"
    mkdir -p "$nvm_dir"
    (
      export NVM_DIR="$nvm_dir"; set +u
      . "$nvm_sh" || exit 1
      nvm install --lts || exit 1
      nvm alias default 'lts/*' || exit 1
      nvm use default >/dev/null || exit 1
      corepack enable || exit 3
    )
    rc=$?
    case $rc in
      0) ok "Node LTS installed with nvm (default = lts/*); corepack enabled for yarn / pnpm" ;;
      3) ok "Node LTS installed with nvm (default = lts/*)"
         warn "'corepack enable' failed. Fix: npm install -g corepack && corepack enable" ;;
      *) warn "nvm could not install Node LTS. Fix (in a new terminal): nvm install --lts && nvm alias default 'lts/*' && corepack enable" ;;
    esac
  else
    todo "nvm was not found, so Node LTS was not installed. Fix: brew install nvm && mkdir -p ~/.nvm  — then re-run this script."
    if command -v corepack >/dev/null 2>&1; then
      if corepack enable 2>/dev/null; then ok "corepack enabled (system Node)"; else warn "'corepack enable' failed on the system Node."; fi
    fi
  fi
}

check_android() {
  step "Android SDK"
  local sm="$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" emu="$ANDROID_SDK/emulator/emulator"
  local arch="x86_64" out miss="" pair pat id avds
  [[ "$(uname -m)" == "arm64" ]] && arch="arm64-v8a"

  if [[ ! -d "/Applications/Android Studio.app" ]]; then
    todo "Android Studio is not installed. Fix: brew install --cask android-studio"
    return 0
  fi
  if [[ ! -x $sm ]]; then
    todo "Android Studio has not set up the SDK yet. Open it once (Spotlight → Android Studio), finish the Setup Wizard, then in More Actions → SDK Manager install: SDK Platforms → Android SDK Platform 35; SDK Tools → Android SDK Build-Tools 35, Android SDK Command-line Tools (latest), Android Emulator, Android SDK Platform-Tools. Then Device Manager → Create Device → Pixel with a Google APIs system image. Re-run this script to re-check."
    return 0
  fi

  out="$(JAVA_HOME="$JDK17_HOME" "$sm" --list_installed 2>/dev/null)"
  for pair in 'platforms;android-35|platforms;android-35' 'build-tools;35\.|build-tools;35.0.0' \
              'cmdline-tools;latest|cmdline-tools;latest' 'emulator|emulator' 'platform-tools|platform-tools'; do
    pat=${pair%%|*}; id=${pair#*|}
    if grep -Eq "^[[:space:]]*${pat}([[:space:]]|$)" <<<"$out"; then ok "SDK package present: ${id%.0.0}"
    else miss="$miss \"$id\""; fi
  done
  if [[ -n $miss ]]; then
    todo "Missing Android SDK packages. Fix: sdkmanager$miss   (new terminal; then: yes | sdkmanager --licenses)"
  fi

  if [[ -x $emu ]]; then
    avds="$("$emu" -list-avds 2>/dev/null | grep -Ev '^(INFO|WARNING|ERROR)[[:space:]]*\|')"
    if [[ -n $avds ]]; then ok "Android emulator(s): $(printf '%s' "$avds" | tr '\n' ' ')"
    else
      todo "No Android emulator exists yet. Fix (Android Studio → Device Manager → Create Device → Pixel + Google APIs image), or: sdkmanager \"system-images;android-35;google_apis;$arch\" && avdmanager create avd -n Pixel_API_35 -k \"system-images;android-35;google_apis;$arch\" -d pixel"
    fi
  fi
}

fix_for() {   # fix_for "<name of the failing check>"
  local n; n="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$n" in
    node*)                  printf '%s' "nvm install --lts && nvm alias default 'lts/*'   (new terminal)" ;;
    npm*)                   printf '%s' "nvm install --lts   (npm ships with Node)" ;;
    yarn*)                  printf '%s' "corepack enable   (or: npm install -g yarn)" ;;
    watchman*)              printf '%s' "brew install watchman" ;;
    adb*)                   printf '%s' "sdkmanager \"platform-tools\"   (then open a new terminal so PATH is refreshed)" ;;
    jdk*)                   printf '%s' "brew install --cask zulu@17, then open a new terminal (JAVA_HOME is set in ~/.zshrc)" ;;
    "android studio"*)      printf '%s' "brew install --cask android-studio, open it once and finish the Setup Wizard" ;;
    android_home*|"android sdk"*) printf '%s' "open Android Studio once, then: sdkmanager \"platforms;android-35\" \"build-tools;35.0.0\"; ANDROID_HOME is set in ~/.zshrc (new terminal)" ;;
    gradlew*)               printf '%s' "cd android && chmod +x gradlew && ./gradlew --version" ;;
    ruby*)                  printf '%s' "brew install ruby, then open a new terminal (the Homebrew Ruby path is in ~/.zshrc)" ;;
    cocoapods*)             printf '%s' "cd <project> && bundle install   (or: brew install cocoapods)" ;;
    xcode*)                 printf '%s' "install Xcode from the App Store, then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -license accept" ;;
    ios-deploy*)            printf '%s' "brew install ios-deploy   (only needed for physical iPhones)" ;;
    *)                      printf '%s' "see the doctor message above" ;;
  esac
}

run_doctor() {
  step "React Native / Expo doctor (from a new shell)"
  local proj="$PROJECT_DIR" cmd out clean l mark rest name found=0
  if [[ -z $proj ]]; then
    todo "No React Native/Expo project to check. Run the doctor yourself in the project folder: npx react-native doctor   (Expo: npx expo-doctor)   — or re-run this script with --project /path/to/app"
    return 0
  fi
  if grep -q '"expo"' "$proj/package.json" 2>/dev/null; then cmd="npx --yes expo-doctor"
  else
    cmd="npx react-native doctor"
    if [[ ! -d $proj/node_modules/react-native ]]; then
      todo "Dependencies are not installed in $proj. Fix: cd \"$proj\" && npm install   (or yarn / pnpm install), then run: npx react-native doctor"
      return 0
    fi
  fi
  say "Running in $proj:  $cmd   (can take a minute)"
  out="$(cd "$proj" && perl -e 'alarm 300; exec @ARGV' -- zsh -i -c "$cmd" </dev/null 2>&1)"
  clean="$(printf '%s' "$out" | tr -d '\r' | sed $'s/\x1b\\[[0-9;?]*[A-Za-z]//g')"
  printf '%s\n' "$clean" | tail -n 70 | sed 's/^/    /'

  if [[ $cmd == *expo-doctor* ]]; then
    if grep -Eq '✖|issues? detected|failed' <<<"$clean"; then
      todo "expo-doctor found problems. Usual fix: cd \"$proj\" && npx expo install --fix   (aligns package versions with your Expo SDK), then run: npx expo-doctor"
    else ok "expo-doctor found no problems"; fi
    return 0
  fi

  printf '\n%sStill missing (with the exact fix):%s\n' "$B" "$N"
  while IFS= read -r l; do
    l="${l#"${l%%[![:space:]]*}"}"
    case "$l" in
      "✖"*) mark="✖"; rest="${l#✖}" ;;
      "●"*) mark="●"; rest="${l#●}" ;;
      *) continue ;;
    esac
    rest="${rest# }"; name="${rest%% - *}"
    printf '  %s %s\n      fix: %s\n' "$mark" "$name" "$(fix_for "$name")"
    found=1
  done <<<"$clean"
  if (( found )); then
    printf '%s\n' "react-native doctor reported issues (see the fixes above)" >> "$WORK/todo.log"
  else
    ok "react-native doctor reported nothing missing"
  fi
}

# ----------------------------------------------------------------------------- verification
median_startup() {
  local i t
  : > "$WORK/times.txt"
  for i in 1 2 3 4 5; do
    t="$(perl -MTime::HiRes=time -e '$t = time; system(@ARGV); printf "%.3f\n", time - $t;' -- zsh -i -c exit </dev/null 2>/dev/null)"
    printf '%s\n' "$t" >> "$WORK/times.txt"
  done
  sort -n "$WORK/times.txt" | sed -n 3p
}

verify() {
  step "Verification"
  local err t out

  if zsh -n "$HOME/.zshrc" 2>"$WORK/zsh-n.err"; then ok "~/.zshrc syntax OK"
  else warn "~/.zshrc syntax error: $(cat "$WORK/zsh-n.err")"; fi

  # first run builds the completion cache; not timed
  zsh -i -c exit </dev/null >/dev/null 2>&1
  err="$(zsh -i -c exit 2>&1 >/dev/null </dev/null)"
  if [[ -z $err ]]; then ok "A new zsh starts with no errors or warnings"
  else warn "zsh printed messages on start-up:"; printf '%s\n' "$err" | sed 's/^/      /' >&2; fi

  t="$(median_startup)"
  if [[ -n $t ]] && awk -v t="$t" 'BEGIN { exit !(t < 0.3) }'; then
    ok "zsh start-up: ${t}s (median of 5) — under 0.3 s"
  else
    warn "zsh start-up: ${t:-?}s (median of 5) — NOT under 0.3 s. Find the slow part with:  ZSH_PROFILE=1 zsh -i -c exit"
  fi

  out="$(zsh -i -c 'print -r -- $JAVA_HOME' </dev/null 2>/dev/null)"
  if [[ -d $out/bin ]]; then ok "JAVA_HOME in a new shell: $out"
  else warn "JAVA_HOME ($out) does not exist yet — Zulu 17 may not be installed (brew install --cask zulu@17)."; fi

  if command -v starship >/dev/null 2>&1; then
    out="$(starship prompt 2>&1 >/dev/null)"
    if [[ -z $out ]]; then ok "starship.toml parsed cleanly"; else warn "starship reported: $out"; fi
  fi

  if [[ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]]; then
    if /Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config >"$WORK/ghostty.val" 2>&1; then ok "Ghostty config is valid"
    else warn "Ghostty config check: $(tr '\n' ' ' < "$WORK/ghostty.val")"; fi
  fi

  if command -v bat >/dev/null 2>&1; then
    out="$(bat --list-themes --color=never 2>/dev/null)"
    if grep -qx 'tokyonight_night' <<<"$out"; then ok "bat theme tokyonight_night is available"
    else warn "bat theme tokyonight_night not found in bat's cache"; fi
  fi

  if command -v git >/dev/null 2>&1 && [[ $(git config --global --get core.pager 2>/dev/null) == delta ]]; then
    ok "git pager is delta"
  fi
}

# ----------------------------------------------------------------------------- undo + report
write_undo_script() {
  {
    printf '#!/usr/bin/env bash\n'
    printf '# Undo for the Tokyo Night setup run %s\n' "$STAMP"
    printf '# Restores every file to its backed-up version (or removes files that were newly created).\n'
    printf 'set -u\n'
    local target backup
    while IFS=$'\t' read -r target backup; do
      [[ -n $target ]] || continue
      if [[ -n $backup ]]; then
        printf 'cp -p %q %q && echo "restored: "%q\n' "$backup" "$target" "$target"
      else
        printf 'rm -f %q && echo "removed (was new): "%q\n' "$target" "$target"
      fi
    done < "$MANIFEST"
    if [[ -n $TERMINAL_BACKUP ]]; then
      printf '# Terminal.app settings — QUIT Terminal.app first, then run:\n'
      printf 'defaults import com.apple.Terminal %q && echo "restored: Terminal.app settings"\n' "$TERMINAL_BACKUP"
    fi
    if (( XCODE_CHANGED )); then
      printf '# Xcode: the developer directory was changed. To restore the previous one:\n'
      printf '# sudo xcode-select -s %q\n' "$XCODE_PREV_PATH"
    fi
    printf '# Node / corepack (optional): corepack disable ; Node versions installed with nvm stay (nvm ls / nvm uninstall <ver>)\n'
    printf 'command -v bat >/dev/null 2>&1 && bat cache --build >/dev/null 2>&1\n'
    printf 'rm -f "$HOME"/.zcompdump*   # completion cache; regenerated automatically\n'
    printf 'echo "Done. Open a new terminal window."\n'
    if [[ -n $INSTALLED_NOW ]]; then
      printf '\n# Optional: remove what this run installed with Homebrew (not done automatically):\n'
      printf '# brew uninstall%s\n' "$INSTALLED_NOW"
    fi
  } > "$UNDO_SCRIPT"
  chmod +x "$UNDO_SCRIPT"
}

report() {
  local target backup
  step "Summary"
  printf '%sFiles changed (and their backups):%s\n' "$B" "$N"
  while IFS=$'\t' read -r target backup; do
    [[ -n $target ]] || continue
    if [[ -n $backup ]]; then printf '  %s\n      backup: %s\n' "$target" "$backup"
    else printf '  %s\n      (new file — no earlier version existed)\n' "$target"; fi
  done < "$MANIFEST"
  if [[ -n $TERMINAL_BACKUP ]]; then
    printf '  Terminal.app preferences\n      backup: %s\n' "$TERMINAL_BACKUP"
  fi
  printf '  ~/.zcompdump*  (completion cache — deleted so it is rebuilt)\n'

  write_undo_script
  printf '\n%sHow to undo:%s\n' "$B" "$N"
  printf '  bash %s\n' "$UNDO_SCRIPT"
  printf '  (restores every backup above; for Terminal.app quit it first. Homebrew packages are left\n'
  printf '   installed — the undo script lists the optional brew uninstall command.)\n'
  printf '  Manual alternative, e.g.:  cp -p ~/.zshrc.backup-%s ~/.zshrc\n' "$TODAY"

  if [[ -s $WORK/todo.log ]]; then
    printf '\n%sManual steps still needed:%s\n' "$Y" "$N"
    sed 's/^/  → /' "$WORK/todo.log"
  fi
  if [[ -s $WORK/warnings.log ]]; then
    printf '\n%sThings to look at:%s\n' "$Y" "$N"
    sed 's/^/  ! /' "$WORK/warnings.log"
  fi

  printf '\n%s✨ All done — now open Ghostty (Spotlight → “Ghostty”) to see your Tokyo Night terminal.%s\n' "$B$G" "$N"
  printf '   In the current window, run:  exec zsh   (or just open a new tab)\n'
}

# ----------------------------------------------------------------------------- main
main() {
  parse_args "$@"

  [[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS only."
  [[ $EUID -ne 0 ]] || die "Do not run this with sudo — run it as your normal user."
  command -v curl >/dev/null 2>&1 || die "curl is required."
  command -v zsh  >/dev/null 2>&1 || die "zsh is required."

  if [[ "$(uname -m)" == "arm64" ]]; then BREW_PREFIX=/opt/homebrew; BREW_REPO=/opt/homebrew
  else BREW_PREFIX=/usr/local; BREW_REPO=/usr/local/Homebrew; fi

  WORK="$(mktemp -d "${TMPDIR:-/tmp}/tokyo-night.XXXXXX")" || die "Cannot create a temp directory."
  trap 'rm -rf "$WORK"' EXIT
  : > "$WORK/warnings.log"; : > "$WORK/todo.log"

  step "Preparing (no changes yet)"
  gen_ghostty  > "$WORK/ghostty.config"
  gen_starship > "$WORK/starship.toml"
  build_zshrc
  ok "Generated new Ghostty, Starship and zsh configs"

  detect_project
  show_plan

  if (( DRY_RUN )); then
    printf '\n%sDry run — nothing was changed.%s Re-run without --dry-run to apply.\n' "$B" "$N"
    exit 0
  fi

  printf '\n'
  confirm "Apply these changes? Every file is backed up first. [y/N]" n || die "Aborted — nothing was changed."

  case "$TERMINAL_APP" in
    ask) if confirm "Also create a “Tokyo Night” profile for the built-in Terminal.app and make it the default? [y/N]" n; then TERMINAL_APP=yes; else TERMINAL_APP=no; fi ;;
  esac

  mkdir -p "$STATE_DIR"; : > "$MANIFEST"

  ensure_brew
  install_packages
  setup_xcode

  step "Writing config files (backups first)"
  install_file "$WORK/ghostty.config" "$HOME/.config/ghostty/config"
  install_file "$WORK/starship.toml"  "$HOME/.config/starship.toml"
  install_file "$WORK/zshrc"          "$HOME/.zshrc"
  rm -f "$HOME"/.zcompdump* 2>/dev/null

  install_bat_theme
  configure_git
  [[ $TERMINAL_APP == yes ]] && setup_terminal_app
  setup_editor_terminals

  setup_node
  check_android
  verify
  run_doctor
  report
}

# Run only when executed (not when sourced for testing)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
