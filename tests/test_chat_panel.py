import pytest
from hyprvoice.ui.chat_panel import (
    check_chat_panel_dependencies,
    chat_panel_available,
    format_chat_panel_title,
    format_chat_panel_status,
    format_chat_panel_placeholder,
    format_message_row,
    session_messages_to_rows,
    normalize_input_text
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

def test_format_message_row_user():
    row = format_message_row({"role": "user", "content": " hello "})
    assert row is not None
    assert row["role"] == "user"
    assert row["content"] == "hello"
    assert row["align"] == "end"
    assert row["css_class"] == "message-user"

def test_format_message_row_assistant():
    row = format_message_row({"role": "assistant", "content": "world"})
    assert row is not None
    assert row["role"] == "assistant"
    assert row["align"] == "start"
    assert row["css_class"] == "message-assistant"

def test_format_message_row_invalid_role():
    assert format_message_row({"role": "system", "content": "test"}) is None
    assert format_message_row({"role": "", "content": "test"}) is None

def test_format_message_row_empty_content():
    assert format_message_row({"role": "user", "content": ""}) is None
    assert format_message_row({"role": "user", "content": "  "}) is None

def test_session_messages_to_rows():
    msgs = [
        {"role": "user", "content": "hi"},
        {"role": "assistant", "content": "hello"},
        {"role": "system", "content": "ignored"},
        {"role": "user", "content": ""},
    ]
    rows = session_messages_to_rows(msgs)
    assert len(rows) == 2
    assert rows[0]["role"] == "user"
    assert rows[1]["role"] == "assistant"

def test_session_messages_to_rows_empty():
    assert session_messages_to_rows([]) == []

def test_normalize_input_text():
    assert normalize_input_text("  hello  ") == "hello"
    assert normalize_input_text("") == ""
    assert normalize_input_text("   ") == ""
    assert normalize_input_text("\t\n") == ""
    assert normalize_input_text("hi there") == "hi there"

def test_normalize_input_preserves_inner_whitespace():
    assert normalize_input_text("  hello   world  ") == "hello   world"
