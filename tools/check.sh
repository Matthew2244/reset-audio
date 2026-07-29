#!/bin/bash
#
# tools/check.sh — everything CI runs, and everything you should run before
# opening a pull request. Takes about a second and changes nothing.
#
# What it deliberately does not do is reset Core Audio. There is no way to
# test that without stopping the audio daemon on the machine running the test,
# which on your Mac interrupts whatever you are listening to and on a CI
# runner proves very little. The behaviour that can be checked without side
# effects is checked here; the rest is in CONTRIBUTING.md as a by-hand list.
#
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$name"; else fail "$name"; fi
}

echo "reset-audio checks"
echo

# --- it is valid Python, on the oldest interpreter we claim to support -----
check "reset-audio compiles"          python3 -m py_compile reset-audio

# --- the read-only entry points work and change nothing -------------------
check "--version"                     python3 reset-audio --version
check "--help"                        python3 reset-audio --help
check "--install-help"                python3 reset-audio --install-help
check "--dry-run --quiet"             python3 reset-audio --dry-run --quiet

# --status exits 1 when Core Audio is not running, which is a legitimate
# answer and not a failure of the check. Accept 0 or 1; anything else is a
# crash. (GitHub's macOS runners are headless and do run coreaudiod, but that
# is not something to depend on.)
python3 reset-audio --status --quiet >/dev/null 2>&1
rc=$?
if [ $rc -le 1 ]; then ok "--status"; else fail "--status (exit $rc)"; fi

# --- the dry run must not have touched anything ---------------------------
before=$(pgrep -x coreaudiod | head -1)
python3 reset-audio --dry-run --quiet >/dev/null 2>&1
after=$(pgrep -x coreaudiod | head -1)
if [ "$before" = "$after" ]; then ok "--dry-run leaves coreaudiod alone"
else fail "--dry-run changed the coreaudiod PID ($before -> $after)"; fi

# --- the shell scripts parse ----------------------------------------------
for f in install.sh uninstall.sh tools/check.sh; do
    check "$f parses" bash -n "$f"
done

# --- the install is reversible, in a throwaway prefix ---------------------
# Runs the real installer against a temporary directory, so a change that
# breaks installation is caught here rather than by the first person to clone.
tmp="$(mktemp -d)"
if ./install.sh --prefix "$tmp" --app-dir "$tmp/Applications" >/dev/null 2>&1; then
    [ -L "$tmp/bin/reset-audio" ] && ok "install.sh links the command" \
        || fail "install.sh did not link the command"
    [ -d "$tmp/Applications/Reset Audio.app" ] && ok "install.sh builds the app" \
        || fail "install.sh did not build the app"
    check "the built app is signed" codesign --verify --deep "$tmp/Applications/Reset Audio.app"

    ./uninstall.sh --prefix "$tmp" --app-dir "$tmp/Applications" >/dev/null 2>&1
    [ ! -e "$tmp/bin/reset-audio" ] && [ ! -d "$tmp/Applications/Reset Audio.app" ] \
        && ok "uninstall.sh removes both" || fail "uninstall.sh left something behind"
else
    fail "install.sh failed against a temporary prefix"
fi
rm -rf "$tmp"

echo
if [ "$fails" = "0" ]; then echo "All checks passed."; exit 0
else echo "$fails check(s) failed."; exit 1; fi
