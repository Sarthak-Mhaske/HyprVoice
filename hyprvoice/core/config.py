from __future__ import annotations

import json
import os
import random
from pathlib import Path
from typing import Any

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

DEFAULT_CONFIG: dict[str, Any] = {
    "groq": {
        "api_keys": [],
        "stt_model": "whisper-large-v3-turbo",
        "translation_model": "whisper-large-v3-turbo",
    },
    "tts": {
        "engine_order": ["edge", "piper"],
        "edge": {
            "enabled": True,
            "binary": "edge-tts",
            "voices": {
                "english": "en-US-AvaMultilingualNeural",
                "hindi": "hi-IN-SwaraNeural",
                "marathi": "hi-IN-SwaraNeural",
            },
        },
        "piper": {
            "enabled": True,
            "binary": "piper",
            "models": {
                "english": "~/.local/share/piper/models/en_US-lessac-medium.onnx",
                "hindi": "~/.local/share/piper/models/hi_IN-pratham-medium.onnx",
                "marathi": "~/.local/share/piper/models/hi_IN-pratham-medium.onnx",
            },
        },
        "playback": {
            "preferred_player": "mpv"
        }
    },
    "wake": {
        "enabled": True,
        "wake_word": "alexa",
        "model_path": "~/.config/hyprvoice/models/alexa.onnx",
        "threshold": 0.5,
        "sample_rate": 16000,
        "frame_length": 1280,
        "cooldown_seconds": 2.0,
    },
    "recording": {
        "backend": "auto",
        "sample_rate": 16000,
        "channels": 1,
        "duration_seconds": 5.0,
        "output_dir": "~/.cache/hyprvoice",
        "filename_prefix": "voice_command",
    },
    "llm": {
        "provider": "groq",
        "model": "llama-3.3-70b-versatile",
        "temperature": 0.3,
        "max_tokens": 512,
        "base_url": "https://api.groq.com/openai/v1/chat/completions",
        "fallback_models": [
            "llama-3.3-70b-versatile",
            "meta-llama/llama-4-scout-17b-16e-instruct",
            "meta-llama/llama-4-maverick-17b-128e-instruct"
        ],
        "retry_on_rate_limit": True,
        "max_attempts": 3
    }
}

def load_config(config_path: str | None = None) -> dict[str, Any]:
    """Load configuration from a YAML or JSON file, falling back to safe defaults."""
    if config_path is None:
        home = Path.home()
        path = home / ".config" / "hyprvoice" / "config.yml"
        if not path.exists():
            path = home / ".config" / "hyprvoice" / "config.json"
    else:
        path = Path(config_path)

    if not path.exists():
        return DEFAULT_CONFIG.copy()

    ext = path.suffix.lower()
    
    try:
        with open(path, "r", encoding="utf-8") as f:
            if ext in (".yml", ".yaml"):
                if not HAS_YAML:
                    raise RuntimeError("PyYAML is not installed. Please install 'PyYAML' to parse YAML configs.")
                data = yaml.safe_load(f)
            else:
                data = json.load(f)
                
            if not isinstance(data, dict):
                return DEFAULT_CONFIG.copy()
                
            # Basic merge with defaults
            cfg = DEFAULT_CONFIG.copy()
            for k, v in data.items():
                if isinstance(v, dict) and k in cfg and isinstance(cfg[k], dict):
                    cfg[k] = {**cfg[k], **v}
                else:
                    cfg[k] = v
            return cfg
            
    except Exception:
        # Gracefully return defaults on parse error
        return DEFAULT_CONFIG.copy()

def get_groq_api_keys(config: dict[str, Any]) -> list[str]:
    """Retrieve and normalize Groq API keys from the configuration."""
    groq_cfg = config.get("groq", {})
    keys = groq_cfg.get("api_keys", [])
    
    if isinstance(keys, str):
        keys = [k.strip() for k in keys.split(",") if k.strip()]
    elif isinstance(keys, list):
        keys = [str(k).strip() for k in keys if str(k).strip()]
    else:
        keys = []
        
    # Check env var fallback if empty
    if not keys and "GROQ_API_KEY" in os.environ:
        val = os.environ["GROQ_API_KEY"].strip()
        if val:
            keys.append(val)
            
    return keys

def pick_groq_api_key(config: dict[str, Any]) -> str | None:
    """Pick a random Groq API key from available keys."""
    keys = get_groq_api_keys(config)
    if not keys:
        return None
    return random.choice(keys)
