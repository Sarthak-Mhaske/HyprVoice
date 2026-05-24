import pytest
from hyprvoice.ui.overlay import (
    check_overlay_dependencies, 
    overlay_available,
    should_overlay_be_visible,
    get_overlay_state_class,
    format_overlay_title,
    format_overlay_message
)

def test_check_overlay_dependencies():
    deps = check_overlay_dependencies()
    assert isinstance(deps, dict)
    assert "gi" in deps
    assert "gtk4" in deps

def test_should_overlay_be_visible():
    assert should_overlay_be_visible({"state": "thinking"}) is True
    assert should_overlay_be_visible({"state": "listening"}) is True
    assert should_overlay_be_visible({"state": "idle"}) is False
    assert should_overlay_be_visible({}) is False

def test_get_overlay_state_class():
    assert get_overlay_state_class({"state": "thinking"}) == "state-thinking"
    assert get_overlay_state_class({"state": "idle"}) == "state-idle"
    assert get_overlay_state_class({}) == "state-idle"

def test_format_overlay_title():
    assert format_overlay_title({"state": "wake_detected"}) == "HyprVoice"
    assert format_overlay_title({"state": "listening"}) == "Listening"
    assert format_overlay_title({"state": "idle"}) == "HyprVoice"
    assert format_overlay_title({}) == "HyprVoice"

def test_format_overlay_message():
    assert format_overlay_message({"state": "thinking", "message": "custom msg"}) == "custom msg"
    assert format_overlay_message({"state": "listening", "message": ""}) == "I'm listening..."
    assert format_overlay_message({"state": "idle", "message": ""}) == ""
    assert format_overlay_message({}) == ""
