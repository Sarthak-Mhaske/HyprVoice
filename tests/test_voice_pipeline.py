import pytest
from unittest.mock import patch
from hyprvoice.core.voice_pipeline import build_voice_user_text, run_voice_pipeline, run_voice_pipeline_from_audio

def test_build_voice_user_text():
    assert build_voice_user_text({"ok": True, "english_text": "hello", "transcription_text": "नमस्ते"}) == "hello"
    assert build_voice_user_text({"ok": True, "english_text": "", "transcription_text": "नमस्ते"}) == "नमस्ते"
    assert build_voice_user_text({"ok": True}) == ""
    assert build_voice_user_text({"ok": False, "english_text": "hello"}) == ""

@patch("hyprvoice.core.voice_pipeline.record_and_transcribe")
def test_pipeline_transcription_fails(mock_record):
    mock_record.return_value = {"ok": False, "error": "mic broken"}
    res = run_voice_pipeline({})
    
    assert not res["ok"]
    assert res["error"] == "mic broken"
    assert res["agent"] is None

@patch("hyprvoice.core.voice_pipeline.record_and_transcribe")
def test_pipeline_empty_text(mock_record):
    mock_record.return_value = {"ok": True, "english_text": "", "transcription_text": ""}
    res = run_voice_pipeline({})
    
    assert not res["ok"]
    assert res["error"] == "No text transcribed"

@patch("hyprvoice.core.voice_pipeline.record_and_transcribe")
@patch("hyprvoice.core.voice_pipeline.detect_environment")
@patch("hyprvoice.core.voice_pipeline.build_system_prompt")
@patch("hyprvoice.core.voice_pipeline.run_single_tool_turn_with_followup")
@patch("hyprvoice.core.voice_pipeline.speak_text")
def test_pipeline_success_no_tts(mock_speak, mock_agent, mock_prompt, mock_env, mock_record):
    mock_record.return_value = {"ok": True, "english_text": "what time is it"}
    mock_env.return_value = {}
    mock_prompt.return_value = "system"
    mock_agent.return_value = {"ok": True, "assistant_content": "It is 12 PM"}
    
    res = run_voice_pipeline({}, speak_reply=False)
    
    assert res["ok"]
    assert res["user_text"] == "what time is it"
    assert res["assistant_text"] == "It is 12 PM"
    assert res["tts"] is None
    assert not mock_speak.called

@patch("hyprvoice.core.voice_pipeline.record_and_transcribe")
@patch("hyprvoice.core.voice_pipeline.detect_environment")
@patch("hyprvoice.core.voice_pipeline.build_system_prompt")
@patch("hyprvoice.core.voice_pipeline.run_single_tool_turn_with_followup")
@patch("hyprvoice.core.voice_pipeline.speak_text")
def test_pipeline_success_with_tts(mock_speak, mock_agent, mock_prompt, mock_env, mock_record):
    mock_record.return_value = {"ok": True, "english_text": "hello"}
    mock_env.return_value = {}
    mock_prompt.return_value = "system"
    mock_agent.return_value = {"ok": True, "assistant_content": "hi"}
    mock_speak.return_value = {"ok": True}
    
    res = run_voice_pipeline({}, speak_reply=True)
    
    assert res["ok"]
    assert res["user_text"] == "hello"
    assert res["assistant_text"] == "hi"
    assert res["tts"]["ok"]
    assert mock_speak.called
    
@patch("hyprvoice.core.voice_pipeline.transcribe_existing_audio")
@patch("hyprvoice.core.voice_pipeline.detect_environment")
@patch("hyprvoice.core.voice_pipeline.build_system_prompt")
@patch("hyprvoice.core.voice_pipeline.run_single_tool_turn_with_followup")
def test_pipeline_from_audio(mock_agent, mock_prompt, mock_env, mock_transcribe):
    mock_transcribe.return_value = {"ok": True, "english_text": "file text"}
    mock_env.return_value = {}
    mock_prompt.return_value = "system"
    mock_agent.return_value = {"ok": True, "assistant_content": "file reply"}
    
    res = run_voice_pipeline_from_audio("path/to/audio.wav", {}, speak_reply=False)
    
    assert res["ok"]
    assert res["user_text"] == "file text"
    assert res["assistant_text"] == "file reply"
    assert mock_transcribe.call_args[0][0] == "path/to/audio.wav"
