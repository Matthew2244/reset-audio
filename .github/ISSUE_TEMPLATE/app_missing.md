---
name: My audio app is not recognised
about: Add an application to the "check its audio device" list
title: 'Recognise <app name>'
labels: enhancement, good first issue
assignees: ''
---

After a reset, the tool names the audio applications you have open, because
several of them hold their device across a restart and need reselecting. If
yours is not named, it is missing from the list.

**Application name**

**Its executable name**, with the app running:

```bash
ps -Ao comm= | grep -i yourapp
```

```
paste the output here
```

The last path component is what the list matches on, and it is often not the
name in the Applications folder.

**Does it actually need attention after a Core Audio reset?** Some apps
recover on their own — worth saying which yours does, so the announcement
stays honest.

This is a two-line change to `AUDIO_APPS` in `reset-audio` and a good first
pull request if you fancy it. See CONTRIBUTING.md.
