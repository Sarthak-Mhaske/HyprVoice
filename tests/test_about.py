from hyprvoice.__about__ import __version__, __status__, __title__

def test_about_version():
    assert isinstance(__version__, str)
    assert len(__version__) > 0
    assert "0.1.0" in __version__

def test_about_status():
    assert isinstance(__status__, str)
    assert __status__ == "alpha"

def test_about_title():
    assert isinstance(__title__, str)
    assert __title__ == "hyprvoice"
