#!/bin/bash
#
# install.sh — put `reset-audio` on your PATH and build "Reset Audio.app".
#
# Everything it does is undone by ./uninstall.sh, and it touches nothing
# outside the two directories it prints on the way past. It does not ask for
# your password: making the reset promptless is a separate, opt-in step that
# `reset-audio --install-help` will talk you through.
#
# Usage:
#   ./install.sh                      # CLI into ~/bin, app into ~/Applications
#   ./install.sh --prefix /usr/local  # CLI into /usr/local/bin
#   ./install.sh --no-app             # command line only, no .app bundle
#   ./install.sh --app-dir /Applications
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="$HOME"
APP_DIR="$HOME/Applications"
BUILD_APP=1
BUNDLE_ID="io.github.matthew2244.reset-audio"

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)  PREFIX="$2";  shift 2 ;;
        --app-dir) APP_DIR="$2"; shift 2 ;;
        --no-app)  BUILD_APP=0;  shift ;;
        -h|--help) sed -n '3,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "install.sh: unknown option $1" >&2; exit 2 ;;
    esac
done

BIN_DIR="$PREFIX/bin"

# ---------------------------------------------------------------------------
# preflight
# ---------------------------------------------------------------------------

[ "$(uname -s)" = "Darwin" ] || { echo "reset-audio is macOS only." >&2; exit 1; }

# The script is Python 3, stdlib only. macOS ships /usr/bin/python3 as a stub
# that does nothing until the Command Line Tools are installed, so check that
# it actually runs rather than merely that the file exists — the failure
# otherwise turns up much later, as a dialog, when you press the button.
if ! python3 -c 'import sys; sys.exit(0)' >/dev/null 2>&1; then
    cat >&2 <<'EOF'
python3 does not run on this Mac yet. It ships with the Xcode Command Line
Tools, which are a free download and not the full Xcode:

    xcode-select --install

Then run ./install.sh again.
EOF
    exit 1
fi

# ---------------------------------------------------------------------------
# the command
# ---------------------------------------------------------------------------

mkdir -p "$BIN_DIR"
chmod +x "$REPO/reset-audio"
ln -sf "$REPO/reset-audio" "$BIN_DIR/reset-audio"
echo "command   $BIN_DIR/reset-audio -> $REPO/reset-audio"

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo
       echo "note: $BIN_DIR is not on your PATH. Add this to ~/.zshrc:"
       echo "        export PATH=\"$BIN_DIR:\$PATH\""
       echo ;;
esac

# ---------------------------------------------------------------------------
# the app
# ---------------------------------------------------------------------------

if [ "$BUILD_APP" = "1" ]; then
    APP="$APP_DIR/Reset Audio.app"
    mkdir -p "$APP_DIR"
    rm -rf "$APP"

    # The applet is a one-liner that shells out to the command above. `try`
    # swallows the AppleScript error a non-zero exit would otherwise raise:
    # reset-audio has already said what went wrong out loud, and a second
    # dialog saying it again in worse words helps nobody.
    SRC="$(mktemp -t reset-audio-applet).applescript"
    cat > "$SRC" <<EOF
try
	do shell script "$BIN_DIR/reset-audio"
end try
EOF
    osacompile -o "$APP" "$SRC"
    rm -f "$SRC"

    P="$APP/Contents/Info.plist"
    plist_set() { /usr/libexec/PlistBuddy -c "Set :$1 $2" "$P" 2>/dev/null \
                  || /usr/libexec/PlistBuddy -c "Add :$1 $3 $2" "$P"; }

    # LSUIElement keeps it out of the Dock and the app switcher: it does its
    # job in under a second and having it steal focus on the way past is worse
    # than useless when you are listening rather than looking.
    plist_set LSUIElement true bool
    plist_set CFBundleName "Reset Audio" string
    plist_set CFBundleIdentifier "$BUNDLE_ID" string
    plist_set CFBundleShortVersionString \
        "$(python3 "$REPO/reset-audio" --version | awk '{print $2}')" string

    # osacompile declares every privacy usage string it can think of, so a
    # bare applet claims it might want your camera, contacts and HomeKit. This
    # one wants Apple Events and an admin password; the rest are noise in the
    # privacy prompts and are better not asked for.
    for key in NSCameraUsageDescription NSPhotoLibraryUsageDescription \
               NSContactsUsageDescription NSCalendarsUsageDescription \
               NSRemindersUsageDescription NSMicrophoneUsageDescription \
               NSHomeKitUsageDescription NSSiriUsageDescription \
               NSAppleMusicUsageDescription; do
        /usr/libexec/PlistBuddy -c "Delete :$key" "$P" 2>/dev/null || true
    done

    # Editing Info.plist invalidates osacompile's ad-hoc signature, and macOS
    # will refuse to launch a bundle whose seal is broken. Re-sign, always,
    # after the edits and never before them.
    codesign --force --deep -s - "$APP" >/dev/null 2>&1
    codesign --verify --deep "$APP" 2>/dev/null \
        || { echo "install.sh: the app failed to sign; not installing it" >&2
             rm -rf "$APP"; exit 1; }

    echo "app       $APP"
fi

# ---------------------------------------------------------------------------
# check it works
# ---------------------------------------------------------------------------

echo
if "$BIN_DIR/reset-audio" --dry-run --quiet >/dev/null; then
    echo "Installed. Try it:"
    echo
    echo "    reset-audio --status"
    echo
    [ "$BUILD_APP" = "1" ] && echo "Or open \"Reset Audio\" from Spotlight."
    echo "For a reset with no password prompt at all: reset-audio --install-help"
else
    echo "Installed, but the dry run failed. Run 'reset-audio --status' to see why." >&2
    exit 1
fi
