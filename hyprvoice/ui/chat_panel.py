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

def format_message_row(msg: dict[str, Any]) -> dict[str, Any] | None:
    role = msg.get("role", "").strip().lower()
    content = msg.get("content", "").strip()
    
    if role not in ("user", "assistant") or not content:
        return None
        
    return {
        "role": role,
        "content": content,
        "align": "end" if role == "user" else "start",
        "css_class": f"message-{role}"
    }

def session_messages_to_rows(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows = []
    for m in messages:
        row = format_message_row(m)
        if row:
            rows.append(row)
    return rows

def normalize_input_text(text: str) -> str:
    cleaned = text.strip()
    return cleaned if cleaned else ""

class ChatPanelWindow:
    def __init__(self, state_store: AssistantStateStore, session: Any | None = None):
        self.state_store = state_store
        self.session = session
        
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
        .message-user {
            background-color: #2d4a7a;
            color: #e0e0e0;
            border-radius: 16px 16px 4px 16px;
            padding: 10px 14px;
            margin: 4px 12px 4px 60px;
        }
        .message-assistant {
            background-color: #2a2a35;
            color: #e0e0e0;
            border-radius: 16px 16px 16px 4px;
            padding: 10px 14px;
            margin: 4px 60px 4px 12px;
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
        self.scroll = self.Gtk.ScrolledWindow()
        self.scroll.set_hexpand(True)
        self.scroll.set_vexpand(True)
        self.scroll.add_css_class("chat-area")
        
        # Inner box for chat messages
        self.chat_inner_box = self.Gtk.Box(orientation=self.Gtk.Orientation.VERTICAL)
        self.chat_inner_box.set_valign(self.Gtk.Align.END)
        
        self.placeholder_label = self.Gtk.Label()
        self.placeholder_label.add_css_class("placeholder-text")
        self.placeholder_label.set_wrap(True)
        self.placeholder_label.set_max_width_chars(30)
        self.placeholder_label.set_justify(self.Gtk.Justification.CENTER)
        self.placeholder_label.set_halign(self.Gtk.Align.CENTER)
        self.placeholder_label.set_valign(self.Gtk.Align.CENTER)
        self.placeholder_label.set_vexpand(True)
        
        self.chat_inner_box.append(self.placeholder_label)
        
        self.scroll.set_child(self.chat_inner_box)
        
        # Input Row
        input_row = self.Gtk.Box(orientation=self.Gtk.Orientation.HORIZONTAL)
        input_row.add_css_class("input-row")
        
        self.entry = self.Gtk.Entry()
        self.entry.set_placeholder_text("Type a message...")
        self.entry.set_hexpand(True)
        self.entry.add_css_class("input-entry")
        self.entry.connect("activate", self.handle_submit)
        
        send_btn = self.Gtk.Button(label="Send")
        send_btn.add_css_class("send-button")
        send_btn.connect("clicked", self.handle_submit)
        
        input_row.append(self.entry)
        input_row.append(send_btn)
        
        # Assemble
        main_box.append(header_box)
        main_box.append(self.scroll)
        main_box.append(input_row)
        
        self.window.set_child(main_box)
        
        snap = self.state_store.snapshot()
        self.update_from_snapshot(snap)
        self.refresh_messages()
        
        self.window.present()

    def _on_state_change(self, snapshot: dict[str, Any]) -> None:
        if self.GLib and self.window:
            self.GLib.idle_add(self.update_from_snapshot, snapshot)

    def update_from_snapshot(self, snapshot: dict[str, Any]) -> None:
        if not self.window or not self.status_label or not self.placeholder_label:
            return
            
        self.status_label.set_text(format_chat_panel_status(snapshot))
        
        has_messages = self.session and self.session.message_count() > 0
        if not has_messages:
            self.placeholder_label.set_text(format_chat_panel_placeholder(snapshot))
        
        self.status_label.remove_css_class(f"status-{self.current_state_class}")
        
        state = snapshot.get("state", "idle")
        self.current_state_class = state
        self.status_label.add_css_class(f"status-{state}")

    def refresh_messages(self) -> None:
        if not self.chat_inner_box or not self.placeholder_label:
            return
            
        if not self.session or self.session.message_count() == 0:
            self.placeholder_label.set_visible(True)
            return
            
        self.placeholder_label.set_visible(False)
        
        # Remove old message widgets (keep placeholder at index 0)
        child = self.chat_inner_box.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            if child != self.placeholder_label:
                self.chat_inner_box.remove(child)
            child = next_child
        
        rows = session_messages_to_rows(self.session.get_messages())
        for row in rows:
            lbl = self.Gtk.Label(label=row["content"])
            lbl.set_wrap(True)
            lbl.set_max_width_chars(35)
            lbl.add_css_class(row["css_class"])
            lbl.set_halign(
                self.Gtk.Align.END if row["align"] == "end" else self.Gtk.Align.START
            )
            self.chat_inner_box.append(lbl)
        
        # Scroll to bottom
        adj = self.scroll.get_vadjustment()
        self.GLib.idle_add(lambda: adj.set_value(adj.get_upper()))

    def handle_submit(self, *_args) -> None:
        if not self.entry or not self.session:
            return
            
        raw = self.entry.get_text()
        text = normalize_input_text(raw)
        if not text:
            return
            
        added = self.session.add_user_message(text)
        if added:
            self.entry.set_text("")
            self.refresh_messages()

    def run(self) -> None:
        self.app.run(None)

    def close(self) -> None:
        if self.window:
            self.window.close()

def launch_chat_panel_demo(state_store: AssistantStateStore | None = None) -> None:
    if not chat_panel_available():
        print("GTK4 dependencies missing, cannot launch chat panel.")
        return
        
    from hyprvoice.core.session import ConversationSession
    
    store = state_store or AssistantStateStore()
    session = ConversationSession()
    session.add_user_message("Open YouTube for me")
    session.add_assistant_message("Opening YouTube in your browser.")
    session.add_user_message("What time is it?")
    session.add_assistant_message("It is currently 10:08 AM IST.")
    
    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import GLib
    
    demo_states = [
        ("listening", "Listening..."),
        ("transcribing", "Transcribing..."),
        ("thinking", "Thinking..."),
        ("idle", "")
    ]
    
    def advance_demo(*args):
        if not demo_states:
            return False
        st, msg = demo_states.pop(0)
        store.set_state(st, msg)
        return True
        
    GLib.timeout_add(2000, advance_demo)
    
    win = ChatPanelWindow(store, session=session)
    win.run()
