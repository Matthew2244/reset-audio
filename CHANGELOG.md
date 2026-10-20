# Changelog

## 1.2.0 — 2026-10-20

More apps recognised after a reset, and names that sound right read aloud.

- Now recognises Audio Hijack, Loopback, SoundSource, Farrago, Zoom,
  Microsoft Teams, Discord, Skype, TeamTalk, Gig Performer, Pianoteq and
  MuseScore. Calls and routing tools hold an audio device just like a DAW does.
- An entry can carry a spoken name. Ableton Live was announced as just "Live",
  since that is its executable name; it now says "Ableton Live". Same for
  Zoom (`zoom.us`), Microsoft Teams (`MSTeams`), Bitwig Studio and MuseScore.
- Background helpers are skipped before matching. Audio Hijack leaves its
  Scheduler running all the time, so without this every reset would have said
  Audio Hijack was open when it was not.
- Two new checks: matching against a fake process list, and the spoken-name
  format.

## 1.1.0 — 2026-07-28

**No dependencies.** Rewritten from Python to bash, so a stock Mac can run it
with nothing installed first.

The Python version needed `python3`, which macOS ships only as a stub until
the Xcode Command Line Tools are installed. That put a download and a dialog
between someone and a tool whose entire job is to be reachable at the moment
their audio has broken. It is now `/bin/bash` — 3.2, the one macOS actually
has — and commands already present on every Mac.

Behaviour is unchanged: same flags, same exit codes, same spoken strings, byte
for byte.

- The script is now **sourceable**: sourcing it defines the functions and runs
  nothing, so `tools/check.sh` tests the internals directly rather than only
  through the command line. Everything except the two functions that take root
  is now under test — the PID handling, the respawn wait, and the spoken
  sentence at every app count.
- Fixed while writing those tests: `announce()` passed its message to
  `osascript` and `say` without a `--`, so any message beginning with a dash
  would have been parsed as an option and lost silently. Nothing it says today
  starts with one, which is exactly why it would have gone unnoticed.
- The checks grew from 14 to 34, and now cover argument validation and exit
  codes, and that the built app carries the script's version.

## 1.0.0 — 2026-07-28

First public release. Previously a personal script; this is the same tool made
fit for someone else's Mac.

- `reset-audio` restarts Core Audio, confirms the daemon genuinely came back
  by checking for a new PID, and announces the result through VoiceOver, or
  through `say` when VoiceOver is not running.
- Root comes from a scoped sudoers rule if you have opted into one, otherwise
  from the native macOS authorisation dialog. Never from a terminal password
  prompt.
- `install.sh` installs the command and builds `Reset Audio.app`;
  `uninstall.sh` removes both. Neither needs your password.
- After a reset, running audio applications are named so you know which ones
  need their device reselecting. Recognises 31 of them, including the audio
  editors screen reader users actually reach for.
- `--status`, `--dry-run`, `--quiet`, `--say`, `--dialog`, `--timeout`,
  `--install-help`, `--version`.
- `tools/check.sh` runs everything CI does, including a full install and
  uninstall against a temporary prefix.

Changed while preparing the release:

- The sudoers help no longer hard-codes a username, and the app is built at
  install time against wherever you installed the command, rather than
  assuming a path.
- `--status` now reports a cached `sudo` session separately from an installed
  sudoers rule. The two look identical at the moment you ask, but one of them
  expires in five minutes, and saying "no prompt" about it was wrong.
- The post-reset reminder covered REAPER only; it now covers the DAWs, editors
  and streaming tools people actually leave open.
- Added `--say` and `--timeout`.
