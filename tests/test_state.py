import pytest
from hyprvoice.core.state import AssistantStateStore

def test_initial_state():
    store = AssistantStateStore()
    assert store.get_state() == "idle"

def test_valid_state_update():
    store = AssistantStateStore()
    store.set_state("listening", "hello")
    assert store.get_state() == "listening"
    assert store.get_message() == "hello"

def test_invalid_state_rejected():
    store = AssistantStateStore()
    with pytest.raises(ValueError):
        store.set_state("not_real")

def test_subscriber_receives_updates():
    store = AssistantStateStore()
    calls = []
    
    def cb(snap):
        calls.append(snap)
        
    store.subscribe(cb)
    store.set_state("thinking", "msg")
    
    assert len(calls) == 1
    assert calls[0]["state"] == "thinking"
    
    store.unsubscribe(cb)
    store.set_state("idle", "")
    assert len(calls) == 1

def test_bad_subscriber_does_not_crash():
    store = AssistantStateStore()
    calls = []
    
    def bad_cb(snap):
        raise RuntimeError("boom")
        
    def good_cb(snap):
        calls.append(snap)
        
    store.subscribe(bad_cb)
    store.subscribe(good_cb)
    
    store.set_state("speaking") # shouldn't crash
    assert len(calls) == 1
