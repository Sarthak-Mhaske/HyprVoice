import pytest
from hyprvoice.ui.app import (
    check_ui_app_dependencies,
    ui_app_available,
    build_demo_session_messages,
    build_demo_state_sequence
)

def test_check_ui_app_dependencies():
    deps = check_ui_app_dependencies()
    assert isinstance(deps, dict)
    assert "gi" in deps
    assert "gtk4" in deps

def test_build_demo_session_messages():
    msgs = build_demo_session_messages()
    assert isinstance(msgs, list)
    assert len(msgs) >= 2
    roles = {m["role"] for m in msgs}
    assert "user" in roles
    assert "assistant" in roles
    for m in msgs:
        assert "role" in m
        assert "content" in m
        assert len(m["content"]) > 0

def test_build_demo_state_sequence():
    seq = build_demo_state_sequence()
    assert isinstance(seq, list)
    assert len(seq) >= 3
    states = [s["state"] for s in seq]
    assert "listening" in states
    assert "thinking" in states
    assert "idle" in states
    assert seq[-1]["state"] == "idle"
    for entry in seq:
        assert "state" in entry
        assert "message" in entry
