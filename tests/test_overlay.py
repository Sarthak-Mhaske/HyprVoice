import pytest
from hyprvoice.ui.overlay import check_overlay_dependencies, overlay_available, format_overlay_text

def test_check_overlay_dependencies():
    deps = check_overlay_dependencies()
    assert isinstance(deps, dict)
    assert "gi" in deps
    assert "gtk4" in deps

def test_format_overlay_text():
    res = format_overlay_text({"state": "thinking", "message": "hmm"})
    assert "HyprVoice" in res
    assert "State: thinking" in res
    assert "Message: hmm" in res
    
    res = format_overlay_text({"state": "idle", "message": ""})
    assert "HyprVoice" in res
    assert "State: idle" in res
    assert "Message" not in res
