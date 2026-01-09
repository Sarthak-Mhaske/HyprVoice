#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# HyprVoice Uninstaller v1.0.0
# https://github.com/Sarthak-Mhaske/HyprVoice
# ═══════════════════════════════════════════════════════════════

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                                                            ║${NC}"
echo -e "${RED}║              HyprVoice Uninstaller                         ║${NC}"
echo -e "${RED}║                                                            ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}This will remove HyprVoice from your system.${NC}"
echo ""
echo -e "The following will be removed:"
echo -e "  • Voice engine (listen.py, venv)"
echo -e "  • Voice scripts"
echo -e "  • VoiceOverlay.qml"
echo -e "  • Voice assistant config"
echo -e "  • Autostart entry"
echo ""
echo -e "${YELLOW}Note: Ai.qml will NOT be removed (part of illogical-impulse)${NC}"
echo ""

read -p "Are you sure you want to uninstall? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}Uninstall cancelled.${NC}"
    echo ""
    exit 0
fi

echo ""

# ─────────────────────────────────────────
# STEP 1: CREATE BACKUP
# ─────────────────────────────────────────

echo -e "${BLUE}[1/4] Creating backup...${NC}"
echo ""

BACKUP_DIR="$HOME/.config/hyprvoice-uninstall-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup files
if [ -f "$HOME/.config/quickshell/ii/services/Ai.qml" ]; then
    cp "$HOME/.config/quickshell/ii/services/Ai.qml" "$BACKUP_DIR/"
fi

if [ -f "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml" ]; then
    cp "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml" "$BACKUP_DIR/"
fi

if [ -d "$HOME/.config/hypr/voice-engine" ]; then
    cp -r "$HOME/.config/hypr/voice-engine" "$BACKUP_DIR/"
fi

if [ -d "$HOME/.config/hypr/voice-assistant" ]; then
    cp -r "$HOME/.config/hypr/voice-assistant" "$BACKUP_DIR/"
fi

echo -e "  ${GREEN}✓${NC} Backup saved to: $BACKUP_DIR"
echo ""

# ─────────────────────────────────────────
# STEP 2: STOP PROCESSES
# ─────────────────────────────────────────

echo -e "${BLUE}[2/4] Stopping HyprVoice processes...${NC}"
echo ""

if pkill -f listen.py 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Stopped voice listener"
else
    echo -e "  ${YELLOW}⚠${NC} Voice listener was not running"
fi

echo ""

# ─────────────────────────────────────────
# STEP 3: REMOVE FILES
# ─────────────────────────────────────────

echo -e "${BLUE}[3/4] Removing HyprVoice files...${NC}"
echo ""

# Remove VoiceOverlay
if [ -f "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml" ]; then
    rm -f "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml"
    echo -e "  ${GREEN}✓${NC} Removed VoiceOverlay.qml"
fi

# Remove voice engine
if [ -d "$HOME/.config/hypr/voice-engine" ]; then
    rm -rf "$HOME/.config/hypr/voice-engine"
    echo -e "  ${GREEN}✓${NC} Removed voice-engine"
fi

# Remove HyprVoice scripts
for script in voice-assistant.sh text-to-speech.sh start-voice-listener.sh play-music.sh; do
    if [ -f "$HOME/.config/hypr/scripts/$script" ]; then
        rm -f "$HOME/.config/hypr/scripts/$script"
    fi
done
echo -e "  ${GREEN}✓${NC} Removed voice scripts"

# Remove config
if [ -d "$HOME/.config/hypr/voice-assistant" ]; then
    rm -rf "$HOME/.config/hypr/voice-assistant"
    echo -e "  ${GREEN}✓${NC} Removed voice-assistant config"
fi

# Remove temp files
rm -f /tmp/voice_active 2>/dev/null
rm -f /tmp/voice_language 2>/dev/null
rm -f /tmp/voice-listener.log 2>/dev/null
rm -f /tmp/voice_command.wav 2>/dev/null
echo -e "  ${GREEN}✓${NC} Removed temp files"

echo ""

# ─────────────────────────────────────────
# STEP 4: REMOVE AUTOSTART
# ─────────────────────────────────────────

echo -e "${BLUE}[4/4] Removing autostart entry...${NC}"
echo ""

HYPR_LOCATIONS=(
    "$HOME/.config/hypr/hyprland/execs.conf"
    "$HOME/.config/hypr/execs.conf"
    "$HOME/.config/hypr/hyprland.conf"
)

for conf in "${HYPR_LOCATIONS[@]}"; do
    if [ -f "$conf" ]; then
        if grep -q "start-voice-listener.sh" "$conf" 2>/dev/null; then
            sed -i '/start-voice-listener\.sh/d' "$conf"
            sed -i '/# HyprVoice/d' "$conf"
            echo -e "  ${GREEN}✓${NC} Removed autostart from: $conf"
        fi
    fi
done

echo ""

# ─────────────────────────────────────────
# OPTIONAL: REMOVE PIPER TTS
# ─────────────────────────────────────────

echo -e "${CYAN}┌────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│    Optional: Remove Piper TTS          │${NC}"
echo -e "${CYAN}└────────────────────────────────────────┘${NC}"
echo ""
echo -e "Piper TTS uses about 200MB for voice models."
echo ""

read -p "Remove Piper TTS and voice models? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "$HOME/.local/share/piper" ]; then
        rm -rf "$HOME/.local/share/piper"
        echo -e "  ${GREEN}✓${NC} Removed Piper TTS"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Piper TTS kept at: ~/.local/share/piper"
fi

echo ""

# ─────────────────────────────────────────
# COMPLETE
# ─────────────────────────────────────────

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║           Uninstall Complete                               ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo ""
echo -e "  • ${CYAN}Ai.qml was NOT removed${NC} (it's part of illogical-impulse)"
echo -e "    To restore the original, get it from:"
echo -e "    ${BLUE}https://github.com/end-4/dots-hyprland${NC}"
echo ""
echo -e "  • ${CYAN}System packages were NOT removed${NC} (may be used by others)"
echo -e "    To remove manually:"
echo -e "    ${BLUE}sudo pacman -Rs python-pyaudio portaudio${NC}"
echo ""
echo -e "  • ${CYAN}Backup saved at:${NC}"
echo -e "    ${BLUE}$BACKUP_DIR${NC}"
echo ""
echo -e "${YELLOW}Restart Hyprland for changes to take effect.${NC}"
echo ""