# HyprVoice V2 Plan

## Purpose
The purpose of the V2 rewrite is to transition from a highly-coupled Quickshell/Hyprland script configuration into a clean, standalone application.

## Goals
- **Standalone Architecture:** Remove tight coupling to specific shell configs.
- **Universal Linux Support:** Run seamlessly across multiple window managers and desktop environments, not just Hyprland.
- **GTK4 Overlay:** Provide a modern, native GTK4 UI overlay instead of QML.
- **Python Backend:** Consolidate all logic (audio, LLM, tools) into a robust Python backend package.

## Transition Note
The legacy implementation (in the repository root) remains fully supported and operational separately while the transition to V2 occurs.
