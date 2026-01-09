#!/bin/bash
# 🗣️ HyprVoice TTS Engine (Piper only)

text=$(cat)
lang="${VOICE_LANG:-english}"

# Paths
PIPER_BIN="$HOME/.local/share/piper/venv/bin/piper"
MODEL_EN="$HOME/.local/share/piper/models/en_US-lessac-medium.onnx"
MODEL_HI="$HOME/.local/share/piper/models/hi_IN-pratham-medium.onnx"

# Safety: Check if models exist
if [ ! -f "$MODEL_EN" ] || [ ! -f "$MODEL_HI" ]; then
    notify-send "❌ TTS Error" "Voice models missing!"
    exit 1
fi

speak() {
    local t="$1"
    local model="$2"
    local speed="1.1"

    echo "$t" | "$PIPER_BIN" --model "$model" --length-scale "$speed" --output-raw \
        | paplay --raw --channels=1 --rate=22050 --format=s16le
}

# Language Routing
case "$lang" in
    hindi|hi|marathi|mr)
        # Use Pratham for Hindi & Marathi
        speak "$text" "$MODEL_HI"
        ;;
    *)
        # Default to English
        speak "$text" "$MODEL_EN"
        ;;
esac
