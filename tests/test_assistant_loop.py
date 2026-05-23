import pytest
from unittest.mock import patch, MagicMock
from hyprvoice.core.assistant_loop import HyprVoiceAssistant, run_assistant_loop

def test_wake_event_triggers_pipeline():
    with patch("hyprvoice.core.assistant_loop.run_voice_pipeline") as mock_run:
        mock_run.return_value = {"ok": True, "assistant_text": "done"}
        
        assistant = HyprVoiceAssistant({})
        res = assistant.handle_wake_event()
        
        assert res is not None
        assert res["ok"]
        assert assistant.last_result == res
        assert not assistant.is_busy
        mock_run.assert_called_once()

def test_busy_flag_prevents_overlap():
    with patch("hyprvoice.core.assistant_loop.run_voice_pipeline") as mock_run:
        assistant = HyprVoiceAssistant({})
        assistant.is_busy = True
        
        res = assistant.handle_wake_event()
        
        assert res is None
        assert not mock_run.called
        assert assistant.is_busy

@patch("hyprvoice.core.assistant_loop.WakeWordListener")
def test_run_forever_wires_callback(mock_listener_class):
    mock_instance = MagicMock()
    mock_listener_class.return_value = mock_instance
    
    assistant = HyprVoiceAssistant({})
    assistant.run_forever()
    
    mock_instance.listen_forever.assert_called_once_with(on_detect=assistant.handle_wake_event)
    assert not assistant.is_running # resets in finally block when listen_forever returns

@patch("hyprvoice.core.assistant_loop.WakeWordListener")
def test_stop_calls_listener_stop(mock_listener_class):
    mock_instance = MagicMock()
    mock_listener_class.return_value = mock_instance
    
    assistant = HyprVoiceAssistant({})
    assistant.listener = mock_instance
    assistant.is_running = True
    
    assistant.stop()
    
    assert not assistant.is_running
    mock_instance.stop.assert_called_once()
