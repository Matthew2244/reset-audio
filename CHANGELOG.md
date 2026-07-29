# Changelog

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
