import pytest
from unittest.mock import patch
from hyprvoice.core.tool_executor import (
    execute_tool,
    execute_notify,
    execute_open_url,
    execute_google_search
)

def test_unsupported_tool():
    res = execute_tool("set_volume", {"level": "50"})
    assert not res["ok"]
    assert "not implemented" in res["error"].lower()

@patch("hyprvoice.core.tool_executor._command_exists")
@patch("subprocess.run")
def test_notify_normalization(mock_run, mock_exists):
    mock_exists.return_value = True
    
    # Test only message
    res = execute_notify({"message": "hello"})
    assert res["ok"]
    assert res["data"]["title"] == "HyprVoice"
    assert res["data"]["body"] == "hello"
    
    # Test title and body
    res2 = execute_notify({"title": "Alert", "body": "system down"})
    assert res2["ok"]
    assert res2["data"]["title"] == "Alert"
    assert res2["data"]["body"] == "system down"
    
    # Test missing command
    mock_exists.return_value = False
    res3 = execute_notify({"message": "test"})
    assert not res3["ok"]
    assert "not found" in res3["error"]

@patch("hyprvoice.core.tool_executor._command_exists")
@patch("subprocess.run")
def test_open_url_validation(mock_run, mock_exists):
    mock_exists.return_value = True
    
    # Valid
    res = execute_open_url({"url": "https://example.com"})
    assert res["ok"]
    
    # Invalid scheme
    res2 = execute_open_url({"url": "ftp://example.com"})
    assert not res2["ok"]
    assert "http" in res2["error"]

@patch("hyprvoice.core.tool_executor.execute_open_url")
def test_google_search_url_building(mock_open):
    mock_open.return_value = {"ok": True, "tool": "open_url", "message": "...", "data": {"url": "..."}}
    
    res = execute_google_search({"query": "arch linux"})
    mock_open.assert_called_once_with({"url": "https://www.google.com/search?q=arch+linux"})
    
    assert res["ok"]
    assert res["tool"] == "google_search"
    assert res["data"]["query"] == "arch linux"
