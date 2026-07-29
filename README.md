# Reset Audio

Restart macOS Core Audio in one keystroke, and hear whether it worked.

When audio on a Mac wedges — no sound at all, a device that has vanished from
the list, an interface your DAW can see but not open, crackling that survives
a buffer change — the fix is almost always to restart the Core Audio daemon:

```
sudo killall -9 coreaudiod
```

That command has never been the hard part. The friction is everything around
it. Find the note you keep it in, select the line, copy it, launch Terminal,
paste, type an admin password into a shell prompt that gives no useful screen
reader feedback, then read back the scrollback to work out whether anything
actually happened. Six steps and a context switch to run one command that
takes half a second.

This is that, as one command and one app. It gets root the accessible way,
confirms Core Audio genuinely came back rather than assuming it, and says the
result out loud.

Built by and for a screen reader user, which is why the confirmation is spoken
rather than printed. It works exactly the same with VoiceOver off, and if you
are sighted you may just like not opening Terminal.

## Requirements

- macOS. Core Audio is a macOS thing; there is no sensible port of this.
- Python 3, from the Xcode Command Line Tools (`xcode-select --install`).
  Standard library only — nothing to `pip install`. If `python3 --version`
  answers, you are ready.
- VoiceOver is optional. With it running, announcements go through VoiceOver
  itself; without it, they go through `say`.

## Install

```bash
git clone https://github.com/Matthew2244/reset-audio.git
cd reset-audio
./install.sh
```

That symlinks the `reset-audio` command into `~/bin` and builds
`~/Applications/Reset Audio.app`, then verifies both. It never asks for your
password.

If `~/bin` is not on your `PATH`, the installer says so and prints the line to
add. To put things elsewhere:

```bash
./install.sh --prefix /usr/local --app-dir /Applications
./install.sh --no-app          # command line only
```

`./uninstall.sh` removes both, taking the same options.

## Use

Reset Core Audio:

```bash
reset-audio
```

Or launch **Reset Audio** from Spotlight, the Dock, or a keyboard shortcut —
it has no window and no Dock icon, it just runs and speaks.

You will hear one of:

- *"Core Audio reset. Done. REAPER is open, so check its audio device."*
- *"Core Audio reset cancelled. Nothing was changed."* — you dismissed the
  password dialog.
- *"Core Audio was stopped but has not come back yet. Give it a moment, then
  run reset audio again."*

The named-application part is there because several DAWs hold their device
open across a restart and need reselecting afterwards. It recognises the
usual suspects and only mentions the ones actually running.

### Other things it does

- `--status` — whether Core Audio is running, how long for, how much CPU it is
  using, whether the next reset will prompt you, and which audio apps are
  open. Changes nothing.
- `--dry-run` — says what a reset would do. Changes nothing.
- `--quiet` — print, do not speak.
- `--say` — speak with `say` even when VoiceOver is running.
- `--dialog` — always use the password dialog, even when passwordless sudo is
  available.
- `--timeout SECONDS` — how long to wait for Core Audio to come back. Default
  15.
- `--install-help` — how to make resets promptless.

Exit codes: `0` succeeded, `1` cancelled or failed, `2` Core Audio was stopped
but had not returned within the timeout.

## How it gets root

Stopping a system daemon needs root, and how you are asked for it is the whole
accessibility story here. In order of preference:

1. **Passwordless sudo**, if you have chosen to install the one-line rule. You
   type nothing at all. It is opt-in and the installer does not do it for you —
   see below.

2. **The native macOS authorisation dialog**, via AppleScript's `with
   administrator privileges`. One dialog, a real secure text field, proper
   VoiceOver support, and Touch ID where your keyboard offers it. No Terminal
   window, no shell prompt, no echoed password.

What it never does is prompt in a terminal. `sudo`'s own prompt is a bare line
of text with no accessible label, no announcement when it appears, and no
feedback as you type — it is the single worst part of the manual routine, and
avoiding it is most of the point of this tool.

Either way the result is checked rather than assumed. It waits for launchd to
respawn `coreaudiod` and confirms the new process has a different PID, so a
daemon that refused to die is reported as a failure instead of being announced
as a success.

### Making it promptless

`reset-audio --install-help` prints a sudoers rule scoped to exactly this one
command:

```
you ALL=(root) NOPASSWD: /usr/bin/killall -9 coreaudiod
```

Because sudoers matches the whole command line, this grants that exact
argument vector and nothing else — `killall -9` on anything else still asks
for a password. The worst case if it were ever abused is a stopped audio
daemon that launchd restarts a second later.

It is still a change to your machine's security configuration, so it is your
decision and this project will not make it for you. Running with the dialog is
a perfectly good way to use this.

## What it does not do

- It does not restart audio *devices*, only the Core Audio daemon. If your
  interface itself has locked up, this will not unlock it.
- It does not change your default input or output device.
- It does not touch the network. Nothing is uploaded, logged remotely, or
  phoned home.
- It does not run in the background, install a launch agent, or start at
  login. It runs when you run it, and exits.

## Contributing

Yes, please — including if you are writing the change with an AI assistant.
[CONTRIBUTING.md](CONTRIBUTING.md) is written to be complete enough to work
from on its own, and `./tools/check.sh` runs everything CI does in about a
second.

The most useful small contributions are probably: applications missing from
the "check its audio device" list, and reports of the spoken output being
wrong, clumsy, or talked over on a screen reader other than VoiceOver.

## Licence

MIT. See [LICENSE](LICENSE).
