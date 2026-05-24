from __future__ import annotations
from typing import Any
import sys

from hyprvoice.core.state import AssistantStateStore

def check_overlay_dependencies() -> dict[str, bool]:
    deps = {"gi": False, "gtk4": False}
    try:
        import gi
        deps["gi"] = True
        gi.require_version("Gtk", "4.0")
        from gi.repository import Gtk
        deps["gtk4"] = True
    except (ImportError, ValueError):
        pass
    return deps

def overlay_available() -> bool:
    deps = check_overlay_dependencies()
    return deps["gi"] and deps["gtk4"]

def format_overlay_text(snapshot: dict[str, Any]) -> str:
    state = snapshot.get("state", "idle")
    msg = snapshot.get("message", "").strip()
    
    text = f"HyprVoice\nState: {state}"
    if msg:
        text += f"\nMessage: {msg}"
    return text

class OverlayWindow:
    def __init__(self, state_store: AssistantStateStore):
        self.state_store = state_store
        
        import gi
        gi.require_version("Gtk", "4.0")
        from gi.repository import Gtk, GLib
        
        self.Gtk = Gtk
        self.GLib = GLib
        
        self.app = Gtk.Application(application_id="org.hyprvoice.overlay")
        self.app.connect("activate", self._on_activate)
        
        self.window: Gtk.ApplicationWindow | None = None
        self.label: Gtk.Label | None = None
        
        self.state_store.subscribe(self._on_state_change)

    def _on_activate(self, app: Any) -> None:
        self.window = self.Gtk.ApplicationWindow(application=app)
        self.window.set_title("HyprVoice Overlay")
        self.window.set_default_size(300, 100)
        self.window.set_decorated(False)
        
        self.label = self.Gtk.Label()
        self.label.set_text(format_overlay_text(self.state_store.snapshot()))
        self.label.set_margin_top(20)
        self.label.set_margin_bottom(20)
        self.label.set_margin_start(20)
        self.label.set_margin_end(20)
        
        self.window.set_child(self.label)
        self.window.present()

    def _on_state_change(self, snapshot: dict[str, Any]) -> None:
        if self.GLib and self.label:
            self.GLib.idle_add(self.update_from_snapshot, snapshot)

    def update_from_snapshot(self, snapshot: dict[str, Any]) -> None:
        if self.label:
            self.label.set_text(format_overlay_text(snapshot))

    def run(self) -> None:
        self.app.run(None)

    def close(self) -> None:
        if self.window:
            self.window.close()

def launch_overlay_demo(state_store: AssistantStateStore | None = None) -> None:
    if not overlay_available():
        print("GTK4 dependencies missing, cannot launch overlay.")
        return
        
    store = state_store or AssistantStateStore()
    
    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import GLib
    
    demo_states = [
        ("listening", "Hearing mic..."),
        ("transcribing", "Converting speech..."),
        ("thinking", "Thinking..."),
        ("executing", "Running tool..."),
        ("speaking", "Replying..."),
        ("idle", "")
    ]
    
    def advance_demo(*args):
        if not demo_states:
            return False
        st, msg = demo_states.pop(0)
        store.set_state(st, msg)
        return True
        
    GLib.timeout_add(1500, advance_demo)
    
    win = OverlayWindow(store)
    win.run()
