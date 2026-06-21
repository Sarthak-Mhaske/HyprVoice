#!/bin/bash

pkill paplay 2>/dev/null
pkill -f "piper" 2>/dev/null

TEMP_AUDIO="/tmp/voice_command.wav"
TRIGGER_FILE="/tmp/voice_active"
LANG_FILE="/tmp/voice_language"

GROQ_KEYS=$(secret-tool lookup 'application' 'illogical-impulse' | jq -r '.apiKeys.groq')
if [[ -z "$GROQ_KEYS" || "$GROQ_KEYS" == "null" ]]; then
    notify-send "❌ Voice" "No API key"
    rm -f "$TRIGGER_FILE"
    exit 1
fi

IFS=',' read -ra KEY_ARRAY <<< "${GROQ_KEYS// /}"
GROQ_API_KEY="${KEY_ARRAY[$RANDOM % ${#KEY_ARRAY[@]}]}"

timeout -k 2 5s parecord --channels=1 --rate=16000 "$TEMP_AUDIO" 2>/dev/null

if [ ! -s "$TEMP_AUDIO" ]; then
    notify-send "❌ Voice" "No audio"
    rm -f "$TRIGGER_FILE"
    exit 1
fi

# Step 1: Transcribe (original language)
# First try: Auto-detect language
TRANSCRIPTION=$(curl -s -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
  --max-time 15 \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$TEMP_AUDIO" \
  -F "model=whisper-large-v3-turbo")

TEXT=$(echo "$TRANSCRIPTION" | jq -r '.text // empty')
ERR_MSG=$(echo "$TRANSCRIPTION" | jq -r '.error.message // empty')

if [[ -z "$TEXT" ]]; then
    if [[ -n "$ERR_MSG" ]]; then
        notify-send "❌ API Error" "$ERR_MSG"
    else
        notify-send "❌ Voice" "Couldn't hear you"
    fi
    rm -f "$TEMP_AUDIO" "$TRIGGER_FILE"
    exit 1
fi
TRANSCRIPTION="$TEXT"

# Check if Whisper incorrectly detected Arabic/Urdu (common misdetection for Indian languages)
if echo "$TRANSCRIPTION" | grep -qP '[\x{0600}-\x{06FF}\x{0750}-\x{077F}]'; then
    # Arabic/Urdu script detected - likely wrong, retry with Hindi hint
    notify-send "🔄 Retrying..." "Detected wrong script"
    
    TRANSCRIPTION=$(curl -s -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
      --max-time 15 \
      -H "Authorization: Bearer $GROQ_API_KEY" \
      -H "Content-Type: multipart/form-data" \
      -F "file=@$TEMP_AUDIO" \
      -F "model=whisper-large-v3-turbo" \
      -F "language=hi" | jq -r '.text')
fi

# Clean whisper artifacts
TRANSCRIPTION=$(echo "$TRANSCRIPTION" | sed 's/^[Tt]he translation is[:\.]* *//g')
TRANSCRIPTION=$(echo "$TRANSCRIPTION" | sed 's/^[Tt]ranslation[:\.]* *//g')

notify-send "🗣️ You said:" "$TRANSCRIPTION"

# Check if Devanagari or Arabic scripts are present instead of broad non-ASCII
if echo "$TRANSCRIPTION" | grep -qP '[\x{0900}-\x{097F}\x{0600}-\x{06FF}\x{0750}-\x{077F}]'; then
    
    # Detect language
    if echo "$TRANSCRIPTION" | grep -qP '[\x{0900}-\x{097F}]'; then
        LANG_DETECT=$(curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
          --max-time 10 \
          -H "Authorization: Bearer $GROQ_API_KEY" \
          -H "Content-Type: application/json" \
          -d "{
            \"model\": \"llama-3.1-8b-instant\",
            \"messages\": [
              {\"role\": \"system\", \"content\": \"Reply with ONLY one word: hindi or marathi\"},
              {\"role\": \"user\", \"content\": \"$TRANSCRIPTION\"}
            ],
            \"max_tokens\": 5,
            \"temperature\": 0
          }" | jq -r '.choices[0].message.content' | tr '[:upper:]' '[:lower:]' | tr -d ' \n')
        # Normalize language label to stable tokens for TTS routing
        LANG_NORM=$(echo "$LANG_DETECT" | tr '[:upper:]' '[:lower:]' | tr -d ' \n\r\t')

        if echo "$LANG_NORM" | grep -qiE 'marathi|मराठी|माराठी|मऱ्हाठी'; then
            LANG_NORM="marathi"
        elif echo "$LANG_NORM" | grep -qiE 'hindi|हिंदी|हिन्दी'; then
            LANG_NORM="hindi"
        else
            # Devanagari was detected but detector output is ambiguous -> default
            LANG_NORM="marathi"
        fi

        echo "$LANG_NORM" > "$LANG_FILE"
    else
        echo "other" > "$LANG_FILE"
    fi
    
    # Translate audio to English using Whisper (audio file still exists!)
    ENGLISH=$(curl -s -X POST "https://api.groq.com/openai/v1/audio/translations" \
      --max-time 15 \
      -H "Authorization: Bearer $GROQ_API_KEY" \
      -H "Content-Type: multipart/form-data" \
      -F "file=@$TEMP_AUDIO" \
      -F "model=whisper-large-v3-turbo" | jq -r '.text')
    
    # NOW delete audio file
    rm -f "$TEMP_AUDIO"
    
    # Debug
    echo "[DEBUG] Original: $TRANSCRIPTION" >> /tmp/voice-translation.log
    echo "[DEBUG] Detected: $(cat $LANG_FILE)" >> /tmp/voice-translation.log
    echo "[DEBUG] Whisper English: $ENGLISH" >> /tmp/voice-translation.log
    echo "---" >> /tmp/voice-translation.log
    
    if [[ -z "$ENGLISH" || "$ENGLISH" == "null" ]]; then
        ENGLISH="$TRANSCRIPTION"
    fi

    LANG_TAG=$(cat "$LANG_FILE" 2>/dev/null || echo "english")
    qs ipc -c ii call ai voiceMessageTranslated "$TRANSCRIPTION" "$ENGLISH" "$LANG_TAG"

else
    echo "english" > "$LANG_FILE"
    rm -f "$TEMP_AUDIO"
    qs ipc -c ii call ai voiceMessage "#voice $TRANSCRIPTION"
fi

sleep 1
rm -f "$TRIGGER_FILE"
