# V2 Alpha Tester Checklist

If you are trying to run the HyprVoice v2 Alpha locally, use this checklist to verify your setup progressively. By validating each step, you can isolate where things might be breaking on your specific machine.

## 1. Setup & Config
- [ ] `git clone` the repository and run `python -m venv venv && ./venv/bin/pip install -e .`
- [ ] Run `./venv/bin/hyprvoice config-init` to generate `~/.config/hyprvoice/config.yml`
- [ ] Open your config and add your Groq API key (`gsk_...`) under `groq.api_keys`

## 2. Environment Diagnostics
- [ ] Run `./venv/bin/hyprvoice capabilities`. Identify what your system is ready for.
- [ ] Run `./venv/bin/hyprvoice doctor`. Verify it sees your OS and Wayland compositor.

## 3. Basic LLM & Typed Chat
- [ ] Run `./venv/bin/hyprvoice ask "What is 2+2?"`. Ensure it successfully queries the LLM and prints `4`.
- [ ] Run `./venv/bin/hyprvoice chat-live`. Type a message and ensure you receive an assistant reply in your terminal.

## 4. UI Validation
*Requires GTK4 and PyGObject.*
- [ ] Run `./venv/bin/hyprvoice ui-live`. Verify that the GTK chat panel opens.
- [ ] Type a request in the panel and ensure the status line updates from "Ready" -> "Thinking..." and the reply appears.

## 5. Voice Capture Validation
*Requires `parecord`, `arecord`, or `ffmpeg`.*
- [ ] Run `./venv/bin/hyprvoice voice-once --no-speak`.
- [ ] Speak a 5-second command clearly (e.g. "What time is it?").
- [ ] Verify that the tool captures the audio, transcribes it, and prints the LLM's response to your terminal.

## 6. Full Assistant Loop (Wake Word)
*Requires `openwakeword`, `pyaudio`, `numpy`.*
- [ ] Run `./venv/bin/hyprvoice ui-assistant`.
- [ ] Say your wake word ("Alexa").
- [ ] Verify that the desktop overlay pops up displaying "Wake detected" followed by "Listening...".
- [ ] Speak your command and verify that both the overlay and chat panel update to reflect the assistant's state.

If you made it this far, congratulations! You have successfully spun up the entire v2 alpha stack locally.
