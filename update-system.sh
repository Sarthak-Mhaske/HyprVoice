#!/bin/bash
set -e

REPO_DIR="$HOME/Projects/voice-assistant"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config/hyprvoice-backup-$(date +%Y%m%d-%H%M%S)"

echo "📦 Updating HyprVoice system files..."
echo "💾 Creating backup at: $BACKUP_DIR"

mkdir -p "$BACKUP_DIR"

# Backup current files
cp "$CONFIG_DIR/quickshell/ii/services/Ai.qml" "$BACKUP_DIR/" 2>/dev/null || true
cp "$CONFIG_DIR/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml" "$BACKUP_DIR/" 2>/dev/null || true
cp "$CONFIG_DIR/hypr/voice-engine/listen.py" "$BACKUP_DIR/" 2>/dev/null || true
cp "$CONFIG_DIR/hypr/scripts/"*.sh "$BACKUP_DIR/" 2>/dev/null || true

# Update files
echo "📂 Copying updated files..."
cp "$REPO_DIR/config/quickshell/ii/services/Ai.qml" "$CONFIG_DIR/quickshell/ii/services/"
cp "$REPO_DIR/config/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml" "$CONFIG_DIR/quickshell/ii/modules/ii/voiceOverlay/"
cp "$REPO_DIR/config/hypr/voice-engine/listen.py" "$CONFIG_DIR/hypr/voice-engine/"
cp "$REPO_DIR/config/hypr/scripts/"*.sh "$CONFIG_DIR/hypr/scripts/"
chmod +x "$CONFIG_DIR/hypr/scripts/"*.sh

echo ""
echo "✅ Files updated!"
echo "📁 Backup saved: $BACKUP_DIR"
echo ""
echo "🔄 Restart services with:"
echo "   pkill -f listen.py && bash ~/.config/hypr/scripts/start-voice-listener.sh"
echo "   hyprctl dispatch exec 'pkill quickshell; sleep 1; qs -n -c ii'"
