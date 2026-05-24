import pytest
from unittest.mock import MagicMock, patch
from hyprvoice.ui.app import (
    build_live_runtime,
    run_assistant_worker,
    start_assistant_background,
    stop_assistant_background,
)

def test_build_live_runtime_returns_expected_keys():
    runtime = build_live_runtime({})
    assert "state_store" in runtime
    assert "session" in runtime
    assert "assistant" in runtime
    assert "config" in runtime

def test_build_live_runtime_shares_state_store():
    runtime = build_live_runtime({})
    assert runtime["assistant"].state_store is runtime["state_store"]

def test_start_assistant_background_returns_thread():
    assistant = MagicMock()
    assistant.run_forever = MagicMock()
    store = MagicMock()

    thread = start_assistant_background(assistant, store)
    thread.join(timeout=1.0)

    assert assistant.run_forever.called

def test_stop_assistant_background_calls_stop():
    assistant = MagicMock()
    stop_assistant_background(assistant)
    assistant.stop.assert_called_once()

def test_stop_assistant_background_swallows_exception():
    assistant = MagicMock()
    assistant.stop.side_effect = RuntimeError("boom")
    # Should not raise
    stop_assistant_background(assistant)

def test_run_assistant_worker_sets_error_on_crash():
    assistant = MagicMock()
    assistant.run_forever.side_effect = RuntimeError("mic failed")
    store = MagicMock()

    run_assistant_worker(assistant, store)

    store.set_state.assert_called_once()
    args = store.set_state.call_args[0]
    assert args[0] == "error"
    assert "mic failed" in args[1]

def test_run_assistant_worker_no_error_on_success():
    assistant = MagicMock()
    assistant.run_forever = MagicMock()
    store = MagicMock()

    run_assistant_worker(assistant, store)

    store.set_state.assert_not_called()
