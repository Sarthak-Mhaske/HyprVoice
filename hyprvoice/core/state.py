from __future__ import annotations
from typing import Callable, Any

VALID_STATES = {
    "idle",
    "wake_detected",
    "listening",
    "transcribing",
    "thinking",
    "executing",
    "speaking",
    "error"
}

class AssistantStateStore:
    def __init__(self) -> None:
        self._state = "idle"
        self._message = ""
        self._subscribers: list[Callable[[dict[str, Any]], None]] = []

    def get_state(self) -> str:
        return self._state

    def get_message(self) -> str:
        return self._message

    def set_state(self, state: str, message: str = "") -> None:
        if state not in VALID_STATES:
            raise ValueError(f"Invalid state: {state}")
            
        self._state = state
        self._message = message
        self._notify()

    def snapshot(self) -> dict[str, Any]:
        return {
            "state": self._state,
            "message": self._message
        }

    def subscribe(self, callback: Callable[[dict[str, Any]], None]) -> None:
        if callback not in self._subscribers:
            self._subscribers.append(callback)

    def unsubscribe(self, callback: Callable[[dict[str, Any]], None]) -> None:
        if callback in self._subscribers:
            self._subscribers.remove(callback)
            
    def _notify(self) -> None:
        snap = self.snapshot()
        for sub in self._subscribers:
            try:
                sub(snap)
            except Exception as e:
                print(f"Error in subscriber: {e}")
