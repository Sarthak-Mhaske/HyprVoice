#!/bin/bash
# 🎤 Voice Listener Launcher
# Handles both Bash and Fish shells

VOICE_ENGINE_DIR="$HOME/.config/hypr/voice-engine"
VENV_DIR="$VOICE_ENGINE_DIR/venv"
LISTEN_SCRIPT="$VOICE_ENGINE_DIR/listen.py"

# Kill any existing listener
pkill -f "listen.py" 2>/dev/null

# Check if venv exists
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ Virtual environment not found. Creating..."
    python -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install openwakeword pyaudio numpy
fi

echo "🚀 Starting HyprVoice Listener..."

# Run in bash (not fish) to avoid activation issues
# Use absolute path to Python to avoid shell issues
nohup "$VENV_DIR/bin/python" "$LISTEN_SCRIPT" >> /tmp/voice-listener.log 2>&1 &

disown

echo "✅ Listener started (PID: $!)"
echo "📝 Logs: tail -f /tmp/voice-listener.log"
