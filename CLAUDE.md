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

Thirty-odd checks, a couple of seconds, changes nothing. It also **sources
`reset-audio`** and tests the internals directly — the `BASH_SOURCE[0]` guard
at the bottom of the script is what makes that possible, so leave it there.
Only `try_passwordless()` and `try_auth_dialog()` are out of reach, since they
take root; CONTRIBUTING.md has the by-hand list for those.

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
- **bash 3.2 is the floor** — `/bin/bash` on macOS, pinned in the shebang. No
  associative arrays, no `${var^^}`, no `mapfile`. A Homebrew bash 5 on your
  PATH will accept things that fail for everyone else.
- **Pass text to `osascript` and `say` as `argv`, after `--`.** Interpolating
  it into the AppleScript source breaks on a double quote; omitting the `--`
  loses any message starting with a dash to getopt. Both fail silently.
- **No dependencies, on purpose.** It was Python until 1.1.0; a stock Mac has
  no working `python3` until the Command Line Tools are installed, which is a
  poor thing to discover when your audio is already broken.

## House style

Comments explain *why*, not what. Spoken strings are written to be listened to
once, at speed, by someone whose audio has just broken — so they say what
happened and what to do next, in that order.
