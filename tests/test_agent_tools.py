import pytest
from unittest.mock import patch
from hyprvoice.core.agent import run_single_tool_turn

@patch("hyprvoice.core.agent.chat_completion_with_tools")
def test_agent_plain_reply(mock_chat):
    mock_chat.return_value = {
        "ok": True,
        "model": "test-model",
        "content": "Hello!",
        "tool_calls": [],
        "raw": {"some": "data"}
    }
    
    res = run_single_tool_turn([{"role": "user", "content": "hi"}], {})
    assert res["ok"]
    assert res["mode"] == "assistant_reply"
    assert res["assistant_content"] == "Hello!"
    assert res["tool_name"] is None
    
@patch("hyprvoice.core.agent.chat_completion_with_tools")
@patch("hyprvoice.core.tool_executor.execute_tool")
def test_agent_tool_call(mock_exec, mock_chat):
    mock_chat.return_value = {
        "ok": True,
        "model": "test-model",
        "content": "",
        "tool_calls": [{
            "function": {
                "name": "google_search",
                "arguments": '{"query": "linux"}'
            }
        }],
        "raw": {}
    }
    
    mock_exec.return_value = {
        "ok": True,
        "tool": "google_search",
        "error": None,
        "data": {"query": "linux"}
    }
    
    res = run_single_tool_turn([{"role": "user", "content": "search linux"}], {})
    mock_exec.assert_called_once_with("google_search", {"query": "linux"}, config={})
    
    assert res["ok"]
    assert res["mode"] == "tool_call"
    assert res["tool_name"] == "google_search"
    assert res["tool_args"] == {"query": "linux"}
    assert res["tool_result"]["ok"]

@patch("hyprvoice.core.agent.chat_completion_with_tools")
def test_agent_tool_call_malformed_json(mock_chat):
    mock_chat.return_value = {
        "ok": True,
        "model": "test-model",
        "content": "",
        "tool_calls": [{
            "function": {
                "name": "google_search",
                "arguments": '{"query": "linux"' # missing brace
            }
        }],
        "raw": {}
    }
    
    res = run_single_tool_turn([{"role": "user", "content": "search"}], {})
    assert not res["ok"]
    assert res["mode"] == "tool_call"
    assert res["tool_args"] is None
    assert "Failed to parse tool arguments" in res["error"]
