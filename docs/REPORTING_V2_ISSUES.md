# Reporting Issues in V2 Alpha

Thank you for testing the HyprVoice V2 Alpha branch! Since this is an alpha release, you will likely encounter bugs or missing dependencies specific to your Linux distribution.

Good bug reports help us reach a stable V2 release much faster.

## How to File a Useful Report

When you encounter an issue, please use the **V2 Alpha Bug Report** template on GitHub. 

To make your report actionable, **always include the output of these diagnostic commands**:

```bash
# 1. Shows your exact V2 version
./venv/bin/hyprvoice version

# 2. Shows what features your Python/system environment supports
./venv/bin/hyprvoice capabilities

# 3. Shows your WM/Desktop context
./venv/bin/hyprvoice doctor
```

### ⚠️ Important: Redact Your Secrets
Before pasting terminal output, make sure you **remove or mask your Groq API keys** or any other sensitive personal data.

## What to Include

If possible, narrow down exactly *where* the issue happens. Does the failure occur when you run:
- The text-only chat? (`hyprvoice chat-live`)
- The UI chat? (`hyprvoice ui-live`)
- The voice capture? (`hyprvoice voice-once`)
- The background assistant? (`hyprvoice ui-assistant`)

Please attach:
1. **Python Tracebacks:** If the app crashes with an error, paste the full text of the error.
2. **Screenshots:** If the GTK window looks wrong, attach an image.
3. **Exact Commands:** Show the exact terminal command you ran when the error occurred.

## Distro Compatibility

Linux environments vary wildly. What works out-of-the-box on Arch Linux might fail on Ubuntu due to differing package names for GTK or PyAudio.

If you figure out how to get V2 running perfectly on a specific distro, please submit a **V2 Alpha Compatibility Report** on GitHub. Tell us the exact `apt`, `dnf`, or `pacman` commands you used so we can incorporate them into the final V2 installer script.
