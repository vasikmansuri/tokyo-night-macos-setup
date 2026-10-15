#!/usr/bin/env bash
# Safe test suite for tokyo-night-setup.sh.
#
# Every test runs against a throwaway HOME in a temp directory. Nothing is
# installed and your real dotfiles are never read or written.
#
#   bash tests/run-tests.sh
#
# Tests that need macOS (the dry run) are skipped on other systems.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/tokyo-night-setup.sh"
PASS=0 FAIL=0 SKIP=0
LAST_LOG=""

pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; if [[ -n ${2-} ]]; then printf '        %s\n' "$2"; fi; }
skip() { SKIP=$((SKIP + 1)); printf '  skip  %s (%s)\n' "$1" "$2"; }

# Run a snippet in a fresh bash with the script's functions loaded and HOME
# pointing at a new temp directory. The snippet sees $SANDBOX and $WORK.
in_sandbox() {
  local sandbox rc
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/tn-test.XXXXXX")"
  # shellcheck disable=SC2016  # the snippet is expanded by the inner bash
  HOME="$sandbox" SANDBOX="$sandbox" SCRIPT="$SCRIPT" bash -c '
    set -uo pipefail
    source "$SCRIPT"
    BREW_PREFIX=/opt/homebrew BREW_REPO=/opt/homebrew
    WORK="$(mktemp -d "${TMPDIR:-/tmp}/tn-work.XXXXXX")"
    : > "$WORK/warnings.log"; : > "$WORK/todo.log"
    mkdir -p "$STATE_DIR"; : > "$MANIFEST"
    '"$1"'
  ' >"$sandbox.log" 2>&1
  rc=$?
  LAST_LOG="$sandbox.log"
  rm -rf "$sandbox"
  return $rc
}

echo "Static checks"
if bash -n "$SCRIPT"; then pass "bash -n tokyo-night-setup.sh"; else fail "bash -n tokyo-night-setup.sh"; fi
if command -v shellcheck >/dev/null 2>&1; then
  if (cd "$ROOT" && shellcheck tokyo-night-setup.sh tests/run-tests.sh); then pass "shellcheck"
  else fail "shellcheck (see output above)"; fi
else
  skip "shellcheck" "not installed: brew install shellcheck"
fi

echo "Command-line options"
if out="$("$SCRIPT" --help 2>&1)" && grep -q -- '--dry-run' <<<"$out"; then pass "--help prints usage and exits 0"
else fail "--help prints usage and exits 0"; fi
if ! "$SCRIPT" --no-such-flag >/dev/null 2>&1; then pass "unknown option is rejected"
else fail "unknown option is rejected"; fi
if ! "$SCRIPT" --project >/dev/null 2>&1; then pass "--project without a folder is rejected"
else fail "--project without a folder is rejected"; fi

# shellcheck disable=SC2016  # every snippet below is expanded inside the sandbox
{
echo "Backups"
if in_sandbox '
  f="$SANDBOX/cfg"; touch "$f" "$f.backup-$TODAY"
  [[ $(next_backup_path "$f") == "$f.backup-$TODAY-2" ]]'; then
  pass "an existing backup is never overwritten (-2 suffix)"
else fail "an existing backup is never overwritten (-2 suffix)" "$(cat "$LAST_LOG")"; fi

if in_sandbox '
  f="$SANDBOX/cfg"; echo old > "$f"; echo new > "$WORK/src"
  install_file "$WORK/src" "$f"
  [[ $(cat "$f") == new && $(cat "$f.backup-$TODAY") == old ]] && grep -q "^$f	$f.backup-$TODAY\$" "$MANIFEST"'; then
  pass "install_file backs up, writes, and records the change"
else fail "install_file backs up, writes, and records the change" "$(cat "$LAST_LOG")"; fi

if in_sandbox '
  mkdir -p "$SANDBOX/dotfiles"; echo old > "$SANDBOX/dotfiles/zshrc"
  ln -s "$SANDBOX/dotfiles/zshrc" "$SANDBOX/.zshrc"; echo new > "$WORK/src"
  install_file "$WORK/src" "$SANDBOX/.zshrc"
  [[ -L $SANDBOX/.zshrc && $(cat "$SANDBOX/dotfiles/zshrc") == new && $(cat "$SANDBOX/.zshrc.backup-$TODAY") == old ]]'; then
  pass "a symlinked file keeps its link; content is written through it"
else fail "a symlinked file keeps its link; content is written through it" "$(cat "$LAST_LOG")"; fi

if in_sandbox '
  d="$SANDBOX/Application Support/Code/User"; mkdir -p "$d"; echo "{}" > "$d/settings.json"; echo new > "$WORK/src"
  install_file "$WORK/src" "$d/settings.json"
  [[ $(cat "$d/settings.json.backup-$TODAY") == "{}" ]]'; then
  pass "paths with spaces are handled"
else fail "paths with spaces are handled" "$(cat "$LAST_LOG")"; fi

echo "Undo"
if in_sandbox '
  echo old > "$SANDBOX/a"; echo new > "$WORK/src"
  install_file "$WORK/src" "$SANDBOX/a"
  install_file "$WORK/src" "$SANDBOX/created"
  write_undo_script
  bash "$UNDO_SCRIPT" >/dev/null
  [[ $(cat "$SANDBOX/a") == old && ! -e $SANDBOX/created ]]'; then
  pass "undo restores changed files and removes created ones"
else fail "undo restores changed files and removes created ones" "$(cat "$LAST_LOG")"; fi

if in_sandbox '
  echo old > "$SANDBOX/a"; echo new > "$WORK/src"
  ( trap on_exit EXIT; install_file "$WORK/src" "$SANDBOX/a"; die "simulated failure" ) || true
  [[ -x $UNDO_SCRIPT ]] && bash "$UNDO_SCRIPT" >/dev/null && [[ $(cat "$SANDBOX/a") == old ]]'; then
  pass "a run that stops early still leaves a working undo script"
else fail "a run that stops early still leaves a working undo script" "$(cat "$LAST_LOG")"; fi

echo "~/.zshrc merge"
if in_sandbox '
  cat > "$SANDBOX/.zshrc" <<"EOF"
# my settings
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/bin:$PATH"
alias k=kubectl
alias ll="ls -l"
eval "$(starship init zsh)"
if [[ -f ~/.secrets ]]; then
  source ~/.secrets
fi
EOF
  build_zshrc
  z="$WORK/zshrc"
  [[ $(grep -c "^export PATH=\"\$HOME/bin:\$PATH\"" "$z") == 1 ]] || { echo "duplicate PATH line not removed"; exit 1; }
  grep -q "^alias k=kubectl" "$z" || { echo "user alias lost"; exit 1; }
  grep -q "source ~/.secrets" "$z" || { echo "user if-block lost"; exit 1; }
  ! grep -q "^alias ll=\"ls -l\"" "$z" || { echo "managed alias not replaced"; exit 1; }
  [[ $(grep -c "starship init zsh" "$z") == 1 ]] || { echo "starship init not de-duplicated"; exit 1; }
  if command -v zsh >/dev/null 2>&1; then zsh -n "$z"; fi'; then
  pass "user lines kept, duplicates and managed lines removed, result passes zsh -n"
else fail "user lines kept, duplicates and managed lines removed, result passes zsh -n" "$(cat "$LAST_LOG")"; fi
}

echo "Dry run"
if [[ $(uname -s) != Darwin ]]; then
  skip "dry run changes no config files" "needs macOS"
else
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/tn-dry.XXXXXX")"
  printf 'alias k=kubectl\n' > "$sandbox/.zshrc"
  before="$(cat "$sandbox/.zshrc")"
  if HOME="$sandbox" "$SCRIPT" --dry-run >"$sandbox.log" 2>&1 \
     && [[ $(cat "$sandbox/.zshrc") == "$before" ]] \
     && [[ ! -e $sandbox/.config/ghostty/config && ! -e $sandbox/.config/starship.toml && ! -e $sandbox/.gitconfig ]] \
     && [[ -z $(find "$sandbox/.tokyo-night-setup" -type f ! -path '*/preview-*' 2>/dev/null) ]] \
     && [[ ! -e $sandbox/.zshrc.backup-$(date +%Y-%m-%d) ]] \
     && grep -q 'Dry run — nothing was changed' "$sandbox.log"; then
    pass "dry run changes no config files (only writes previews to ~/.tokyo-night-setup/preview-*)"
    rm -f "$sandbox.log"
  else
    fail "dry run changes no config files" "log: $sandbox.log"
  fi
  rm -rf "$sandbox"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
(( FAIL == 0 ))
