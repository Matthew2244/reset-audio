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

**Add no dependencies.** It has to run on a Mac where nothing has been
installed, because that is the state a lot of Macs are in and this is a tool
you reach for when something is already wrong. `/bin/bash` and what ships with
macOS, and that is the list.

**That means bash 3.2.** `/bin/bash` on macOS has been 3.2.57 for years and
shows no sign of moving. So: no associative arrays, no `${var^^}`, no
`mapfile`/`readarray`, no `&>>`. The shebang pins `/bin/bash` on purpose — if
you develop with a Homebrew bash 5 on your PATH it will happily accept things
that fail for everyone else, so run `./tools/check.sh` before you send
anything, since it invokes the script the same way a user does.

**Pass text to `osascript` and `say` as an argument after `--`, never inside
the script source.** `announce()` builds an AppleScript handler and passes the
message as `item 1 of argv`. Interpolating it into the source instead means a
message containing a double quote ends the string early. And both commands
parse their arguments with getopt, so without the `--` a message beginning
with a dash is read as an option and the announcement is lost with an error
nobody sees. Neither failure is loud; both are covered by the checks.

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

If the executable name would sound wrong read aloud, give the entry a spoken
name after a `|`: `"zoom.us|Zoom"`, `"Live|Ableton Live"`. Background helpers
(anything ending in Helper, Scheduler, Agent, Extension or Service) are skipped
before matching, so an app that leaves one running all the time is only named
when the app itself is open.

## Running the checks

```bash
./tools/check.sh
```

Thirty-odd checks, a couple of seconds, and it changes nothing on your
machine. It parses every script, exercises the read-only entry points,
confirms bad input is rejected with the right exit code, confirms `--dry-run`
really does leave `coreaudiod` alone, and installs and uninstalls the whole
thing against a temporary prefix so a broken installer is caught before
someone clones it.

It then **sources `reset-audio` and tests the logic directly**. Sourcing the
script defines its functions and runs nothing — that is what the
`BASH_SOURCE[0]` guard at the bottom is for, so do not remove it. That gets
the PID handling, the respawn wait and the spoken sentences under test
without stopping the audio daemon to do it. If you add a function, add a case
to `tools/check.sh` for it.

The spoken strings are asserted exactly, at every count — no apps, one, two,
three. That is on purpose: those strings are the user interface, so a change
to the wording should be a deliberate edit to the check as well.

## What the checks cannot cover

Two functions actually take root — `try_passwordless()` and
`try_auth_dialog()` — and there is no way to exercise those, or an actual
reset, without stopping the audio daemon on the machine running the test. So
those are verified by hand, and a change touching them or `reset_audio()`
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
