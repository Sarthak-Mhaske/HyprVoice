"""Shared GTK application that launches both the overlay and chat panel together."""
from __future__ import annotations
from typing import Any

from hyprvoice.core.state import AssistantStateStore

def check_ui_app_dependencies() -> dict[str, bool]:
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

def ui_app_available() -> bool:
    deps = check_ui_app_dependencies()
    return deps["gi"] and deps["gtk4"]

def build_demo_session_messages() -> list[dict[str, str]]:
    return [
        {"role": "user", "content": "Open YouTube for me"},
        {"role": "assistant", "content": "Opening YouTube in your browser."},
        {"role": "user", "content": "What time is it?"},
        {"role": "assistant", "content": "It is currently 10:08 AM IST."},
    ]

def build_demo_state_sequence() -> list[dict[str, str]]:
    return [
        {"state": "listening", "message": "Hearing mic..."},
        {"state": "transcribing", "message": "Converting speech..."},
        {"state": "thinking", "message": "Thinking..."},
        {"state": "executing", "message": "Running tool..."},
        {"state": "speaking", "message": "Replying..."},
        {"state": "idle", "message": ""},
    ]

def launch_shared_ui_demo() -> None:
    if not ui_app_available():
        print("GTK4 dependencies missing, cannot launch shared UI.")
        return
    
    from hyprvoice.core.session import ConversationSession
    from hyprvoice.ui.overlay import OverlayWindow
    from hyprvoice.ui.chat_panel import ChatPanelWindow
    
    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import Gtk, GLib
    
    store = AssistantStateStore()
    session = ConversationSession()
    for msg in build_demo_session_messages():
        session.add_message(msg["role"], msg["content"])
    
    overlay = OverlayWindow(store)
    panel = ChatPanelWindow(store, session=session)
    
    demo_states = build_demo_state_sequence()
    
    def advance_demo(*_args):
        if not demo_states:
            return False
        entry = demo_states.pop(0)
        store.set_state(entry["state"], entry["message"])
        return True
    
    app = Gtk.Application(application_id="org.hyprvoice.app")
    
    def on_activate(gtk_app):
        overlay.build_window(gtk_app)
        panel.build_window(gtk_app)
        GLib.timeout_add(1500, advance_demo)
    
    app.connect("activate", on_activate)
    app.run(None)

def launch_shared_ui_live(config: dict[str, Any]) -> None:
    if not ui_app_available():
        print("GTK4 dependencies missing, cannot launch shared UI.")
        return
    
    from hyprvoice.core.session import ConversationSession
    from hyprvoice.ui.overlay import OverlayWindow
    from hyprvoice.ui.chat_panel import ChatPanelWindow
    
    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import Gtk
    
    store = AssistantStateStore()
    session = ConversationSession()
    
    overlay = OverlayWindow(store)
    panel = ChatPanelWindow(store, session=session, config=config)
    
    app = Gtk.Application(application_id="org.hyprvoice.app")
    
    def on_activate(gtk_app):
        overlay.build_window(gtk_app)
        panel.build_window(gtk_app)
    
    app.connect("activate", on_activate)
    app.run(None)
