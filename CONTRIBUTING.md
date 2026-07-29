# Contributing

Contributions are welcome, including from people using an AI assistant to
write them. This document is written to be complete enough that an assistant
can extend the project correctly from this file alone, without having seen the
conversation that started it.

There is also a [CLAUDE.md](CLAUDE.md) at the repository root, which Claude
Code picks up on its own when you open the repo. It is the short version.
This file is the reference.

## Sending a change

You do not need permission to start, and you do not need to be invited. Open
an issue first only if you want to know whether an idea is wanted before
spending time on it — for a fix, just send it.

```bash
gh repo fork Matthew2244/reset-audio --clone
cd reset-audio
git checkout -b my-change

# work, then:
./tools/check.sh

git commit -am "Short summary of what changed"
gh pr create --fill
```

CI runs `tools/check.sh` on macOS for every pull request, forks included.

## The three rules

Everything else is a preference. These three are not.

**1. Speak the outcome, every time.** A tool that silently succeeds leaves a
screen reader user guessing whether it ran at all — and this one is most often
run at exactly the moment audio is broken, which is the worst possible moment
to be guessing. Every path out of `reset()` ends in `announce()`: success,
cancellation, and failure alike. If you add a path, it announces.

**2. Never claim a success you have not verified.** Killing `coreaudiod` is
not the same as Core Audio coming back. The script waits for launchd to
respawn it and checks the PID actually changed, because a daemon that ignored
the signal leaves the old PID in place and would otherwise be announced as a
fix. Any new operation gets the same treatment: check, then speak.

**3. Never prompt for a password in a terminal.** `sudo`'s own prompt has no
accessible label, does not announce itself, and gives no feedback as you type.
Root comes from a sudoers rule or from AppleScript's `with administrator
privileges` and nowhere else. This is the reason the project exists; a change
that reintroduces a shell password prompt will not be merged.

## Some further guidance

**Keep it to the standard library.** It has to run on a stock Mac with only
the Command Line Tools installed, which today means Python 3.9. No `pip`, no
virtualenv, no third-party imports, and no syntax newer than 3.9 — the
structural pattern matching and the `X | Y` annotations you would reach for
are both 3.10.

**Pass text to `osascript` as an argument, never inside the script source.**
`announce()` builds an AppleScript handler and passes the message as `item 1
of argv`. Interpolating it into the source instead means a message containing
a double quote ends the string early, and the announcement either says the
wrong thing or fails silently. Same reasoning applies anywhere else
user-visible text meets AppleScript.

**Say when something failed, in words that describe what to do next.** "Core
Audio was stopped but has not come back yet. Give it a moment, then run reset
audio again." is a useful sentence. "Error 2" is not. These strings are heard
once, at speed, by someone whose audio has just broken — they get read aloud,
so write them to be listened to rather than looked at.

**Keep the tool silent on the network.** It makes no requests and has no
telemetry. That is a property worth keeping, not an oversight to fix.

**Adding an application to the "check its audio device" list** is the easiest
useful change here. Add it to `AUDIO_APPS` in `reset-audio`, in the name that
appears in `ps -Ao comm=` — that is the executable name, which is often not
the name in the Applications folder. Check yours with the app running:

```bash
ps -Ao comm= | grep -i yourapp
```

Matching is by prefix, so `Cubase` covers `Cubase 13` and `Cubase 14`. Prefer
the shortest prefix that is not ambiguous with something else.

## Running the checks

```bash
./tools/check.sh
```

It compiles the script, exercises every read-only entry point, confirms
`--dry-run` really does leave `coreaudiod` alone, parses the shell scripts,
and then installs and uninstalls the whole thing against a temporary prefix so
a broken installer is caught before someone clones it. About a second, and it
changes nothing on your machine.

## What the checks cannot cover

There is no way to test an actual reset without stopping the audio daemon on
the machine running the test. So an actual reset is verified by hand, and a
change that touches `reset()`, `try_auth_dialog()` or `try_passwordless()`
should be checked against this list before it is sent:

- A plain `reset-audio` with no sudoers rule shows one native dialog, and
  succeeds after you authenticate.
- Cancelling that dialog says "cancelled" and exits 1, and nothing was killed
  (`--status` still shows the same PID).
- With the sudoers rule installed, a reset happens with no prompt at all.
- `--dialog` still shows the dialog even with the rule installed.
- With VoiceOver on, the announcement comes from VoiceOver and does not talk
  over itself. With VoiceOver off, `say` speaks it.
- `--quiet` says nothing at all.
- The app, launched from Spotlight, does the same as the command and puts
  nothing in the Dock.

Say in your pull request which of these you ran. "I could not test the
sudoers path" is a fine thing to write and much better than silence.

## Working on the app bundle

The `.app` is not checked in — it is built by `install.sh` from a two-line
AppleScript, so there is no compiled binary in the repository to review or to
trust. If you change how it is built, the one thing not to lose is this:

**Editing `Info.plist` after `osacompile` invalidates the ad-hoc code
signature, and macOS refuses to launch a bundle whose seal is broken.** Re-run
`codesign --force --deep -s -` after the plist edits, never before. This
failure looks like the app doing nothing at all when launched, with the reason
only visible in Console.

## Reporting a bug

Include what you heard, not only what you saw — if the announcement was wrong,
the wording of it is the bug report. `reset-audio --status` output, your macOS
version, and whether VoiceOver was running cover almost everything else.
