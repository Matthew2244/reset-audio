#!/bin/bash
#
# tools/check.sh — everything CI runs, and everything you should run before
# opening a pull request. Takes a couple of seconds and changes nothing.
#
# What it deliberately does not do is reset Core Audio. There is no way to test
# that end to end without stopping the audio daemon on the machine running the
# test, which on your Mac interrupts whatever you are listening to and on a CI
# runner proves very little.
#
# So instead it sources reset-audio and tests the logic directly. Sourcing the
# script defines its functions and runs nothing, which means everything except
# the two functions that actually take root — try_passwordless and
# try_auth_dialog — is exercised here. Those two are in CONTRIBUTING.md as a
# by-hand list.
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

# Compare two strings, showing both when they differ — a failing assertion
# that does not say what it got is a failing assertion you have to debug twice.
eq() {
    local name="$1" want="$2" got="$3"
    if [ "$want" = "$got" ]; then ok "$name"
    else fail "$name"; printf '        want [%s]\n        got  [%s]\n' "$want" "$got"; fi
}

# Assert an exit status.
rc_is() {
    local name="$1" want="$2"; shift 2
    "$@" >/dev/null 2>&1
    local got=$?
    if [ "$got" = "$want" ]; then ok "$name"
    else fail "$name (wanted exit $want, got $got)"; fi
}

echo "reset-audio checks"
echo

# --- the shell scripts parse ------------------------------------------------
for f in reset-audio install.sh uninstall.sh tools/check.sh; do
    check "$f parses" bash -n "$f"
done

# --- the entry points that change nothing -----------------------------------
rc_is "--version"            0 ./reset-audio --version
rc_is "--help"               0 ./reset-audio --help
rc_is "--install-help"       0 ./reset-audio --install-help
rc_is "--dry-run --quiet"    0 ./reset-audio --dry-run --quiet

# --status exits 1 when Core Audio is not running, which is a legitimate answer
# and not a failure of the check. Accept 0 or 1; anything else is a crash.
./reset-audio --status --quiet >/dev/null 2>&1
rc=$?
if [ $rc -le 1 ]; then ok "--status"; else fail "--status (exit $rc)"; fi

# --- bad input is rejected, and with argparse's exit code --------------------
rc_is "unknown option exits 2"    2 ./reset-audio --bogus
rc_is "--timeout abc exits 2"     2 ./reset-audio --timeout abc
rc_is "--timeout=1.2.3 exits 2"   2 ./reset-audio --timeout=1.2.3
rc_is "bare --timeout exits 2"    2 ./reset-audio --timeout
rc_is "--timeout=0.5 accepted"    0 ./reset-audio --timeout=0.5 --dry-run --quiet
rc_is "--timeout 30 accepted"     0 ./reset-audio --timeout 30 --dry-run --quiet

# --- the dry run must not have touched anything -----------------------------
before=$(pgrep -x coreaudiod | sort -n | head -1)
./reset-audio --dry-run --quiet >/dev/null 2>&1
after=$(pgrep -x coreaudiod | sort -n | head -1)
eq "--dry-run leaves coreaudiod alone" "$before" "$after"

# ---------------------------------------------------------------------------
# the logic, sourced
# ---------------------------------------------------------------------------
echo
echo "  internals"

# shellcheck source=../reset-audio
source ./reset-audio
QUIET=1

eq "coreaudiod_pid agrees with pgrep" \
   "$(pgrep -x coreaudiod | sort -n | head -1)" "$(coreaudiod_pid)"

# A PID that cannot match means any running coreaudiod counts as "new", so
# this returns at once. If it ever blocks, the poll loop is broken.
got=$(wait_for_respawn 999999 5); rc=$?
if [ "$rc" = "0" ] && [ -n "$got" ]; then ok "wait_for_respawn finds a new PID"
elif [ -z "$(coreaudiod_pid)" ]; then ok "wait_for_respawn (skipped, no coreaudiod)"
else fail "wait_for_respawn did not find a new PID (exit $rc)"; fi

# The opposite: asking it to wait for something other than the PID that is
# already there must time out rather than claim success. This is the check
# that keeps "killed it" from being reported as "it came back".
cur=$(coreaudiod_pid)
if [ -n "$cur" ]; then
    got=$(wait_for_respawn "$cur" 0.5); rc=$?
    if [ "$rc" != "0" ] && [ -z "$got" ]; then ok "wait_for_respawn times out honestly"
    else fail "wait_for_respawn claimed a respawn that did not happen"; fi
else
    ok "wait_for_respawn timeout (skipped, no coreaudiod)"
fi

# The spoken sentence, at every count. These are the strings a screen reader
# reads out, so the grammar is part of the contract, not a nicety.
audio_apps_running() { printf ''; }
eq "sentence, no apps"    "" "$(audio_apps_sentence)"
audio_apps_running() { printf 'REAPER\n'; }
eq "sentence, one app"    " REAPER is open, so check its audio device." "$(audio_apps_sentence)"
audio_apps_running() { printf 'REAPER\nLogic Pro\n'; }
eq "sentence, two apps"   " REAPER and Logic Pro are open, so check their audio devices." "$(audio_apps_sentence)"
audio_apps_running() { printf 'REAPER\nLogic Pro\nOBS\n'; }
eq "sentence, three apps" " REAPER, Logic Pro and OBS are open, so check their audio devices." "$(audio_apps_sentence)"
unset -f audio_apps_running
source ./reset-audio

# Quoting: a message with a double quote in it must survive intact. Getting
# this wrong is silent — the announcement just says the wrong thing.
eq "announce survives a double quote" \
   'he said "hello" and left' "$(QUIET=1 announce 'he said "hello" and left')"
# A message starting with a dash must not be eaten by osascript's or say's
# option parsing. Testing that through announce() would mean letting it speak
# on every check run, so test the mechanism directly — that `--` really does
# get a dash-leading string past getopt — and then assert the guards are still
# in the source. Between them that is the whole failure mode, silently.
eq "osascript passes a leading dash through --" \
   '-mid sentence dash' \
   "$(osascript -e 'on run argv' -e 'return item 1 of argv' -e 'end run' \
        -- '-mid sentence dash' 2>&1)"
check "announce still guards osascript with --" \
    grep -q -- '-- "\$text" >/dev/null' reset-audio
check "announce still guards say with --" \
    grep -q -- 'say -- "\$text"' reset-audio

# The app list itself.
dupes=$(printf '%s\n' "${AUDIO_APPS[@]}" | sort | uniq -d)
eq "AUDIO_APPS has no duplicates" "" "$dupes"
empty=$(printf '%s\n' "${AUDIO_APPS[@]}" | grep -c '^$')
eq "AUDIO_APPS has no empty entries" "0" "$empty"

bad=$(printf '%s\n' "${AUDIO_APPS[@]}" | grep -c '|.*|')
eq "AUDIO_APPS entries have at most one |" "0" "$bad"

# Matching, against a fake process list: spoken names replace executable
# names, a duplicate process is named once, and an always-running background
# helper is never mistaken for its app.
ps() {
    printf '%s\n' \
        "/Applications/Ableton Live 12 Suite.app/Contents/MacOS/Live" \
        "/Library/Application Support/Audio Hijack/Audio Hijack Scheduler.app/Contents/MacOS/Audio Hijack Scheduler" \
        "/Applications/zoom.us.app/Contents/MacOS/zoom.us" \
        "/Applications/REAPER.app/Contents/MacOS/REAPER" \
        "/Applications/REAPER.app/Contents/MacOS/REAPER" \
        "/Applications/Cubase 14.app/Contents/MacOS/Cubase 14"
}
eq "matching: spoken names, no dupes, helpers skipped" \
   "Ableton Live|Zoom|REAPER|Cubase" "$(audio_apps_running | paste -sd '|' -)"
unset -f ps

# Whatever it reports as running must actually be in the list.
strays=""
while IFS= read -r a; do
    [ -z "$a" ] && continue
    found=0
    for known in "${AUDIO_APPS[@]}"; do [ "$a" = "${known#*|}" ] && found=1 && break; done
    [ "$found" = "0" ] && strays="$strays $a"
done < <(audio_apps_running)
eq "audio_apps_running returns only known names" "" "$strays"

# ---------------------------------------------------------------------------
# the install is reversible, in a throwaway prefix
# ---------------------------------------------------------------------------
echo
echo "  install"

tmp="$(mktemp -d)"
if ./install.sh --prefix "$tmp" --app-dir "$tmp/Applications" >/dev/null 2>&1; then
    [ -L "$tmp/bin/reset-audio" ] && ok "install.sh links the command" \
        || fail "install.sh did not link the command"
    [ -d "$tmp/Applications/Reset Audio.app" ] && ok "install.sh builds the app" \
        || fail "install.sh did not build the app"
    check "the built app is signed" \
        codesign --verify --deep "$tmp/Applications/Reset Audio.app"

    # The version in the bundle must match the script, or the About box lies.
    eq "the app carries the script's version" \
       "$(./reset-audio --version | awk '{print $2}')" \
       "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
          "$tmp/Applications/Reset Audio.app/Contents/Info.plist" 2>/dev/null)"

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
