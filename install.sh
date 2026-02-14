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

# Flags
SKIP_BAR=false
SKIP_DEPS=false
UNATTENDED=false

# Global: Compatible Python path (set in Step 6, used in Step 7)
PYTHON_BIN=""

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-bar)
            SKIP_BAR=true
            shift
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --unattended|-y)
            UNATTENDED=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --skip-bar        Skip installing custom bar (BarContent.qml)"
            echo "  --skip-deps       Skip installing system dependencies"
            echo "  --unattended, -y  Run without prompts"
            echo "  --help, -h        Show this help"
            echo ""
            exit 0
            ;;
    esac
done

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

echo -e "${BLUE}[1/10] Checking system requirements...${NC}"
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

if [ "$SKIP_DEPS" != true ]; then
    echo -e "${BLUE}[2/10] Installing system packages...${NC}"
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
        pyenv
        base-devel
        openssl
        zlib
        xz
        tk
    )

    echo -e "  ${YELLOW}Installing dependencies...${NC}"

    sudo pacman -S --needed --noconfirm "${PACKAGES[@]}" > /dev/null 2>&1 || {
        echo -e "  ${YELLOW}⚠${NC} Some packages may have failed, continuing..."
    }

    echo -e "  ${GREEN}✓${NC} System packages installed"
    echo ""
else
    echo -e "${BLUE}[2/10] Skipping system packages (--skip-deps)${NC}"
    echo ""
fi

# ─────────────────────────────────────────
# STEP 3: INSTALL AUR PACKAGES
# ─────────────────────────────────────────

if [ "$SKIP_DEPS" != true ]; then
    echo -e "${BLUE}[3/10] Installing AUR packages...${NC}"
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
else
    echo -e "${BLUE}[3/10] Skipping AUR packages (--skip-deps)${NC}"
    echo ""
fi

# ─────────────────────────────────────────
# STEP 4: CREATE BACKUP
# ─────────────────────────────────────────

echo -e "${BLUE}[4/10] Creating backup of existing files...${NC}"
echo ""

BACKUP_DIR="$HOME/.config/hyprvoice-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

backup_file() {
    local file="$1"
    local name=$(basename "$file")
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/$name"
        echo -e "  ${GREEN}✓${NC} Backed up $name"
    fi
}

backup_file "$HOME/.config/quickshell/ii/services/Ai.qml"
backup_file "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml"

if [ "$SKIP_BAR" != true ]; then
    backup_file "$HOME/.config/quickshell/ii/modules/ii/bar/BarContent.qml"
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

echo -e "${BLUE}[5/10] Installing HyprVoice files...${NC}"
echo ""

mkdir -p "$HOME/.config/quickshell/ii/services"
mkdir -p "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay"
mkdir -p "$HOME/.config/quickshell/ii/modules/ii/bar"
mkdir -p "$HOME/.config/hypr/scripts"
mkdir -p "$HOME/.config/hypr/voice-engine/models"
mkdir -p "$HOME/.config/hypr/voice-assistant"

cp "$SCRIPT_DIR/config/quickshell/ii/services/Ai.qml" \
    "$HOME/.config/quickshell/ii/services/"
echo -e "  ${GREEN}✓${NC} Installed Ai.qml"

if [ -d "$SCRIPT_DIR/config/quickshell/ii/services/ai" ]; then
    echo "  → Installing AI API strategies..."
    mkdir -p "$HOME/.config/quickshell/ii/services/ai"
    cp -r "$SCRIPT_DIR/config/quickshell/ii/services/ai/"* \
        "$HOME/.config/quickshell/ii/services/ai/"
fi

cp "$SCRIPT_DIR/config/quickshell/ii/modules/ii/voiceOverlay/VoiceOverlay.qml" \
    "$HOME/.config/quickshell/ii/modules/ii/voiceOverlay/"
echo -e "  ${GREEN}✓${NC} Installed VoiceOverlay.qml"

if [ "$SKIP_BAR" != true ]; then
    if [ -f "$SCRIPT_DIR/config/quickshell/ii/modules/ii/bar/BarContent.qml" ]; then
        cp "$SCRIPT_DIR/config/quickshell/ii/modules/ii/bar/BarContent.qml" \
            "$HOME/.config/quickshell/ii/modules/ii/bar/"
        echo -e "  ${GREEN}✓${NC} Installed BarContent.qml (notch design)"
    else
        echo -e "  ${YELLOW}⚠${NC} BarContent.qml not found in repo"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Skipped BarContent.qml (--skip-bar)"
fi

cp "$SCRIPT_DIR/config/hypr/scripts/"*.sh "$HOME/.config/hypr/scripts/"
chmod +x "$HOME/.config/hypr/scripts/"*.sh
echo -e "  ${GREEN}✓${NC} Installed voice scripts"

cp "$SCRIPT_DIR/config/hypr/voice-engine/listen.py" "$HOME/.config/hypr/voice-engine/"
echo -e "  ${GREEN}✓${NC} Installed listen.py"

cp "$SCRIPT_DIR/config/hypr/voice-assistant/music-player.conf" "$HOME/.config/hypr/voice-assistant/"
echo -e "  ${GREEN}✓${NC} Installed music-player.conf"

echo ""

# ─────────────────────────────────────────
# STEP 6: SETUP PYTHON ENVIRONMENT
# ─────────────────────────────────────────

echo -e "${BLUE}[6/10] Setting up Python environment...${NC}"
echo ""

VOICE_ENGINE_DIR="$HOME/.config/hypr/voice-engine"
VENV_DIR="$VOICE_ENGINE_DIR/venv"

cd "$VOICE_ENGINE_DIR"

# Find compatible Python version (3.10, 3.11, or 3.12)
# onnxruntime doesn't support 3.13+ yet

# Method 1: Check system Python versions
for py in python3.12 python3.11 python3.10; do
    if command -v "$py" &> /dev/null; then
        PYTHON_BIN="$py"
        echo -e "  ${GREEN}✓${NC} Found compatible Python: $py"
        break
    fi
done

# Method 2: Check pyenv installations
if [ -z "$PYTHON_BIN" ]; then
    for ver in 3.12.8 3.12.7 3.12.6 3.12.5 3.12.4 3.12.3 3.12.2 3.12.1 3.12.0 3.11.10 3.11.9 3.10.15 3.10.14; do
        PYENV_PY="$HOME/.pyenv/versions/$ver/bin/python"
        if [ -f "$PYENV_PY" ]; then
            PYTHON_BIN="$PYENV_PY"
            echo -e "  ${GREEN}✓${NC} Found pyenv Python: $ver"
            break
        fi
    done
fi

# Method 3: Check if system python is compatible
if [ -z "$PYTHON_BIN" ] && command -v python &> /dev/null; then
    PY_VERSION=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
    if [[ "$PY_VERSION" =~ ^3\.(10|11|12)$ ]]; then
        PYTHON_BIN="python"
        echo -e "  ${GREEN}✓${NC} Using system Python $PY_VERSION"
    fi
fi

# If no compatible Python found, try to install via pyenv
if [ -z "$PYTHON_BIN" ]; then
    echo -e "  ${YELLOW}⚠${NC} No compatible Python found (need 3.10-3.12)"
    echo -e "  ${YELLOW}→${NC} Attempting to install Python 3.12 via pyenv..."
    
    if command -v pyenv &> /dev/null; then
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init --path 2>/dev/null)" || true
        
        echo -e "  ${YELLOW}→${NC} Installing Python 3.12.8 (this may take 5-10 minutes)..."
        if pyenv install 3.12.8 2>/dev/null; then
            PYTHON_BIN="$HOME/.pyenv/versions/3.12.8/bin/python"
            echo -e "  ${GREEN}✓${NC} Python 3.12.8 installed via pyenv"
        else
            echo -e "  ${RED}✗${NC} Failed to install Python via pyenv"
        fi
    fi
fi

# Final check
if [ -z "$PYTHON_BIN" ]; then
    echo -e "  ${RED}✗${NC} Could not find or install compatible Python"
    echo ""
    echo -e "  ${YELLOW}Your system Python is too new for onnxruntime${NC}"
    echo ""
    echo -e "  ${CYAN}Manual fix:${NC}"
    echo -e "    1. Install pyenv: sudo pacman -S pyenv"
    echo -e "    2. Install Python 3.12: pyenv install 3.12.8"
    echo -e "    3. Re-run this installer"
    echo ""
    exit 1
fi

# Remove old venv if exists
if [ -d "$VENV_DIR" ]; then
    echo -e "  ${YELLOW}→${NC} Removing old virtual environment..."
    rm -rf "$VENV_DIR"
fi

# Create fresh venv
echo -e "  ${YELLOW}→${NC} Creating virtual environment..."
"$PYTHON_BIN" -m venv "$VENV_DIR"

# Upgrade pip
echo -e "  ${YELLOW}→${NC} Upgrading pip..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip setuptools wheel

# Install dependencies in order
echo -e "  ${YELLOW}→${NC} Installing numpy..."
"$VENV_DIR/bin/pip" install --quiet "numpy<2.0.0"

echo -e "  ${YELLOW}→${NC} Installing onnxruntime..."
if ! "$VENV_DIR/bin/pip" install --quiet onnxruntime 2>&1; then
    echo -e "  ${RED}✗${NC} Failed to install onnxruntime"
    exit 1
fi

echo -e "  ${YELLOW}→${NC} Installing openwakeword..."
"$VENV_DIR/bin/pip" install --quiet openwakeword

echo -e "  ${YELLOW}→${NC} Installing pyaudio..."
"$VENV_DIR/bin/pip" install --quiet pyaudio

# Verify
if "$VENV_DIR/bin/python" -c "import openwakeword; import pyaudio; import numpy" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Python environment ready"
else
    echo -e "  ${RED}✗${NC} Python environment setup failed"
    exit 1
fi

echo ""

# ─────────────────────────────────────────
# STEP 7: SETUP PIPER TTS
# ─────────────────────────────────────────

echo -e "${BLUE}[7/10] Setting up Piper TTS...${NC}"
echo ""

PIPER_DIR="$HOME/.local/share/piper"
PIPER_VENV="$PIPER_DIR/venv"

mkdir -p "$PIPER_DIR/models"
cd "$PIPER_DIR"

# Remove old venv if exists
if [ -d "$PIPER_VENV" ]; then
    echo -e "  ${YELLOW}→${NC} Removing old Piper virtual environment..."
    rm -rf "$PIPER_VENV"
fi

# Create venv with same compatible Python
echo -e "  ${YELLOW}→${NC} Creating Piper virtual environment..."
"$PYTHON_BIN" -m venv "$PIPER_VENV"

# Upgrade pip
echo -e "  ${YELLOW}→${NC} Upgrading pip..."
"$PIPER_VENV/bin/pip" install --quiet --upgrade pip setuptools wheel

# Install dependencies in order
echo -e "  ${YELLOW}→${NC} Installing numpy..."
"$PIPER_VENV/bin/pip" install --quiet "numpy<2.0.0"

echo -e "  ${YELLOW}→${NC} Installing onnxruntime..."
"$PIPER_VENV/bin/pip" install --quiet onnxruntime

echo -e "  ${YELLOW}→${NC} Installing piper-tts..."
if "$PIPER_VENV/bin/pip" install --quiet piper-tts 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Piper TTS installed"
else
    echo -e "  ${YELLOW}→${NC} Retrying with --no-deps..."
    "$PIPER_VENV/bin/pip" install --quiet --no-deps piper-tts
    echo -e "  ${GREEN}✓${NC} Piper TTS installed"
fi

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

echo -e "${BLUE}[8/10] Configuring autostart...${NC}"
echo ""

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
    echo -e "    ${YELLOW}Add this manually:${NC}"
    echo -e "    ${CYAN}exec-once = setsid -f bash \$HOME/.config/hypr/scripts/start-voice-listener.sh${NC}"
fi

echo ""

# ─────────────────────────────────────────
# STEP 9: API KEY SETUP
# ─────────────────────────────────────────

echo -e "${BLUE}[9/10] API Key configuration...${NC}"
echo ""

echo -e "${CYAN}┌────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│         Groq API Key Setup             │${NC}"
echo -e "${CYAN}└────────────────────────────────────────┘${NC}"
echo ""
echo -e "HyprVoice needs a Groq API key (free tier available)"
echo ""
echo -e "  1. Sign up at: ${BLUE}https://console.groq.com${NC}"
echo -e "  2. Go to API Keys → Create new key"
echo ""

if [ "$UNATTENDED" != true ]; then
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
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Unattended mode - skipping API key setup"
fi

echo ""

# ─────────────────────────────────────────
# STEP 10: FINAL
# ─────────────────────────────────────────

echo -e "${BLUE}[10/10] Final setup...${NC}"
echo ""

echo -e "For best results, update your AI system prompt."
echo -e "Find it at: ${CYAN}$SCRIPT_DIR/docs/SYSTEM_PROMPT.md${NC}"
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
echo -e "  3. Try: ${CYAN}\"Alexa, set volume to 50\"${NC}"
echo ""
echo -e "${BLUE}Quick Test:${NC}"
echo -e "  ${CYAN}bash ~/.config/hypr/scripts/start-voice-listener.sh${NC}"
echo -e "  ${CYAN}tail -f /tmp/voice-listener.log${NC}"
echo ""
echo -e "${BLUE}Backup:${NC} ${CYAN}$BACKUP_DIR${NC}"
echo ""
