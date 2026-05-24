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

def should_overlay_be_visible(snapshot: dict[str, Any]) -> bool:
    return snapshot.get("state", "idle") != "idle"

def get_overlay_state_class(snapshot: dict[str, Any]) -> str:
    state = snapshot.get("state", "idle")
    return f"state-{state}"

def format_overlay_title(snapshot: dict[str, Any]) -> str:
    state = snapshot.get("state", "idle")
    titles = {
        "wake_detected": "HyprVoice",
        "listening": "Listening",
        "transcribing": "Transcribing",
        "thinking": "Thinking",
        "executing": "Executing",
        "speaking": "Speaking",
        "error": "Error",
        "idle": "HyprVoice"
    }
    return titles.get(state, "HyprVoice")

def format_overlay_message(snapshot: dict[str, Any]) -> str:
    msg = snapshot.get("message", "").strip()
    if msg:
        return msg
        
    state = snapshot.get("state", "idle")
    defaults = {
        "listening": "I'm listening...",
        "transcribing": "Converting speech to text",
        "thinking": "Thinking",
        "executing": "Running action",
        "speaking": "Speaking",
        "error": "Something went wrong",
        "idle": ""
    }
    return defaults.get(state, "")

class OverlayWindow:
    def __init__(self, state_store: AssistantStateStore):
        self.state_store = state_store
        
        import gi
        gi.require_version("Gtk", "4.0")
        from gi.repository import Gtk, GLib, Gdk
        
        self.Gtk = Gtk
        self.GLib = GLib
        self.Gdk = Gdk
        
        self.app: Gtk.Application | None = None
        self.window: Gtk.ApplicationWindow | None = None
        self.box: Gtk.Box | None = None
        self.title_label: Gtk.Label | None = None
        self.msg_label: Gtk.Label | None = None
        self.current_state_class = "state-idle"
        
        self._load_css()
        self.state_store.subscribe(self._on_state_change)

    def _load_css(self):
        css_data = b"""
        window {
            background: transparent;
        }
        .pill-container {
            background-color: rgba(20, 20, 25, 0.85);
            border-radius: 24px;
            padding: 16px 24px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5);
        }
        .pill-title {
            font-weight: bold;
            font-size: 16px;
            color: #ffffff;
        }
        .pill-message {
            font-size: 14px;
            color: #cccccc;
            margin-top: 4px;
        }
        /* State specific colors */
        .state-listening .pill-title { color: #82aaff; }
        .state-thinking .pill-title { color: #c099ff; }
        .state-error .pill-title { color: #ff5370; }
        """
        provider = self.Gtk.CssProvider()
        provider.load_from_data(css_data)
        self.Gtk.StyleContext.add_provider_for_display(
            self.Gdk.Display.get_default(),
            provider,
            self.Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def build_window(self, app: Any) -> None:
        """Build the overlay window inside the given Gtk.Application."""
        self.window = self.Gtk.ApplicationWindow(application=app)
        self.window.set_title("HyprVoice Overlay")
        self.window.set_decorated(False)
        self.window.set_default_size(300, -1)
        self.window.set_resizable(False)
        
        self.box = self.Gtk.Box(orientation=self.Gtk.Orientation.VERTICAL)
        self.box.add_css_class("pill-container")
        self.box.add_css_class("state-idle")
        self.box.set_halign(self.Gtk.Align.CENTER)
        self.box.set_valign(self.Gtk.Align.CENTER)
        
        self.title_label = self.Gtk.Label()
        self.title_label.add_css_class("pill-title")
        self.title_label.set_halign(self.Gtk.Align.START)
        
        self.msg_label = self.Gtk.Label()
        self.msg_label.add_css_class("pill-message")
        self.msg_label.set_halign(self.Gtk.Align.START)
        self.msg_label.set_wrap(True)
        self.msg_label.set_max_width_chars(40)
        
        self.box.append(self.title_label)
        self.box.append(self.msg_label)
        
        self.window.set_child(self.box)
        
        snap = self.state_store.snapshot()
        self.update_from_snapshot(snap)

    def _on_state_change(self, snapshot: dict[str, Any]) -> None:
        if self.GLib and self.window:
            self.GLib.idle_add(self.update_from_snapshot, snapshot)

    def update_from_snapshot(self, snapshot: dict[str, Any]) -> None:
        if not self.window or not self.box or not self.title_label or not self.msg_label:
            return
            
        self.title_label.set_text(format_overlay_title(snapshot))
        self.msg_label.set_text(format_overlay_message(snapshot))
        
        new_class = get_overlay_state_class(snapshot)
        if new_class != self.current_state_class:
            self.box.remove_css_class(self.current_state_class)
            self.box.add_css_class(new_class)
            self.current_state_class = new_class
            
        if should_overlay_be_visible(snapshot):
            self.window.present()
        else:
            self.window.set_visible(False)

    def run(self) -> None:
        """Run standalone with its own Gtk.Application."""
        self.app = self.Gtk.Application(application_id="org.hyprvoice.overlay")
        self.app.connect("activate", lambda app: self.build_window(app))
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
        ("wake_detected", ""),
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
