import pytest
from hyprvoice.ui.chat_panel import (
    check_chat_panel_dependencies,
    chat_panel_available,
    format_chat_panel_title,
    format_chat_panel_status,
    format_chat_panel_placeholder
)

def test_check_chat_panel_dependencies():
    deps = check_chat_panel_dependencies()
    assert isinstance(deps, dict)
    assert "gi" in deps
    assert "gtk4" in deps

def test_format_chat_panel_title():
    assert format_chat_panel_title() == "HyprVoice"

def test_format_chat_panel_status():
    assert format_chat_panel_status({"state": "thinking", "message": "custom msg"}) == "custom msg"
    assert format_chat_panel_status({"state": "listening", "message": ""}) == "Listening..."
    assert format_chat_panel_status({"state": "idle", "message": ""}) == "Idle"
    assert format_chat_panel_status({}) == "Idle"

def test_format_chat_panel_placeholder():
    assert "Voice and text" in format_chat_panel_placeholder({"state": "idle"})
    assert "Listening for" in format_chat_panel_placeholder({"state": "listening"})
    assert "thinking" in format_chat_panel_placeholder({"state": "thinking"})
    assert "error" in format_chat_panel_placeholder({"state": "error"}).lower()
    assert "Processing" in format_chat_panel_placeholder({"state": "executing"})
