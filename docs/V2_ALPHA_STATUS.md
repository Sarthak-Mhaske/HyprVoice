# HyprVoice V2 Alpha Status

HyprVoice v2 is currently in its **Alpha** stage. This means it is highly functional and demonstrates the core architecture of the rewrite, but it is not yet feature-complete or polished for widespread daily use.

## Current Alpha Scope
The following components are built and working:
- **Environment Detection:** Safe evaluation of the desktop context.
- **Capabilities & Doctor:** Clear visibility into missing local packages.
- **Speech-to-Text:** Groq Whisper STT plumbing.
- **Text-to-Speech:** Piper and Edge-TTS plumbing.
- **Always-Listening Pipeline:** OpenWakeWord background loop.
- **Desktop UI:** GTK4 Chat Panel and Floating Overlay.
- **Shared Session State:** Both voice and typed UI interactions run through the same unified state, keeping them perfectly in sync.

## Known Limitations
- **UX Evolution:** The integration of chat and voice is new. The UI flow will continue to be refined.
- **Setup Complexity:** There is no installer script yet. Setting up dependencies varies drastically between Arch, Fedora, and Ubuntu.
- **Audio Routing:** PulseAudio/PipeWire differences may cause `parecord` or `pyaudio` capture issues on some setups.
- **No Persistence:** Conversation history currently disappears when the app is closed.
- **Visuals:** The UI lacks rich markdown rendering, advanced animations, and a live audio waveform.

## Recommended Alpha Entrypoints
If you've installed the prerequisites, test the system in pieces:

```bash
# 1. Check your setup
./venv/bin/hyprvoice capabilities
./venv/bin/hyprvoice doctor

# 2. Try simple voice (no wake word needed)
./venv/bin/hyprvoice voice-once --no-speak

# 3. Try typed GTK chat
./venv/bin/hyprvoice ui-live

# 4. Try the full listening assistant
./venv/bin/hyprvoice ui-assistant
```

## How You Can Help
If you are testing the Alpha, we need to know where it breaks for you. Please report:
- Missing dependency warnings or required packages for your specific distro.
- Silent failures when capturing microphone audio.
- Issues with wake-word sensitivity (false positives/negatives).
- GTK window rendering issues.
- Unexpected API rate-limiting or fallback failures.
