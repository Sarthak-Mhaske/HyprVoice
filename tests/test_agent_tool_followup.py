import pytest
from unittest.mock import patch
from hyprvoice.core.agent import run_single_tool_turn_with_followup

@patch("hyprvoice.core.agent.chat_completion_with_tools")
@patch("hyprvoice.core.agent.chat_completion_with_fallback")
@patch("hyprvoice.core.tool_executor.execute_tool")
def test_tool_followup_success(mock_exec, mock_fallback, mock_tools):
    mock_tools.return_value = {
        "ok": True,
        "model": "m",
        "content": "",
        "tool_calls": [{"id": "t1", "function": {"name": "google_search", "arguments": '{"query": "linux"}'}}],
        "raw": {"choices": [{"message": {"tool_calls": [{"id": "t1", "function": {"name": "google_search", "arguments": '{"query": "linux"}'}}]}}]}
    }
    
    mock_exec.return_value = {"ok": True, "tool": "google_search", "message": "done", "error": None, "data": {}}
    
    mock_fallback.return_value = {
        "ok": True,
        "model": "m",
        "content": "I found info about linux.",
        "error": None,
        "raw": {"final": True}
    }
    
    res = run_single_tool_turn_with_followup([{"role": "user", "content": "hi"}], {})
    
    assert res["ok"]
    assert res["mode"] == "tool_followup"
    assert res["assistant_content"] == "I found info about linux."
    assert res["tool_name"] == "google_search"
    assert res["tool_result"]["ok"]
    assert mock_fallback.called
    
    called_args = mock_fallback.call_args[0][0]
    assert len(called_args) == 3
    assert called_args[0]["role"] == "user"
    assert called_args[1]["role"] == "assistant"
    assert "tool_calls" in called_args[1]
    assert called_args[2]["role"] == "tool"
    assert called_args[2]["tool_call_id"] == "t1"

@patch("hyprvoice.core.agent.chat_completion_with_tools")
def test_tool_followup_plain_reply(mock_tools):
    mock_tools.return_value = {
        "ok": True,
        "model": "m",
        "content": "Just saying hi",
        "tool_calls": [],
        "raw": {"some": "raw"}
    }
    
    res = run_single_tool_turn_with_followup([{"role": "user", "content": "hi"}], {})
    assert res["ok"]
    assert res["mode"] == "assistant_reply"
    assert res["assistant_content"] == "Just saying hi"
    assert res["final_response"] is None

@patch("hyprvoice.core.agent.chat_completion_with_tools")
def test_tool_followup_malformed_args(mock_tools):
    mock_tools.return_value = {
        "ok": True,
        "model": "m",
        "content": "",
        "tool_calls": [{"id": "t1", "function": {"name": "google_search", "arguments": '{bad' }}],
        "raw": {"choices": [{"message": {"tool_calls": [{"id": "t1", "function": {"name": "google_search", "arguments": '{bad' }}]}}]}
    }
    
    res = run_single_tool_turn_with_followup([{"role": "user", "content": "hi"}], {})
    assert not res["ok"]
    assert res["mode"] == "tool_call"
    assert res["tool_args"] is None

@patch("hyprvoice.core.agent.chat_completion_with_tools")
@patch("hyprvoice.core.agent.chat_completion_with_fallback")
@patch("hyprvoice.core.tool_executor.execute_tool")
def test_tool_followup_tool_failure(mock_exec, mock_fallback, mock_tools):
    mock_tools.return_value = {
        "ok": True,
        "model": "m",
        "content": "",
        "tool_calls": [{"id": "t1", "function": {"name": "google_search", "arguments": '{"query": "linux"}'}}],
        "raw": {"choices": [{"message": {"tool_calls": [{"id": "t1", "function": {"name": "google_search", "arguments": '{"query": "linux"}'}}]}}]}
    }
    
    mock_exec.return_value = {"ok": False, "tool": "google_search", "message": "", "error": "Not found", "data": None}
    
    mock_fallback.return_value = {
        "ok": True,
        "model": "m",
        "content": "Sorry, that tool failed.",
        "error": None,
        "raw": {"final": True}
    }
    
    res = run_single_tool_turn_with_followup([{"role": "user", "content": "hi"}], {})
    
    assert res["ok"]
    assert res["mode"] == "tool_followup"
    assert res["assistant_content"] == "Sorry, that tool failed."
    assert not res["tool_result"]["ok"]
    assert res["tool_result"]["error"] == "Not found"
