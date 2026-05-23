from hyprvoice.core.context import (
    detect_environment,
    detect_os,
    detect_wm,
    detect_audio_system,
    detect_display_server,
    detect_browser,
    detect_terminal,
    detect_screenshot_tool,
    detect_package_manager,
    scan_installed_apps,
    format_context_for_llm,
)

def test_detect_environment():
    env = detect_environment()
    assert isinstance(env, dict)
    expected_keys = {
        "os", "wm", "audio", "display", "browser", 
        "terminal", "screenshot_tool", "package_manager", "installed_apps"
    }
    assert expected_keys.issubset(env.keys())

def test_string_helpers():
    assert isinstance(detect_os(), str)
    assert isinstance(detect_wm(), str)
    assert isinstance(detect_audio_system(), str)
    assert isinstance(detect_display_server(), str)
    assert isinstance(detect_browser(), str)
    assert isinstance(detect_terminal(), str)
    assert isinstance(detect_package_manager(), str)

def test_detect_screenshot_tool():
    tool = detect_screenshot_tool()
    assert tool is None or isinstance(tool, str)

def test_scan_installed_apps():
    apps = scan_installed_apps()
    assert isinstance(apps, list)

def test_format_context_for_llm():
    env = detect_environment()
    out = format_context_for_llm(env)
    assert isinstance(out, str)
    assert len(out) > 0
    assert "SYSTEM CONTEXT:" in out
    assert "- OS:" in out
    assert "- Window Manager:" in out
