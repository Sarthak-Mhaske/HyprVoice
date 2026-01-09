#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# HyprVoice Installer v1.0.0
# Voice Control for Hyprland
# https://github.com/Sarthak-Mhaske/HyprVoice
# ═══════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─────────────────────────────────────────
# HEADER
# ─────────────────────────────────────────

clear
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}║   ${BLUE}██╗  ██╗██╗   ██╗██████╗ ██████╗ ${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}║   ${BLUE}██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}║   ${BLUE}███████║ ╚████╔╝ ██████╔╝██████╔╝${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}║   ${BLUE}██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}║   ${BLUE}██║  ██║   ██║   ██║     ██║  ██║${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}║   ${BLUE}╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝${NC}  ${GREEN}VOICE${NC}               ${CYAN}║${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}║            Voice Control for Hyprland v1.0.0               ║${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────
# STEP 1: SYSTEM CHECKS
# ─────────────────────────────────────────

echo -e "${BLUE}[1/9] Checking system requirements...${NC}"
echo ""

# Check Arch-based system
if ! command -v pacman &> /dev/null; then
    echo -e "  ${RED}✗${NC} Not an Arch-based system"
    echo -e "    ${YELLOW}HyprVoice requires Arch Linux or an Arch-based distro${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Arch-based system detected"

# Check Hyprland
if ! command -v hyprctl &> /dev/null; then
    echo -e "  ${RED}✗${NC} Hyprland not installed"
    echo -e "    ${YELLOW}Install Hyprland first: https://hyprland.org${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Hyprland detected"

# Check Quickshell
QS_CMD=""
if command -v qs &> /dev/null; then
    QS_CMD="qs"
elif command -v quickshell &> /dev/null; then
    QS_CMD="quickshell"
fi

if [ -z "$QS_CMD" ]; then
    echo -e "  ${RED}✗${NC} Quickshell not installed"
    echo -e "    ${YELLOW}Install with: paru -S quickshell-git${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Quickshell detected (${QS_CMD})"

# Check illogical-impulse config
if [ ! -d "$HOME/.config/quickshell/ii" ]; then
    echo -e "  ${RED}✗${NC} illogical-impulse config not found"
    echo -e "    ${YELLOW}HyprVoice requires End-4's illogical-impulse configuration${NC}"
    echo -e "    ${YELLOW}Get it from: https://github.com/end-4/dots-hyprland${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} illogical-impulse config detected"

# Check AUR helper
AUR_HELPER=""
if command -v paru &> /dev/null; then
    AUR_HELPER="paru"
elif command -v yay &> /dev/null; then
    AUR_HELPER="yay"
fi

if [ -z "$AUR_HELPER" ]; then
    echo -e "  ${RED}✗${NC} No AUR helper found"
    echo -e "    ${YELLOW}Install paru or yay first${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} AUR helper detected (${AUR_HELPER})"

# Check config folder exists in repo
if [ ! -d "$SCRIPT_DIR/config" ]; then
    echo -e "  ${RED}✗${NC} Config directory not found"
    echo -e "    ${YELLOW}Make sure you're running install.sh from the HyprVoice directory${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} HyprVoice files found"

echo ""

# ─────────────────────────────────────────
# STEP 2: INSTALL SYSTEM PACKAGES
# ─────────────────────────────────────────

echo -e "${BLUE}[2/9] Installing system packages...${NC}"
echo ""

PACKAGES=(
    python
    python-pyaudio
    portaudio
    jq
    curl
    libnotify
    libsecret
    playerctl
    brightnessctl
    wl-clipboard
    pipewire
    wireplumber
)

echo -e "  ${YELLOW}Installing: ${PACKAGES[*]}${NC}"
echo ""

sudo pacman -S --needed --noconfirm "${PACKAGES[@]}" > /dev/null 2>&1 || {
    echo -e "  ${RED}✗${NC} Failed to install system packages"
    echo -e "    ${YELLOW}Try running: sudo pacman -S --needed ${PACKAGES[*]}${NC}"
    exit 1
}

echo -e "  ${GREEN}✓${NC} System packages installed"
echo ""

# ─────────────────────────────────────────
# STEP 3: INSTALL AUR PACKAGES
# ─────────────────────────────────────────

echo -e "${BLUE}[3/9] Installing AUR packages...${NC}"
echo ""

AUR_PACKAGES=(
    grimblast-git
    yt-dlp
)

for pkg in "${AUR_PACKAGES[@]}"; do
    if pacman -Qi "$pkg" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $pkg already installed"
    else
        echo -e "  ${YELLOW}→${NC} Installing $pkg..."
        $AUR_HELPER -S --noconfirm "$pkg" > /dev/null 2>&1 || {
            echo -e "  ${YELLOW}⚠${NC} Failed to install $pkg (install manually later)"
        }
    fi
done

echo ""

# ─────────────────────────────────────────
# STEP 4: CREATE BACKUP
# ─────────────────────────────────────────

echo -e "${BLUE}[4/9] Creating backup of existing files...${NC}"
echo ""

BACKUP_DIR="$HOME/.config/hyprvoice-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup existing files
if [ -f "$HOME/.config/quickshell/ii/services/Ai.qml" ]; then
    cp "$HOME/.config/quickshell/ii/services/Ai.qml" "$BACKUP_DIR/"
    echo -e "  ${GREEN}✓${NC} Backed up Ai.qml"
fi

if [ -f "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml" ]; then
    cp "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml" "$BACKUP_DIR/"
    echo -e "  ${GREEN}✓${NC} Backed up VoiceOverlay.qml"
fi

if [ -d "$HOME/.config/hypr/voice-engine" ]; then
    cp -r "$HOME/.config/hypr/voice-engine" "$BACKUP_DIR/"
    echo -e "  ${GREEN}✓${NC} Backed up voice-engine"
fi

echo -e "  ${GREEN}✓${NC} Backup saved to: $BACKUP_DIR"
echo ""

# ─────────────────────────────────────────
# STEP 5: INSTALL HYPRVOICE FILES
# ─────────────────────────────────────────

echo -e "${BLUE}[5/9] Installing HyprVoice files...${NC}"
echo ""

# Create directories
mkdir -p "$HOME/.config/quickshell/ii/services"
mkdir -p "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay"
mkdir -p "$HOME/.config/hypr/scripts"
mkdir -p "$HOME/.config/hypr/voice-engine/models"
mkdir -p "$HOME/.config/hypr/voice-assistant"

# Copy Quickshell files
cp "$SCRIPT_DIR/config/quickshell/ii/services/Ai.qml" \
    "$HOME/.config/quickshell/ii/services/"
echo -e "  ${GREEN}✓${NC} Installed Ai.qml"

cp "$SCRIPT_DIR/config/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml" \
    "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay/"
echo -e "  ${GREEN}✓${NC} Installed VoiceOverlay.qml"

# Copy scripts
cp "$SCRIPT_DIR/config/hypr/scripts/"*.sh "$HOME/.config/hypr/scripts/"
chmod +x "$HOME/.config/hypr/scripts/"*.sh
echo -e "  ${GREEN}✓${NC} Installed voice scripts"

# Copy voice engine
cp "$SCRIPT_DIR/config/hypr/voice-engine/listen.py" "$HOME/.config/hypr/voice-engine/"
echo -e "  ${GREEN}✓${NC} Installed listen.py"

# Copy config
cp "$SCRIPT_DIR/config/hypr/voice-assistant/music-player.conf" "$HOME/.config/hypr/voice-assistant/"
echo -e "  ${GREEN}✓${NC} Installed music-player.conf"

echo ""

# ─────────────────────────────────────────
# STEP 6: SETUP PYTHON ENVIRONMENT
# ─────────────────────────────────────────

echo -e "${BLUE}[6/9] Setting up Python environment...${NC}"
echo ""

cd "$HOME/.config/hypr/voice-engine"

# Create venv if needed
if [ ! -d "venv" ]; then
    echo -e "  ${YELLOW}→${NC} Creating virtual environment..."
    python -m venv venv
fi

# Install packages
echo -e "  ${YELLOW}→${NC} Installing Python packages..."
./venv/bin/pip install --quiet --upgrade pip
./venv/bin/pip install --quiet openwakeword pyaudio numpy

echo -e "  ${GREEN}✓${NC} Python environment ready"
echo ""

# ─────────────────────────────────────────
# STEP 7: SETUP PIPER TTS
# ─────────────────────────────────────────

echo -e "${BLUE}[7/9] Setting up Piper TTS...${NC}"
echo ""

mkdir -p "$HOME/.local/share/piper/models"
cd "$HOME/.local/share/piper"

# Create venv if needed
if [ ! -d "venv" ]; then
    echo -e "  ${YELLOW}→${NC} Creating Piper virtual environment..."
    python -m venv venv
fi

# Install piper
echo -e "  ${YELLOW}→${NC} Installing piper-tts..."
./venv/bin/pip install --quiet --upgrade pip
./venv/bin/pip install --quiet piper-tts

echo -e "  ${GREEN}✓${NC} Piper TTS installed"

# Download English model
if [ ! -f "models/en_US-lessac-medium.onnx" ]; then
    echo -e "  ${YELLOW}→${NC} Downloading English voice model..."
    curl -sL "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx" \
        -o "models/en_US-lessac-medium.onnx"
    curl -sL "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json" \
        -o "models/en_US-lessac-medium.onnx.json"
    echo -e "  ${GREEN}✓${NC} English voice model downloaded"
else
    echo -e "  ${GREEN}✓${NC} English voice model exists"
fi

# Download Hindi model
if [ ! -f "models/hi_IN-pratham-medium.onnx" ]; then
    echo -e "  ${YELLOW}→${NC} Downloading Hindi voice model..."
    curl -sL "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/hi/hi_IN/pratham/medium/hi_IN-pratham-medium.onnx" \
        -o "models/hi_IN-pratham-medium.onnx"
    curl -sL "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/hi/hi_IN/pratham/medium/hi_IN-pratham-medium.onnx.json" \
        -o "models/hi_IN-pratham-medium.onnx.json"
    echo -e "  ${GREEN}✓${NC} Hindi voice model downloaded"
else
    echo -e "  ${GREEN}✓${NC} Hindi voice model exists"
fi

echo ""

# ─────────────────────────────────────────
# STEP 8: CONFIGURE AUTOSTART
# ─────────────────────────────────────────

echo -e "${BLUE}[8/9] Configuring autostart...${NC}"
echo ""

# Find Hyprland config
HYPR_CONF=""
HYPR_LOCATIONS=(
    "$HOME/.config/hypr/hyprland/execs.conf"
    "$HOME/.config/hypr/execs.conf"
    "$HOME/.config/hypr/hyprland.conf"
)

for loc in "${HYPR_LOCATIONS[@]}"; do
    if [ -f "$loc" ]; then
        HYPR_CONF="$loc"
        break
    fi
done

if [ -n "$HYPR_CONF" ]; then
    if grep -q "start-voice-listener.sh" "$HYPR_CONF" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Autostart already configured"
    else
        echo "" >> "$HYPR_CONF"
        echo "# HyprVoice - Voice Assistant" >> "$HYPR_CONF"
        echo 'exec-once = setsid -f bash $HOME/.config/hypr/scripts/start-voice-listener.sh' >> "$HYPR_CONF"
        echo -e "  ${GREEN}✓${NC} Autostart added to: $HYPR_CONF"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Could not find Hyprland config"
    echo -e "    ${YELLOW}Add this manually to your Hyprland config:${NC}"
    echo -e "    ${CYAN}exec-once = setsid -f bash \$HOME/.config/hypr/scripts/start-voice-listener.sh${NC}"
fi

echo ""

# ─────────────────────────────────────────
# STEP 9: API KEY & SYSTEM PROMPT
# ─────────────────────────────────────────

echo -e "${BLUE}[9/9] Final configuration...${NC}"
echo ""

# API Key
echo -e "${CYAN}┌────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│         Groq API Key Setup             │${NC}"
echo -e "${CYAN}└────────────────────────────────────────┘${NC}"
echo ""
echo -e "HyprVoice needs a Groq API key (free tier available)"
echo ""
echo -e "  1. Sign up at: ${BLUE}https://console.groq.com${NC}"
echo -e "  2. Go to API Keys → Create new key"
echo ""

read -p "Do you have a Groq API key? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    read -s -p "Enter your Groq API key (hidden): " GROQ_KEY
    echo ""
    
    if [ -n "$GROQ_KEY" ]; then
        echo "{\"apiKeys\": {\"groq\": \"$GROQ_KEY\"}}" | \
            secret-tool store --label='illogical-impulse' application illogical-impulse 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} API key stored securely" || \
            echo -e "  ${YELLOW}⚠${NC} Failed to store key (add manually later)"
    fi
else
    echo ""
    echo -e "  ${YELLOW}⚠${NC} Skipped. Add your key later with:"
    echo -e "    ${CYAN}secret-tool store --label='illogical-impulse' application illogical-impulse${NC}"
    echo -e "    Then enter: {\"apiKeys\": {\"groq\": \"YOUR_KEY\"}}${NC}"
fi

echo ""

# System Prompt
echo -e "${CYAN}┌────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│       System Prompt Setup              │${NC}"
echo -e "${CYAN}└────────────────────────────────────────┘${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Update your AI system prompt for best results!${NC}"
echo ""
echo -e "The optimized HyprVoice prompt:"
echo -e "  • Improves voice command understanding"
echo -e "  • Supports English, Hindi, and Marathi"
echo -e "  • Uses 42% fewer tokens (saves API costs)"
echo ""
echo -e "${GREEN}Steps to update:${NC}"
echo ""
echo -e "  1. Open the prompt file:"
echo -e "     ${CYAN}$SCRIPT_DIR/docs/SYSTEM_PROMPT.md${NC}"
echo ""
echo -e "  2. Copy the prompt text (between the --- markers)"
echo ""
echo -e "  3. Find your Quickshell AI config and replace the systemPrompt"
echo ""

read -p "Press Enter to continue..."

echo ""

# ─────────────────────────────────────────
# COMPLETE
# ─────────────────────────────────────────

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║          Installation Complete! 🎉                         ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo -e "  1. ${YELLOW}Log out and log back in${NC} (or restart Hyprland)"
echo ""
echo -e "  2. Say ${GREEN}\"Alexa\"${NC} to activate HyprVoice"
echo ""
echo -e "  3. Try these commands:"
echo -e "     • ${CYAN}\"Alexa, set volume to 50\"${NC}"
echo -e "     • ${CYAN}\"Alexa, open Brave\"${NC}"
echo -e "     • ${CYAN}\"Alexa, play Shape of You\"${NC}"
echo -e "     • ${CYAN}\"Alexa, take a screenshot\"${NC}"
echo ""
echo -e "${BLUE}Quick Test (run in Hyprland):${NC}"
echo ""
echo -e "  ${CYAN}bash ~/.config/hypr/scripts/start-voice-listener.sh${NC}"
echo -e "  ${CYAN}tail -f /tmp/voice-listener.log${NC}"
echo ""
echo -e "${BLUE}Troubleshooting:${NC}"
echo ""
echo -e "  • Check listener: ${CYAN}pgrep -f listen.py${NC}"
echo -e "  • View logs:      ${CYAN}tail -f /tmp/voice-listener.log${NC}"
echo -e "  • Restart:        ${CYAN}pkill -f listen.py && bash ~/.config/hypr/scripts/start-voice-listener.sh${NC}"
echo ""
echo -e "${BLUE}Documentation:${NC} ${CYAN}https://github.com/Sarthak-Mhaske/HyprVoice${NC}"
echo ""
echo -e "${BLUE}Backup Location:${NC} ${CYAN}$BACKUP_DIR${NC}"
echo ""