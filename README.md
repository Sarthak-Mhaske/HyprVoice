<div align="center">

# HyprVoice

**Voice Control for the Modern Linux Desktop**

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](LICENSE)
[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-00ADD8?logo=wayland&logoColor=white)](https://hyprland.org/)
[![Version](https://img.shields.io/badge/Version-1.0.0-green.svg)](https://github.com/Sarthak-Mhaske/HyprVoice/releases)

A hybrid voice assistant combining offline wake word detection with cloud-powered  
speech recognition. Built for Arch Linux, Hyprland, and Quickshell.

[Installation](#installation) · [Commands](#available-commands) · [Configuration](#configuration) · [Roadmap](#roadmap)

---

**Also known as:** `hyprland-voice-assistant` · `linux-voice-assistant`

</div>

---

## Current Status

> **⚠️ Legacy Implementation:** The existing codebase in this repository is the original, stable Quickshell-based implementation built for Arch Linux and Hyprland. It is working reliably, but is now considered the **legacy version**. A universal, standalone Python rewrite is planned separately. For more details, see [docs/LEGACY.md](docs/LEGACY.md).
> 
> **🚀 V2 Alpha is now available for testing!** The standalone Python rewrite is highly functional but still evolving. Check out:
> - [docs/RUN_V2_LOCAL.md](docs/RUN_V2_LOCAL.md) for quick local setup.
> - [docs/DEPENDENCIES_V2.md](docs/DEPENDENCIES_V2.md) for the capability guide.
> - [docs/V2_ALPHA_STATUS.md](docs/V2_ALPHA_STATUS.md) to see what currently works.
> - [docs/V2_ALPHA_CHECKLIST.md](docs/V2_ALPHA_CHECKLIST.md) for progressive setup validation.

---

## Overview

HyprVoice brings voice control to the Linux desktop. Say "Alexa" to wake it up, speak your command, and watch it execute—whether that's playing music, taking screenshots, adjusting volume, or controlling your windows.

---

## Demo

### 🎤 Voice Activation
Say "Alexa" to activate, then give any command:

![Voice Activation Demo](assets/voice-activation.gif)

### 🎵 Music Playback
Control YouTube Music with your voice:

![Music Playback Demo](assets/music-demo.gif)

### 📸 Screenshot Capture
Take screenshots using voice commands:

![Screenshot Demo](assets/screenshot-demo.gif)

---

**The hybrid approach:**
- **Local:** Wake word detection and text-to-speech (privacy, zero latency)
- **Cloud:** Speech recognition and language processing (accuracy, 90+ languages)

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Voice   │ ──▶ │  Wake    │ ──▶ │  Record  │ ──▶ │   STT    │
│  Input   │     │  (local) │     │  5 sec   │     │  (cloud) │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
                                                         │
┌──────────┐     ┌──────────┐     ┌──────────┐         ▼
│  Speak   │ ◀── │   TTS    │ ◀── │  Execute │ ◀─────────────
│ Response │     │  (local) │     │  Action  │
└──────────┘     └──────────┘     └──────────┘
```

> **Privacy:** Audio is only transmitted after wake word detection. Wake word processing happens entirely on-device.

---

> **⚠️ Compatibility Notice**  
> This release requires [End-4's illogical-impulse Quickshell configuration](https://github.com/end-4/dots-hyprland).  
> HyprVoice extends their existing `Ai.qml` service and assumes their directory structure.  
>  
> **Not using illogical-impulse?** Support for standalone installation and other configs is planned for v2.0+.

---

## Features

### Voice Pipeline

| Component | Technology | Runs Locally |
|-----------|------------|:------------:|
| Wake Word | OpenWakeWord | ✓ |
| Speech-to-Text | Groq Whisper API | ✗ |
| Language Model | Groq LLM API | ✗ |
| Text-to-Speech | Piper TTS | ✓ |

### 19 Function Tools

**Media** — play, pause, next, previous, volume, audio output switching  
**System** — brightness, screenshots (area/window/screen), notifications, reminders  
**Apps** — launch allowlisted applications, open URLs, Google search, YouTube Music  
**Shell** — read/write Quickshell config, execute commands (with approval), switch LLM models

### Language Support

English, Hindi (हिंदी), and Marathi (मराठी) with automatic detection.

### Automatic Failover

Rate limited? The system automatically switches models:

```
Llama 3.3 70B → Llama 4 Scout → Maverick → Qwen 3 → Kimi K2 → Llama 3.1 8B
```

---

## Requirements

- **OS:** Arch Linux (or Arch-based)
- **WM:** Hyprland
- **Shell:** Quickshell (End-4/illogical-impulse config)
- **Audio:** PipeWire + WirePlumber
- **API:** Groq account (free tier works)

### Dependencies

```bash
# Core
pacman -S --needed python python-pyaudio jq curl libnotify \
    playerctl brightnessctl wl-clipboard pipewire wireplumber

# AUR
paru -S quickshell-git grimblast-git piper-tts-bin yt-dlp
```

---

## Installation

### Quick Install

```bash
git clone https://github.com/Sarthak-Mhaske/HyprVoice.git
cd HyprVoice
./install.sh
```

### Manual Setup

<details>
<summary>Click to expand</summary>

**1. Copy files**
```bash
cp -r config/quickshell/ii/* ~/.config/quickshell/ii/
cp -r config/hypr/scripts/* ~/.config/hypr/scripts/
cp -r config/hypr/voice-engine/* ~/.config/hypr/voice-engine/
cp -r config/hypr/voice-assistant/* ~/.config/hypr/voice-assistant/
chmod +x ~/.config/hypr/scripts/*.sh
```

**2. Python environment**
```bash
cd ~/.config/hypr/voice-engine
python -m venv venv
./venv/bin/pip install openwakeword pyaudio numpy
```

**3. Piper TTS**
```bash
mkdir -p ~/.local/share/piper/models
cd ~/.local/share/piper
python -m venv venv
./venv/bin/pip install piper-tts
# Download models: en_US-lessac-medium.onnx, hi_IN-pratham-medium.onnx
```

**4. API Key**
```bash
secret-tool store --label='illogical-impulse' application illogical-impulse
# Enter: {"apiKeys": {"groq": "your-key-here"}}
```

**5. Autostart** — add to `~/.config/hypr/hyprland/execs.conf`:
```conf
exec-once = qs -n -c ii
exec-once = setsid -f bash ~/.config/hypr/scripts/start-voice-listener.sh
```

</details>

---

## Available Commands

| Category | Examples |
|----------|----------|
| **Media** | "Play music", "Next song", "Set volume to 50", "Play Shape of You" |
| **System** | "Set brightness to 80", "Take a screenshot", "Screenshot this window" |
| **Apps** | "Open Brave", "Open terminal", "Open file manager" |
| **Reminders** | "Remind me in 10 minutes to check email" |
| **Web** | "Search for Linux tutorials", "Open github.com" |
| **Assistant** | "Switch to the fast model", "Use the best model" |

---

## Configuration

### Wake Word

| Setting | Default |
|---------|---------|
| Wake Word | alexa |
| Threshold | 0.5 |
| Sample Rate | 16kHz |

### Music Player

Edit `~/.config/hypr/voice-assistant/music-player.conf`:

```bash
PREFERRED_PLAYER="youtube-music"
OPEN_IN_BACKGROUND="true"
TARGET_WORKSPACE="3"
```

### LLM Models

| Model | Use Case | Daily Limit |
|-------|----------|-------------|
| llama-3.3-70b | Best quality (default) | 1K |
| llama-4-maverick | Complex reasoning | 1K |
| llama-4-scout | Balanced | 1K |
| llama-3.1-8b | Fastest | 14K |
| qwen3-32b | Alternative | 1K |
| kimi-k2 | Backup | 1K |

Switch via voice: *"Switch to the fast model"*  
Switch via IPC: `qs ipc -c ii call ai setModel "groq-llama-3-1-8b"`

---

## Architecture

```
QUICKSHELL
├── Ai.qml              # LLM communication, function tools, IPC
└── VoiceOverlay.qml    # Visual feedback during listening

VOICE ENGINE
├── listen.py           # Wake word detection (OpenWakeWord)
├── voice-assistant.sh  # STT pipeline (Groq Whisper)
└── text-to-speech.sh   # TTS output (Piper)

EXTERNAL
├── Groq Whisper API    # Speech-to-text
└── Groq LLM API        # Intent parsing + responses
```

IPC communication:
```bash
qs ipc -c ii call ai voiceMessage "#voice <transcription>"
```

---

## Troubleshooting

<details>
<summary><b>Listener not starting</b></summary>

```bash
pgrep -f "listen.py"                              # Check if running
tail -f /tmp/voice-listener.log                   # View logs
pkill -f listen.py && bash ~/.config/hypr/scripts/start-voice-listener.sh  # Restart
```
</details>

<details>
<summary><b>No TTS audio</b></summary>

```bash
echo "Hello" | ~/.config/hypr/scripts/text-to-speech.sh  # Test TTS
ls ~/.local/share/piper/models/                          # Check models
```
</details>

<details>
<summary><b>API errors</b></summary>

```bash
secret-tool lookup 'application' 'illogical-impulse'     # Verify key
```
</details>

**Common fixes:**

| Problem | Solution |
|---------|----------|
| No API key error | Store key with secret-tool |
| Wake word not detected | Increase mic gain or reduce threshold to 0.4 |
| Hindi detected as Arabic | Script auto-retries with Hindi hint |
| Rate limit errors | System auto-switches to fallback model |

---

## Roadmap

### v1.x (Current)

- [x] Core voice pipeline
- [x] 19 function tools
- [x] Multi-language support (EN/HI/MR)
- [ ] Spotify integration (v1.1)
- [ ] 30+ app allowlist (v1.2)
- [ ] Window management (v1.3)
- [ ] Power controls — lock, suspend, hibernate (v1.4)
- [ ] Network controls — WiFi, Bluetooth (v1.5)

### v2.x (Planned)

- [ ] Custom wake words
- [ ] Offline STT (Whisper.cpp) — *experimental*
- [ ] Offline LLM (Ollama) — *experimental*
- [ ] Plugin system
- [ ] Settings UI

### Provider Support

| Provider | Status |
|----------|--------|
| Groq | ✓ Supported |
| OpenAI | Planned (v1.1) |
| Anthropic | Planned (v1.1) |
| Google Gemini | Planned (v1.1) |
| Ollama (local) | Planned (v2.0) |

> The function-calling architecture is provider-agnostic. Adding new providers is straightforward.

### Offline Mode

We're exploring fully offline operation for v2.x. Current status:

| Component | v1.0 | v2.x Goal |
|-----------|:----:|:---------:|
| Wake Word | Local | Local |
| STT | Cloud | Local (Whisper.cpp) |
| LLM | Cloud | Local (Ollama) |
| TTS | Local | Local |

> **Note:** Full offline mode requires 8-16GB RAM. Hybrid mode will remain the default.

---

## File Structure

```
~/.config/quickshell/ii/
├── services/Ai.qml
└── modules/ii/voiceOverlay/VoiceOverlay.qml

~/.config/hypr/
├── scripts/
│   ├── voice-assistant.sh
│   ├── text-to-speech.sh
│   ├── start-voice-listener.sh
│   └── play-music.sh
├── voice-engine/
│   ├── listen.py
│   └── models/alexa.onnx
└── voice-assistant/
    └── music-player.conf

~/.local/share/piper/
└── models/
    ├── en_US-lessac-medium.onnx
    └── hi_IN-pratham-medium.onnx
```

---

## Contributing

```bash
git clone https://github.com/YOUR_USERNAME/HyprVoice.git
git checkout -b feature/your-feature
# Make changes, test
git commit -m "feat: add your feature"
git push origin feature/your-feature
# Open Pull Request
```

**Commit format:** `type: description`  
Types: `feat`, `fix`, `docs`, `refactor`, `chore`

---

## Acknowledgments

### Built On

This project extends the Quickshell configuration from **[End-4's dots-hyprland](https://github.com/end-4/dots-hyprland)** (illogical-impulse). The Ai.qml service and overall shell architecture are built upon their excellent work.

Special thanks to **[@end-4](https://github.com/end-4)** and all [170+ contributors](https://github.com/end-4/dots-hyprland/graphs/contributors) to the dots-hyprland project.

### Technologies

- [OpenWakeWord](https://github.com/dscripka/openWakeWord) — Wake word detection
- [Piper](https://github.com/rhasspy/piper) — Offline text-to-speech
- [Groq](https://groq.com) — Fast LLM and STT inference
- [Hyprland](https://hyprland.org) — Wayland compositor
- [Quickshell](https://github.com/quickshell-mirror/quickshell) — Qt6/QML shell framework

---

## License

This project is licensed under the **GNU General Public License v3.0** — see [LICENSE](LICENSE) for details.

This project builds upon [dots-hyprland](https://github.com/end-4/dots-hyprland) which is also GPL-3.0 licensed.

---

<div align="center">

**[Issues](https://github.com/Sarthak-Mhaske/HyprVoice/issues)** · **[Discussions](https://github.com/Sarthak-Mhaske/HyprVoice/discussions)** · **[Wiki](https://github.com/Sarthak-Mhaske/HyprVoice/wiki)**

</div>