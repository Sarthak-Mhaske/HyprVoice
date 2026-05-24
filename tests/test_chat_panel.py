import pytest
from hyprvoice.ui.chat_panel import (
    check_chat_panel_dependencies,
    chat_panel_available,
    format_panel_header_title,
    format_panel_header_status,
    format_panel_header_substatus,
    should_panel_input_be_enabled,
    format_message_row,
    session_messages_to_rows,
    normalize_input_text,
    format_submit_state_message,
    derive_post_reply_state
)

def test_check_chat_panel_dependencies():
    deps = check_chat_panel_dependencies()
    assert isinstance(deps, dict)
    assert "gi" in deps
    assert "gtk4" in deps

def test_format_panel_header_title():
    assert format_panel_header_title() == "HyprVoice"

def test_format_panel_header_status():
    assert format_panel_header_status({}, is_submitting=True) == "Thinking..."
    assert format_panel_header_status({"state": "thinking"}) == "Thinking..."
    assert format_panel_header_status({"state": "listening"}) == "Listening..."
    assert format_panel_header_status({"state": "idle"}) == "Ready"
    assert format_panel_header_status({}) == "Ready"

def test_format_panel_header_substatus():
    assert format_panel_header_substatus({"state": "thinking", "message": "custom msg"}) == "custom msg"
    assert "Type a message" in format_panel_header_substatus({"state": "idle"})
    assert "listening" in format_panel_header_substatus({"state": "listening"})
    assert "Converting" in format_panel_header_substatus({"state": "transcribing"})
    assert "Working" in format_panel_header_substatus({"state": "thinking"})
    assert "Running" in format_panel_header_substatus({"state": "executing"})
    assert "Replying" in format_panel_header_substatus({"state": "speaking"})
    assert "wrong" in format_panel_header_substatus({"state": "error"})
    assert "Waiting" in format_panel_header_substatus({"state": "idle"}, is_submitting=True)

def test_should_panel_input_be_enabled():
    assert should_panel_input_be_enabled({}, is_submitting=True) is False
    assert should_panel_input_be_enabled({"state": "transcribing"}) is False
    assert should_panel_input_be_enabled({"state": "idle"}) is True
    assert should_panel_input_be_enabled({"state": "speaking"}) is True

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

def test_format_submit_state_message():
    assert format_submit_state_message() == ""

def test_derive_post_reply_state_failure():
    state, message, reset = derive_post_reply_state({"ok": False, "error": "rate limit"})
    assert state == "error"
    assert "rate limit" in message
    assert reset is False

def test_derive_post_reply_state_tool_followup():
    state, message, reset = derive_post_reply_state({
        "ok": True, "mode": "tool_followup",
        "assistant_content": "Opened it",
        "tool_result": {"message": "URL opened"}
    })
    assert state == "executing"
    assert "URL opened" in message
    assert reset is True

def test_derive_post_reply_state_tool_call():
    state, message, reset = derive_post_reply_state({
        "ok": True, "mode": "tool_call",
        "tool_result": {"message": "Notified"}
    })
    assert state == "executing"
    assert "Notified" in message
    assert reset is True

def test_derive_post_reply_state_assistant_reply():
    state, message, reset = derive_post_reply_state({
        "ok": True, "mode": "assistant_reply",
        "assistant_content": "Hello"
    })
    assert state == "idle"
    assert reset is False

def test_derive_post_reply_state_fallback():
    state, message, reset = derive_post_reply_state({"ok": True})
    assert state == "idle"
    assert reset is False

def test_should_refresh_for_revision():
    from hyprvoice.ui.chat_panel import should_refresh_for_revision
    assert should_refresh_for_revision(0, 1) is True
    assert should_refresh_for_revision(2, 2) is False
    assert should_refresh_for_revision(5, 3) is False
