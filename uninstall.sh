#!/bin/bash
#
# uninstall.sh — remove what install.sh added.
#
# It removes the symlink and the app bundle. It does not remove the repository
# you are standing in, and it does not touch /etc/sudoers.d/reset-audio: that
# was installed by hand, so it is removed by hand.
#
#   sudo rm /etc/sudoers.d/reset-audio
#
# Usage:
#   ./uninstall.sh                      # ~/bin and ~/Applications
#   ./uninstall.sh --prefix /usr/local --app-dir /Applications
#
set -euo pipefail

PREFIX="$HOME"
APP_DIR="$HOME/Applications"

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)  PREFIX="$2";  shift 2 ;;
        --app-dir) APP_DIR="$2"; shift 2 ;;
        -h|--help) sed -n '3,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "uninstall.sh: unknown option $1" >&2; exit 2 ;;
    esac
done

LINK="$PREFIX/bin/reset-audio"
APP="$APP_DIR/Reset Audio.app"
removed=0

# Only remove the symlink install.sh makes. Someone who copied the script in
# by hand gets to keep their copy rather than have it deleted out from under
# them by a script they ran to tidy up.
if [ -L "$LINK" ]; then
    rm -f "$LINK"; echo "removed   $LINK"; removed=1
elif [ -e "$LINK" ]; then
    echo "kept      $LINK (a real file, not our symlink — remove it yourself)"
fi

if [ -d "$APP" ]; then
    rm -rf "$APP"; echo "removed   $APP"; removed=1
fi

[ "$removed" = "1" ] || echo "Nothing to remove."

if [ -f /etc/sudoers.d/reset-audio ]; then
    echo
    echo "note: the passwordless sudo rule is still installed. To remove it:"
    echo "        sudo rm /etc/sudoers.d/reset-audio"
fi
