from __future__ import annotations
from typing import Any

from hyprvoice.core.voice_pipeline import run_voice_pipeline
from hyprvoice.core.wake import WakeWordListener

class HyprVoiceAssistant:
    def __init__(self, config: dict[str, Any], state_store: Any | None = None):
        from hyprvoice.core.state import AssistantStateStore
        self.config = config
        self.state_store = state_store or AssistantStateStore()
        self.listener: WakeWordListener | None = None
        self.is_running = False
        self.is_busy = False
        self.last_result: dict[str, Any] | None = None

    def handle_wake_event(self) -> dict[str, Any] | None:
        """Callback triggered when the wake word is detected."""
        if self.is_busy:
            return None
            
        print("Wake word detected. Running voice pipeline...")
        self.state_store.set_state("wake_detected", "Wake word heard")
        self.is_busy = True
        try:
            self.state_store.set_state("listening", "Listening to command...")
            res = run_voice_pipeline(self.config, speak_reply=True, state_store=self.state_store)
            self.last_result = res
            if not res["ok"]:
                print(f"Pipeline error: {res.get('error')}")
                self.state_store.set_state("error", res.get("error", "Unknown error"))
            else:
                print("Voice pipeline completed successfully.")
                self.state_store.set_state("idle", "Completed")
            return res
        except Exception as e:
            print(f"Pipeline exception: {e}")
            self.state_store.set_state("error", str(e))
            return None
        finally:
            self.is_busy = False

    def run_forever(self) -> None:
        """Start listening for the wake word indefinitely."""
        print("Starting HyprVoice background loop...")
        try:
            self.listener = WakeWordListener(self.config)
            self.is_running = True
            print("Listening for wake word...")
            self.listener.listen_forever(on_detect=self.handle_wake_event)
        except Exception as e:
            print(f"Failed to start wake listener: {e}")
        finally:
            self.is_running = False

    def stop(self) -> None:
        """Stop the background loop and release resources."""
        self.is_running = False
        if self.listener:
            self.listener.stop()

def run_assistant_loop(config: dict[str, Any]) -> None:
    assistant = HyprVoiceAssistant(config)
    try:
        assistant.run_forever()
    except KeyboardInterrupt:
        pass
    finally:
        print("\nShutting down HyprVoice background loop...")
        assistant.stop()
