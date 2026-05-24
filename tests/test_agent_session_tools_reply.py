import pytest
from unittest.mock import patch
from hyprvoice.core.session import ConversationSession
from hyprvoice.core.agent import reply_with_tools_in_session

@patch("hyprvoice.core.agent.run_single_tool_turn_with_followup")
@patch("hyprvoice.core.agent.build_system_prompt", return_value="auto prompt")
@patch("hyprvoice.core.agent.detect_environment", return_value={})
def test_sets_system_prompt_if_missing(mock_env, mock_build, mock_turn):
    mock_turn.return_value = {
        "ok": True, "mode": "assistant_reply",
        "assistant_content": "Sure thing.", "error": None
    }
    session = ConversationSession()
    session.add_user_message("hello")

    reply_with_tools_in_session(session, {})

    assert session._system_prompt == "auto prompt"
    mock_build.assert_called_once()

@patch("hyprvoice.core.agent.run_single_tool_turn_with_followup")
def test_does_not_overwrite_existing_prompt(mock_turn):
    mock_turn.return_value = {
        "ok": True, "mode": "assistant_reply",
        "assistant_content": "hi", "error": None
    }
    session = ConversationSession(system_prompt="keep me")
    session.add_user_message("test")

    reply_with_tools_in_session(session, {})

    assert session._system_prompt == "keep me"

@patch("hyprvoice.core.agent.run_single_tool_turn_with_followup")
def test_tool_followup_appends_reply(mock_turn):
    mock_turn.return_value = {
        "ok": True, "mode": "tool_followup",
        "assistant_content": "Done, opened YouTube.", "error": None,
        "tool_name": "open_url", "tool_args": {"url": "https://youtube.com"}
    }
    session = ConversationSession(system_prompt="sys")
    session.add_user_message("open youtube")

    res = reply_with_tools_in_session(session, {})

    assert res["ok"]
    assert res["mode"] == "tool_followup"
    assert session.message_count() == 2
    assert session.last_assistant_message() == "Done, opened YouTube."

@patch("hyprvoice.core.agent.run_single_tool_turn_with_followup")
def test_plain_reply_appends(mock_turn):
    mock_turn.return_value = {
        "ok": True, "mode": "assistant_reply",
        "assistant_content": "It is 10 AM.", "error": None
    }
    session = ConversationSession(system_prompt="sys")
    session.add_user_message("what time is it")

    res = reply_with_tools_in_session(session, {})

    assert res["ok"]
    assert session.last_assistant_message() == "It is 10 AM."

@patch("hyprvoice.core.agent.run_single_tool_turn_with_followup")
def test_failure_does_not_append(mock_turn):
    mock_turn.return_value = {
        "ok": False, "mode": "tool_call",
        "assistant_content": "", "error": "rate limit hit"
    }
    session = ConversationSession(system_prompt="sys")
    session.add_user_message("do something")

    res = reply_with_tools_in_session(session, {})

    assert not res["ok"]
    assert session.message_count() == 1

@patch("hyprvoice.core.agent.run_single_tool_turn_with_followup")
def test_empty_content_not_appended(mock_turn):
    mock_turn.return_value = {
        "ok": True, "mode": "assistant_reply",
        "assistant_content": "  ", "error": None
    }
    session = ConversationSession(system_prompt="sys")
    session.add_user_message("test")

    reply_with_tools_in_session(session, {})

    assert session.message_count() == 1

@patch("hyprvoice.core.agent.run_single_tool_turn_with_followup")
def test_passes_empty_system_prompt(mock_turn):
    mock_turn.return_value = {
        "ok": True, "mode": "assistant_reply",
        "assistant_content": "hi", "error": None
    }
    session = ConversationSession(system_prompt="already set")
    session.add_user_message("yo")

    reply_with_tools_in_session(session, {"llm": {}})

    _, kwargs = mock_turn.call_args
    assert kwargs["system_prompt"] == ""

def test_empty_session_returns_error():
    session = ConversationSession()
    res = reply_with_tools_in_session(session, {})
    assert not res["ok"]
    assert "no messages" in res["error"].lower()
