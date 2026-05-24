from hyprvoice.ui.app import (
    get_ui_application_id,
    build_ui_launch_profile,
    should_overlay_start_hidden,
    should_present_chat_panel_on_launch
)
import pytest

def test_get_ui_application_id():
    app_id = get_ui_application_id()
    assert isinstance(app_id, str)
    assert len(app_id) > 0
    assert "hyprvoice" in app_id

def test_build_ui_launch_profile_demo():
    profile = build_ui_launch_profile("demo")
    assert profile["mode"] == "demo"
    assert profile["show_chat_panel_on_launch"] is True
    assert profile["overlay_starts_hidden"] is True
    assert profile["chat_panel_is_primary"] is True

def test_build_ui_launch_profile_live():
    profile = build_ui_launch_profile("live")
    assert profile["mode"] == "live"
    assert profile["show_chat_panel_on_launch"] is True

def test_build_ui_launch_profile_assistant():
    profile = build_ui_launch_profile("assistant")
    assert profile["mode"] == "assistant"
    assert profile["overlay_starts_hidden"] is True

def test_build_ui_launch_profile_invalid():
    with pytest.raises(ValueError, match="Invalid launch mode"):
        build_ui_launch_profile("invalid_mode")

def test_should_overlay_start_hidden():
    assert should_overlay_start_hidden({"overlay_starts_hidden": True}) is True
    assert should_overlay_start_hidden({"overlay_starts_hidden": False}) is False
    assert should_overlay_start_hidden({}) is True  # default

def test_should_present_chat_panel_on_launch():
    assert should_present_chat_panel_on_launch({"show_chat_panel_on_launch": True}) is True
    assert should_present_chat_panel_on_launch({"show_chat_panel_on_launch": False}) is False
    assert should_present_chat_panel_on_launch({}) is True  # default
