"""Shared GTK application that launches both the overlay and chat panel together."""
from __future__ import annotations
from typing import Any

from hyprvoice.core.state import AssistantStateStore

def get_ui_application_id() -> str:
    return "ai.hyprvoice.app"

def build_ui_launch_profile(mode: str) -> dict[str, Any]:
    if mode not in ("demo", "live", "assistant"):
        raise ValueError(f"Invalid launch mode: {mode}")
        
    return {
        "mode": mode,
        "show_chat_panel_on_launch": True,
        "overlay_starts_hidden": True,
        "chat_panel_is_primary": True,
    }

def should_overlay_start_hidden(profile: dict[str, Any]) -> bool:
    return profile.get("overlay_starts_hidden", True)

def should_present_chat_panel_on_launch(profile: dict[str, Any]) -> bool:
    return profile.get("show_chat_panel_on_launch", True)

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
    
    profile = build_ui_launch_profile("demo")
    
    store = AssistantStateStore()
    session = ConversationSession()
    for msg in build_demo_session_messages():
        session.add_message(msg["role"], msg["content"])
    
    overlay_hidden = should_overlay_start_hidden(profile)
    panel_present = should_present_chat_panel_on_launch(profile)
    
    overlay = OverlayWindow(store, show_on_start=not overlay_hidden)
    panel = ChatPanelWindow(store, session=session, present_on_start=panel_present)
    
    demo_states = build_demo_state_sequence()
    
    def advance_demo(*_args):
        if not demo_states:
            return False
        entry = demo_states.pop(0)
        store.set_state(entry["state"], entry["message"])
        return True
    
    app = Gtk.Application(application_id=get_ui_application_id())
    
    def on_activate(gtk_app):
        overlay.build_window(gtk_app)
        panel.build_window(gtk_app)
        if panel.window:
            panel.window.connect("close-request", lambda w: gtk_app.quit())
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
    
    profile = build_ui_launch_profile("live")
    
    store = AssistantStateStore()
    session = ConversationSession()
    
    overlay_hidden = should_overlay_start_hidden(profile)
    panel_present = should_present_chat_panel_on_launch(profile)
    
    overlay = OverlayWindow(store, show_on_start=not overlay_hidden)
    panel = ChatPanelWindow(store, session=session, config=config, present_on_start=panel_present)
    
    app = Gtk.Application(application_id=get_ui_application_id())
    
    def on_activate(gtk_app):
        overlay.build_window(gtk_app)
        panel.build_window(gtk_app)
        if panel.window:
            panel.window.connect("close-request", lambda w: gtk_app.quit())
    
    app.connect("activate", on_activate)
    app.run(None)

def build_live_runtime(config: dict[str, Any]) -> dict[str, Any]:
    """Build the shared runtime objects for live assistant mode."""
    from hyprvoice.core.session import ConversationSession
    from hyprvoice.core.assistant_loop import HyprVoiceAssistant

    state_store = AssistantStateStore()
    session = ConversationSession()
    assistant = HyprVoiceAssistant(config, state_store=state_store, session=session)

    return {
        "state_store": state_store,
        "session": session,
        "assistant": assistant,
        "config": config,
    }

def run_assistant_worker(assistant: Any, state_store: AssistantStateStore) -> None:
    """Run the assistant loop, publishing errors to the state store on failure."""
    try:
        assistant.run_forever()
    except Exception as e:
        state_store.set_state("error", f"Assistant loop crashed: {e}")

def start_assistant_background(assistant: Any, state_store: AssistantStateStore) -> Any:
    """Start the assistant loop in a daemon thread."""
    import threading
    thread = threading.Thread(
        target=run_assistant_worker,
        args=(assistant, state_store),
        daemon=True,
    )
    thread.start()
    return thread

def stop_assistant_background(assistant: Any) -> None:
    """Stop the assistant loop gracefully."""
    try:
        assistant.stop()
    except Exception:
        pass

def launch_shared_ui_with_assistant(config: dict[str, Any]) -> None:
    if not ui_app_available():
        print("GTK4 dependencies missing, cannot launch shared UI.")
        return

    from hyprvoice.ui.overlay import OverlayWindow
    from hyprvoice.ui.chat_panel import ChatPanelWindow

    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import Gtk

    profile = build_ui_launch_profile("assistant")
    
    runtime = build_live_runtime(config)
    store = runtime["state_store"]
    session = runtime["session"]
    assistant = runtime["assistant"]

    overlay_hidden = should_overlay_start_hidden(profile)
    panel_present = should_present_chat_panel_on_launch(profile)

    overlay = OverlayWindow(store, show_on_start=not overlay_hidden)
    panel = ChatPanelWindow(store, session=session, config=config, present_on_start=panel_present)

    app = Gtk.Application(application_id=get_ui_application_id())

    def on_activate(gtk_app):
        overlay.build_window(gtk_app)
        panel.build_window(gtk_app)
        if panel.window:
            panel.window.connect("close-request", lambda w: gtk_app.quit())
        start_assistant_background(assistant, store)

    app.connect("activate", on_activate)
    try:
        app.run(None)
    finally:
        stop_assistant_background(assistant)
