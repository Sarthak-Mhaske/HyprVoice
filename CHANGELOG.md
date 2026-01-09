# Changelog

All notable changes to HyprVoice will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-10

### Added
- Initial release of HyprVoice (Hyprland Voice Assistant for Linux)
- Wake word detection via OpenWakeWord ("Alexa" by default)
- Speech-to-text using Groq Whisper API
- Natural language processing with Groq LLM (Llama 3.3 70B)
- Automatic model fallback chain on rate limits
- Multi-language support (English, Hindi, Marathi)
- Offline text-to-speech using Piper TTS
- Visual feedback with wave animation overlay
- 19 function-calling tools:
  - Media control (play, pause, next, previous, stop)
  - Volume control (0-100%)
  - Brightness control (0-100%)
  - Audio output switching (speakers, HDMI, Bluetooth)
  - Screenshot tools (area, screen, window, monitor)
  - Application launcher (allowlisted apps)
  - YouTube Music integration via yt-dlp
  - URL opener (default and Brave browser)
  - Google search integration
  - Desktop notifications
  - Timed reminders
  - Model switching
  - Quickshell config read/write
  - Shell command execution (with manual approval)
- IPC communication with Quickshell
- Race condition prevention for voice responses
- Comprehensive logging system

### Configuration
- Music player preferences (workspace, background mode)
- API key management via secret-tool
- Language detection and routing

### Documentation
- Complete README with architecture diagram
- Installation guide
- Troubleshooting section
- Function tool reference

[1.0.0]: https://github.com/Sarthak-Mhaske/HyprVoice/releases/tag/v1.0.0