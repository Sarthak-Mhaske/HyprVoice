# HyprVoice V2 UI Direction

This document outlines the UI direction for the standalone Python rewrite of HyprVoice.

## A. Overlay
A small, floating GTK4 overlay window (suggested placement: bottom-center or top-center floating pill) that appears strictly during the voice interaction flow.

**Purpose:**
- Provide instant visual feedback for voice operations.
- Replaces the legacy `VoiceOverlay.qml`.
- Visualizes states such as: wake detected, listening, thinking, and speaking.

## B. Chat UI
A GTK4 **right-side chat panel** that opens and closes like a sidebar.

**Purpose:**
- Facilitates text chatting with HyprVoice.
- Displays transcript/history and tool execution feedback.
- Allows for manual typed commands.

*Note: This interface should feel visually similar to End-4’s assistant/chat style, but it will be a fully standalone HyprVoice UI—not embedded into Quickshell or any specific desktop environment shell.*

## C. Why this direction?
- **Universality:** Quickshell-style shell integration is not universally supported across all Linux systems.
- **Portability:** GTK4 provides robust, cross-distro portability out of the box.
- **Independence:** Maintaining our own overlay and chat panel preserves the premium, integrated feel while entirely removing the dependency on a specific shell or environment.

## D. State Model
Both the overlay and the chat panel will reflect a single shared backend state. The shared assistant states include:
- `idle`
- `wake_detected`
- `listening`
- `transcribing`
- `thinking`
- `executing`
- `speaking`
- `error`
