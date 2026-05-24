from __future__ import annotations
from typing import Any
import sys

from hyprvoice.core.state import AssistantStateStore

def check_chat_panel_dependencies() -> dict[str, bool]:
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

def chat_panel_available() -> bool:
    deps = check_chat_panel_dependencies()
    return deps["gi"] and deps["gtk4"]

def format_chat_panel_title() -> str:
    return "HyprVoice"

def format_chat_panel_status(snapshot: dict[str, Any]) -> str:
    msg = snapshot.get("message", "").strip()
    if msg:
        return msg
        
    state = snapshot.get("state", "idle")
    defaults = {
        "idle": "Idle",
        "wake_detected": "Wake word detected...",
        "listening": "Listening...",
        "transcribing": "Transcribing...",
        "thinking": "Thinking...",
        "executing": "Executing action...",
        "speaking": "Speaking...",
        "error": "Error"
    }
    return defaults.get(state, "Idle")

def format_chat_panel_placeholder(snapshot: dict[str, Any]) -> str:
    state = snapshot.get("state", "idle")
    
    if state == "idle":
        return "Voice and text conversations will appear here."
    elif state == "listening":
        return "Listening for your command..."
    elif state == "thinking":
        return "The assistant is thinking..."
    elif state == "error":
        return "An error occurred. Check logs or try again."
        
    return "Processing request..."

class ChatPanelWindow:
    def __init__(self, state_store: AssistantStateStore):
        self.state_store = state_store
        
        import gi
        gi.require_version("Gtk", "4.0")
        from gi.repository import Gtk, GLib, Gdk
        
        self.Gtk = Gtk
        self.GLib = GLib
        self.Gdk = Gdk
        
        self.app = Gtk.Application(application_id="org.hyprvoice.chatpanel")
        self.app.connect("activate", self._on_activate)
        
        self.window: Gtk.ApplicationWindow | None = None
        self.status_label: Gtk.Label | None = None
        self.placeholder_label: Gtk.Label | None = None
        self.current_state_class = "state-idle"
        
        self._load_css()
        self.state_store.subscribe(self._on_state_change)

    def _load_css(self):
        css_data = b"""
        window {
            background-color: #1a1a20;
        }
        .header-box {
            padding: 16px;
            background-color: #24242e;
            border-bottom: 1px solid #333340;
        }
        .panel-title {
            font-weight: bold;
            font-size: 18px;
            color: #ffffff;
        }
        .panel-status {
            font-size: 12px;
            color: #aaaaaa;
            margin-top: 4px;
        }
        .chat-area {
            background-color: #1a1a20;
        }
        .placeholder-text {
            color: #777777;
            font-style: italic;
        }
        .input-row {
            padding: 12px;
            background-color: #24242e;
            border-top: 1px solid #333340;
        }
        .input-entry {
            background-color: #1a1a20;
            color: #ffffff;
            border: 1px solid #333340;
            border-radius: 8px;
            padding: 8px 12px;
        }
        .send-button {
            border-radius: 8px;
            margin-left: 8px;
        }
        
        /* Status styling */
        .status-listening { color: #82aaff; }
        .status-thinking { color: #c099ff; }
        .status-error { color: #ff5370; }
        """
        provider = self.Gtk.CssProvider()
        provider.load_from_data(css_data)
        self.Gtk.StyleContext.add_provider_for_display(
            self.Gdk.Display.get_default(),
            provider,
            self.Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def _on_activate(self, app: Any) -> None:
        self.window = self.Gtk.ApplicationWindow(application=app)
        self.window.set_title("HyprVoice Chat")
        self.window.set_default_size(400, 700)
        
        main_box = self.Gtk.Box(orientation=self.Gtk.Orientation.VERTICAL)
        
        # Header
        header_box = self.Gtk.Box(orientation=self.Gtk.Orientation.VERTICAL)
        header_box.add_css_class("header-box")
        
        title_label = self.Gtk.Label(label=format_chat_panel_title())
        title_label.add_css_class("panel-title")
        title_label.set_halign(self.Gtk.Align.START)
        
        self.status_label = self.Gtk.Label()
        self.status_label.add_css_class("panel-status")
        self.status_label.set_halign(self.Gtk.Align.START)
        
        header_box.append(title_label)
        header_box.append(self.status_label)
        
        # Scrollable Chat Area
        scroll = self.Gtk.ScrolledWindow()
        scroll.set_hexpand(True)
        scroll.set_vexpand(True)
        scroll.add_css_class("chat-area")
        
        # Inner box for chat (just placeholder for now)
        self.chat_inner_box = self.Gtk.Box(orientation=self.Gtk.Orientation.VERTICAL)
        self.chat_inner_box.set_halign(self.Gtk.Align.CENTER)
        self.chat_inner_box.set_valign(self.Gtk.Align.CENTER)
        
        self.placeholder_label = self.Gtk.Label()
        self.placeholder_label.add_css_class("placeholder-text")
        self.placeholder_label.set_wrap(True)
        self.placeholder_label.set_max_width_chars(30)
        self.placeholder_label.set_justify(self.Gtk.Justification.CENTER)
        
        self.chat_inner_box.append(self.placeholder_label)
        
        scroll.set_child(self.chat_inner_box)
        
        # Input Row
        input_row = self.Gtk.Box(orientation=self.Gtk.Orientation.HORIZONTAL)
        input_row.add_css_class("input-row")
        
        entry = self.Gtk.Entry()
        entry.set_placeholder_text("Type a message...")
        entry.set_hexpand(True)
        entry.add_css_class("input-entry")
        
        send_btn = self.Gtk.Button(label="Send")
        send_btn.add_css_class("send-button")
        
        input_row.append(entry)
        input_row.append(send_btn)
        
        # Assemble
        main_box.append(header_box)
        main_box.append(scroll)
        main_box.append(input_row)
        
        self.window.set_child(main_box)
        
        snap = self.state_store.snapshot()
        self.update_from_snapshot(snap)
        
        self.window.present()

    def _on_state_change(self, snapshot: dict[str, Any]) -> None:
        if self.GLib and self.window:
            self.GLib.idle_add(self.update_from_snapshot, snapshot)

    def update_from_snapshot(self, snapshot: dict[str, Any]) -> None:
        if not self.window or not self.status_label or not self.placeholder_label:
            return
            
        self.status_label.set_text(format_chat_panel_status(snapshot))
        self.placeholder_label.set_text(format_chat_panel_placeholder(snapshot))
        
        self.status_label.remove_css_class(f"status-{self.current_state_class}")
        
        state = snapshot.get("state", "idle")
        self.current_state_class = state
        self.status_label.add_css_class(f"status-{state}")

    def run(self) -> None:
        self.app.run(None)

    def close(self) -> None:
        if self.window:
            self.window.close()

def launch_chat_panel_demo(state_store: AssistantStateStore | None = None) -> None:
    if not chat_panel_available():
        print("GTK4 dependencies missing, cannot launch chat panel.")
        return
        
    store = state_store or AssistantStateStore()
    
    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import GLib
    
    demo_states = [
        ("listening", "Listening..."),
        ("transcribing", "Transcribing..."),
        ("thinking", "Thinking..."),
        ("executing", "Running tool..."),
        ("speaking", "Speaking..."),
        ("idle", "")
    ]
    
    def advance_demo(*args):
        if not demo_states:
            return False
        st, msg = demo_states.pop(0)
        store.set_state(st, msg)
        return True
        
    GLib.timeout_add(2000, advance_demo)
    
    win = ChatPanelWindow(store)
    win.run()
