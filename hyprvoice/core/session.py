from __future__ import annotations
from typing import Any

class ConversationSession:
    """Minimal in-memory chat session state for HyprVoice."""
    
    def __init__(self, system_prompt: str | None = None):
        self._system_prompt = system_prompt.strip() if system_prompt else None
        self._messages: list[dict[str, str]] = []
        self._revision = 0
        
    def get_revision(self) -> int:
        return self._revision
        
    def set_system_prompt(self, prompt: str | None) -> None:
        new_prompt = prompt.strip() if prompt else None
        if self._system_prompt != new_prompt:
            self._system_prompt = new_prompt
            self._revision += 1
        
    def add_message(self, role: str, content: str) -> bool:
        content = content.strip()
        role = role.strip().lower()
        
        if not content:
            return False
            
        if role not in ("user", "assistant"):
            return False
            
        self._messages.append({"role": role, "content": content})
        self._revision += 1
        return True

    def add_user_message(self, content: str) -> bool:
        return self.add_message("user", content)
        
    def add_assistant_message(self, content: str) -> bool:
        return self.add_message("assistant", content)

    def clear(self, keep_system_prompt: bool = True) -> None:
        changed = len(self._messages) > 0
        self._messages.clear()
        if not keep_system_prompt and self._system_prompt is not None:
            self._system_prompt = None
            changed = True
        
        if changed:
            self._revision += 1

    def get_messages(self) -> list[dict[str, str]]:
        # Return a copy to prevent accidental mutation
        return [dict(m) for m in self._messages]
        
    def build_api_messages(self) -> list[dict[str, str]]:
        api_msgs = []
        if self._system_prompt:
            api_msgs.append({"role": "system", "content": self._system_prompt})
        api_msgs.extend(self.get_messages())
        return api_msgs

    def last_assistant_message(self) -> str | None:
        for m in reversed(self._messages):
            if m["role"] == "assistant":
                return m["content"]
        return None

    def message_count(self) -> int:
        return len(self._messages)
