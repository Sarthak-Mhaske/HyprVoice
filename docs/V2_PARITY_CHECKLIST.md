# HyprVoice V2 Parity Checklist

This document tracks the feature parity between the frozen `legacy-stable-v1` (Quickshell) branch and the new `v2` (Universal Python) rewrite.

| Feature | Status | Notes |
| :--- | :--- | :--- |
| **System Diagnostics & Context** | Done | Environment detection, package scanning (`context.py`, `doctor.py`). |
| **Rotating Groq API Keys** | Partial | Implemented selection logic, needs retry loop in `agent.py`. |
| **LLM Fallback Model Chain** | Planned | Needs to fall back to smaller models on failure/rate-limit. |
| **Rate-limit Retry / Fallback** | Planned | Needs to automatically handle 429 status codes. |
| **Wake Word Detection** | Partial | Scaffold added (`openwakeword` + `PyAudio`), needs loop integration. |
| **Record → Transcribe Flow** | Done | Integrated in `transcription_flow.py` (arecord/parecord/ffmpeg). |
| **Multilingual STT (Indic Retry)** | Done | Retries with `language="hi"` on failure via `stt.py`. |
| **Auto-Translation to English** | Done | Transparent fallback routing implemented in `stt.py`. |
| **TTS Engine Order (Edge → Piper)** | Done | Implemented via `tts.py` with failover logic. |
| **Session State (Memory)** | Done | Implemented via `session.py`. |
| **Overlay UI** | Planned | GTK4 floating pill replacing `VoiceOverlay.qml`. |
| **Chat Panel UI** | Planned | GTK4 End-4 style sidebar replacing `AssistantChat.qml`. |
| **Tool Execution Layer** | Planned | Secure `Toolbox` execution engine mapping to bash commands. |
| **Notifications/Reminders** | Planned | `notify-send` parity. |
| **Screenshots (Context)** | Planned | Screenshot extraction + Base64 LLM attachment parity. |
| **Open App / URLs** | Planned | `hyprctl dispatch exec` & `xdg-open` mappings. |
| **Media Control** | Planned | `playerctl` parity. |
| **Safety Levels for Shell Exec** | Planned | Pre-defined guardrails for destructive commands. |
