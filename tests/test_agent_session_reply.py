import pytest
from unittest.mock import patch, MagicMock
from hyprvoice.core.session import ConversationSession
from hyprvoice.core.agent import reply_in_session

@patch("hyprvoice.core.agent.chat_completion_with_fallback")
@patch("hyprvoice.core.agent.build_system_prompt", return_value="sys prompt")
@patch("hyprvoice.core.agent.detect_environment", return_value={})
def test_sets_system_prompt_if_missing(mock_env, mock_build, mock_chat):
    mock_chat.return_value = {"ok": True, "content": "reply text"}
    
    session = ConversationSession()
    session.add_user_message("hello")
    
    res = reply_in_session(session, {})
    
    assert session._system_prompt == "sys prompt"
    assert res["ok"]
    mock_build.assert_called_once()

@patch("hyprvoice.core.agent.chat_completion_with_fallback")
def test_does_not_overwrite_existing_system_prompt(mock_chat):
    mock_chat.return_value = {"ok": True, "content": "reply"}
    
    session = ConversationSession(system_prompt="custom prompt")
    session.add_user_message("hi")
    
    reply_in_session(session, {})
    
    assert session._system_prompt == "custom prompt"

@patch("hyprvoice.core.agent.chat_completion_with_fallback")
def test_appends_assistant_on_success(mock_chat):
    mock_chat.return_value = {"ok": True, "content": "I can help with that."}
    
    session = ConversationSession(system_prompt="sys")
    session.add_user_message("do something")
    
    res = reply_in_session(session, {})
    
    assert res["ok"]
    assert session.message_count() == 2
    assert session.last_assistant_message() == "I can help with that."

@patch("hyprvoice.core.agent.chat_completion_with_fallback")
def test_does_not_append_on_failure(mock_chat):
    mock_chat.return_value = {"ok": False, "content": "", "error": "rate limit"}
    
    session = ConversationSession(system_prompt="sys")
    session.add_user_message("test")
    
    res = reply_in_session(session, {})
    
    assert not res["ok"]
    assert session.message_count() == 1
    assert session.last_assistant_message() is None

@patch("hyprvoice.core.agent.chat_completion_with_fallback")
def test_does_not_append_empty_content(mock_chat):
    mock_chat.return_value = {"ok": True, "content": "  "}
    
    session = ConversationSession(system_prompt="sys")
    session.add_user_message("test")
    
    reply_in_session(session, {})
    
    assert session.message_count() == 1

def test_empty_session_returns_error():
    session = ConversationSession()
    res = reply_in_session(session, {})
    assert not res["ok"]
    assert "no messages" in res["error"].lower()

@patch("hyprvoice.core.agent.chat_completion_with_fallback")
def test_passes_empty_system_prompt_to_avoid_duplication(mock_chat):
    mock_chat.return_value = {"ok": True, "content": "hi"}
    
    session = ConversationSession(system_prompt="my prompt")
    session.add_user_message("test")
    
    reply_in_session(session, {})
    
    call_args = mock_chat.call_args
    assert call_args[1]["system_prompt"] == "" or call_args[0][2] == ""
