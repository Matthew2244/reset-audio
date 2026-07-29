# reset-audio — notes for Claude Code

One tool: restart macOS Core Audio (`sudo killall -9 coreaudiod`) and say out
loud whether it worked. `reset-audio` is the whole program; `install.sh`
builds a `.app` wrapper around it. [CONTRIBUTING.md](CONTRIBUTING.md) is the
full reference — this is the short version.

## The three rules

1. **Speak the outcome, every time.** Every path out of `reset()` ends in
   `announce()` — success, cancellation and failure alike. This is run at the
   moment audio is broken, which is the worst moment to be guessing whether it
   ran.
2. **Never claim a success you have not verified.** Killing `coreaudiod` is
   not the same as it coming back. Wait for the respawn and confirm the PID
   changed.
3. **Never prompt for a password in a terminal.** `sudo`'s prompt has no
   accessible label. Root comes from a sudoers rule or AppleScript's `with
   administrator privileges`, nowhere else.

## Verifying a change

```bash
./tools/check.sh
```

Compiles, exercises the read-only entry points, confirms `--dry-run` leaves
`coreaudiod` alone, and installs/uninstalls against a temporary prefix. About
a second, changes nothing. An actual reset cannot be tested without stopping
audio on this machine — CONTRIBUTING.md has the by-hand list for that.

## Facts that each cost an afternoon

- **`sudo -n -l <cmd>` cannot detect passwordless sudo.** It answers "is this
  permitted by policy", so on a machine with `(ALL) ALL` it exits 0 for
  everything and reports "no prompt" when there very much is one. Parse the
  `NOPASSWD:` entries out of `sudo -n -l` instead — that is what
  `passwordless_rule_installed()` does.
- **Editing `Info.plist` after `osacompile` invalidates the ad-hoc signature**
  and macOS then refuses to launch the bundle. Re-run
  `codesign --force --deep -s -` after the edits, never before. The symptom is
  the app doing nothing at all, with the reason only in Console.
- **`pgrep -x coreaudiod` is deliberate.** Without `-x` it also matches the
  several "Core Audio Driver (…)" helpers that run as `_coreaudiod`, which
  makes the PID comparison meaningless.
- **Python 3.9 is the floor** — that is what the Command Line Tools ship. No
  `match`, no `X | Y` annotations, standard library only.
- **Pass text to `osascript` as `argv`, never inside the script source.** A
  message containing a double quote otherwise ends the string early.

## House style

Comments explain *why*, not what. Spoken strings are written to be listened to
once, at speed, by someone whose audio has just broken — so they say what
happened and what to do next, in that order.
