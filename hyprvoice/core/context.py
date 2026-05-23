from __future__ import annotations

import os
import shutil
import subprocess
from typing import Any

def _command_exists(name: str) -> bool:
    """Check if a command exists in PATH."""
    return shutil.which(name) is not None

def _run_command(args: list[str], timeout: float = 2.0) -> subprocess.CompletedProcess[str] | None:
    """Run a subprocess command safely with a timeout."""
    try:
        return subprocess.run(
            args, capture_output=True, text=True, timeout=timeout, check=False
        )
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return None

def detect_os() -> str:
    """Detect the operating system from /etc/os-release."""
    try:
        with open("/etc/os-release", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
    except OSError:
        pass
    return "Linux"

def detect_wm() -> str:
    """Detect the window manager or desktop environment."""
    for env_var in ["XDG_CURRENT_DESKTOP", "DESKTOP_SESSION"]:
        if val := os.environ.get(env_var):
            return val.lower()
            
    # Fallback: check running processes
    wms = ["hyprland", "sway", "i3", "openbox", "gnome-shell", "plasmashell", "xfwm4", "bspwm", "niri"]
    for wm in wms:
        res = _run_command(["pgrep", "-x", wm])
        if res and res.returncode == 0:
            return wm
            
    return "unknown"

def detect_audio_system() -> str:
    """Detect the audio system in use."""
    if _command_exists("wpctl"):
        res = _run_command(["wpctl", "status"])
        if res and res.returncode == 0:
            return "pipewire"
    if _command_exists("pactl"):
        return "pulseaudio"
    if _command_exists("alsamixer"):
        return "alsa"
    return "unknown"

def detect_display_server() -> str:
    """Detect if running under Wayland or X11."""
    if os.environ.get("WAYLAND_DISPLAY"):
        return "wayland"
    if os.environ.get("DISPLAY"):
        return "x11"
    return "unknown"

def detect_browser() -> str:
    """Detect the default or available browser."""
    browsers = [
        "brave", "brave-browser", "google-chrome", "chromium", 
        "firefox", "librewolf", "vivaldi", "opera", "epiphany"
    ]
    for b in browsers:
        if _command_exists(b):
            return b
    return "xdg-open"

def detect_terminal() -> str:
    """Detect an available terminal emulator."""
    terminals = [
        "kitty", "alacritty", "wezterm", "foot", 
        "gnome-terminal", "konsole", "xterm", "tilix"
    ]
    for t in terminals:
        if _command_exists(t):
            return t
    return "xterm"

def detect_screenshot_tool() -> str | None:
    """Detect an available screenshot tool."""
    tools = [
        "grimblast", "grim", "scrot", 
        "gnome-screenshot", "spectacle", "flameshot"
    ]
    for tool in tools:
        if _command_exists(tool):
            return tool
    return None

def detect_package_manager() -> str:
    """Detect the system package manager."""
    pkg_managers = [
        "pacman", "apt", "dnf", "zypper", 
        "emerge", "xbps-install", "apk"
    ]
    for pm in pkg_managers:
        if _command_exists(pm):
            return pm
    return "unknown"

def scan_installed_apps() -> list[str]:
    """Scan for a curated list of installed applications."""
    apps_to_check = [
        "brave", "firefox", "chromium", "spotify", "vlc", "mpv", 
        "code", "codium", "nvim", "vim", "gimp", "discord", 
        "telegram-desktop", "thunar", "dolphin", "nautilus", 
        "kitty", "alacritty", "wezterm"
    ]
    found = []
    for app in apps_to_check:
        if _command_exists(app):
            found.append(app)
    return found

def detect_environment() -> dict[str, Any]:
    """Compile all system environment properties into a dictionary."""
    return {
        "os": detect_os(),
        "wm": detect_wm(),
        "audio": detect_audio_system(),
        "display": detect_display_server(),
        "browser": detect_browser(),
        "terminal": detect_terminal(),
        "screenshot_tool": detect_screenshot_tool(),
        "package_manager": detect_package_manager(),
        "installed_apps": scan_installed_apps(),
    }

def format_context_for_llm(env: dict[str, Any]) -> str:
    """Format the environment dictionary into a concise plain-text string for the LLM."""
    installed_apps = env.get("installed_apps", [])
    apps_str = ", ".join(installed_apps) if installed_apps else "none detected"
    
    lines = [
        "SYSTEM CONTEXT:",
        f"- OS: {env.get('os', 'unknown')}",
        f"- Window Manager: {env.get('wm', 'unknown')}",
        f"- Display Server: {env.get('display', 'unknown')}",
        f"- Audio System: {env.get('audio', 'unknown')}",
        f"- Default Browser: {env.get('browser', 'unknown')}",
        f"- Default Terminal: {env.get('terminal', 'unknown')}",
        f"- Screenshot Tool: {env.get('screenshot_tool', 'unknown')}",
        f"- Package Manager: {env.get('package_manager', 'unknown')}",
        f"- Installed Apps: {apps_str}",
    ]
    return "\n".join(lines)
