---
name: "🐧 V2 Alpha Compatibility Report"
about: Share whether the V2 Alpha worked or failed on your specific Linux distribution.
title: "[V2 Compat] "
labels: ["v2-alpha", "compatibility"]
assignees: ""
---

## Overview
Tell us what worked and what didn't on your setup to help us improve the installation guides.

## Environment
- **Distro & Version:** (e.g., Fedora 40, Manjaro)
- **Desktop Environment / WM:** (e.g., Sway, KDE Plasma)
- **Audio Stack:** (e.g., PipeWire + WirePlumber, PulseAudio)

## What I Tested
Check the feature tiers you tried to run:
- [ ] Core typed chat (`hyprvoice chat-live`)
- [ ] Shared UI Panel (`hyprvoice ui-live`)
- [ ] Manual Voice (`hyprvoice voice-once`)
- [ ] Wake-word Loop (`hyprvoice listen`)
- [ ] Full Assistant (`hyprvoice ui-assistant`)

## Results
**What worked well:**
(Briefly list what ran smoothly.)

**What failed or required workarounds:**
(e.g., "I had to install `python-gobject` manually instead of `gi`", or "Audio capture was silent".)

## Relevant Output
Please paste the output of the following commands:

**Capabilities:**
```bash
# output of: ./venv/bin/hyprvoice capabilities
```

**Doctor:**
```bash
# output of: ./venv/bin/hyprvoice doctor
```

## Install Notes (Optional)
If you found the exact package names needed on your distro, list them here! This helps us build the final installer script.
