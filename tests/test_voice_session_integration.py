import pytest
from unittest.mock import patch, MagicMock
from hyprvoice.core.session import ConversationSession
from hyprvoice.core.voice_pipeline import (
    run_voice_pipeline,
    run_voice_pipeline_from_audio,
    build_voice_user_text,
    should_append_voice_user_message,
    should_append_voice_assistant_message
)
from hyprvoice.core.assistant_loop import HyprVoiceAssistant
from hyprvoice.ui.app import build_live_runtime

def test_build_voice_user_text():
    assert build_voice_user_text({"ok": True, "english_text": "hello"}) == "hello"
    assert build_voice_user_text({"ok": True, "english_text": "", "transcription_text": "hi"}) == "hi"
    assert build_voice_user_text({"ok": False}) == ""
    assert build_voice_user_text({}) == ""

def test_should_append_voice_messages():
    assert should_append_voice_user_message("test") is True
    assert should_append_voice_user_message("  ") is False
    assert should_append_voice_assistant_message("reply") is True
    assert should_append_voice_assistant_message("") is False

@patch("hyprvoice.core.voice_pipeline.record_and_transcribe")
@patch("hyprvoice.core.voice_pipeline.run_single_tool_turn_with_followup")
@patch("hyprvoice.core.voice_pipeline.speak_text")
@patch("hyprvoice.core.voice_pipeline.detect_environment", return_value={})
@patch("hyprvoice.core.voice_pipeline.build_system_prompt", return_value="sys")
def test_voice_pipeline_appends_to_session_on_success(mock_sys, mock_env, mock_tts, mock_agent, mock_stt):
    mock_stt.return_value = {"ok": True, "english_text": "open youtube"}
    mock_agent.return_value = {
        "ok": True,
        "mode": "tool_followup",
        "assistant_content": "Opened YouTube."
    }
    
    session = ConversationSession()
    res = run_voice_pipeline({}, speak_reply=False, session=session)
    
    assert res["ok"]
    assert session.message_count() == 2
    assert session.get_messages()[0]["content"] == "open youtube"
    assert session.get_messages()[1]["content"] == "Opened YouTube."

@patch("hyprvoice.core.voice_pipeline.record_and_transcribe")
def test_voice_pipeline_empty_user_text_no_append(mock_stt):
    mock_stt.return_value = {"ok": True, "english_text": "   "}
    session = ConversationSession()
    
    res = run_voice_pipeline({}, session=session)
    assert not res["ok"]
    assert session.message_count() == 0

@patch("hyprvoice.core.voice_pipeline.record_and_transcribe")
@patch("hyprvoice.core.voice_pipeline.run_single_tool_turn_with_followup")
@patch("hyprvoice.core.voice_pipeline.detect_environment", return_value={})
@patch("hyprvoice.core.voice_pipeline.build_system_prompt", return_value="sys")
def test_voice_pipeline_agent_fails_user_message_still_appended(mock_sys, mock_env, mock_agent, mock_stt):
    mock_stt.return_value = {"ok": True, "english_text": "do something"}
    mock_agent.return_value = {"ok": False, "assistant_content": "", "error": "failed"}
    
    session = ConversationSession()
    res = run_voice_pipeline({}, speak_reply=False, session=session)
    
    assert not res["ok"]
    assert session.message_count() == 1
    assert session.get_messages()[0]["content"] == "do something"

@patch("hyprvoice.core.assistant_loop.run_voice_pipeline")
def test_assistant_loop_passes_shared_session(mock_pipeline):
    mock_pipeline.return_value = {"ok": True}
    session = ConversationSession()
    assistant = HyprVoiceAssistant({}, session=session)
    
    assistant.handle_wake_event()
    
    mock_pipeline.assert_called_once()
    kwargs = mock_pipeline.call_args[1]
    assert kwargs["session"] is session

def test_build_live_runtime_shares_session():
    runtime = build_live_runtime({})
    session = runtime["session"]
    assistant = runtime["assistant"]
    
    assert assistant.session is session
