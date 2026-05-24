from hyprvoice.core.session import ConversationSession

def test_session_init():
    s = ConversationSession("sys prompt")
    assert s.message_count() == 0
    msgs = s.build_api_messages()
    assert len(msgs) == 1
    assert msgs[0]["role"] == "system"

def test_add_messages():
    s = ConversationSession()
    # Reject empty
    assert s.add_user_message("   ") == False
    assert s.message_count() == 0
    
    # Accept valid
    assert s.add_user_message("hello") == True
    assert s.add_assistant_message("world") == True
    assert s.message_count() == 2
    
    assert s.last_assistant_message() == "world"

def test_clear_session():
    s = ConversationSession("sys")
    s.add_user_message("test")
    assert s.message_count() == 1
    
    s.clear(keep_system_prompt=True)
    assert s.message_count() == 0
    assert len(s.build_api_messages()) == 1
    
    s.clear(keep_system_prompt=False)
    assert len(s.build_api_messages()) == 0

def test_build_api_messages():
    s = ConversationSession("system instructions")
    s.add_user_message("user msg")
    s.add_assistant_message("assistant reply")
    
    api_msgs = s.build_api_messages()
    assert len(api_msgs) == 3
    assert api_msgs[0] == {"role": "system", "content": "system instructions"}
    assert api_msgs[1] == {"role": "user", "content": "user msg"}
    assert api_msgs[2] == {"role": "assistant", "content": "assistant reply"}

def test_session_revision_logic():
    s = ConversationSession()
    assert s.get_revision() == 0
    
    # Successful add increments
    s.add_user_message("hello")
    assert s.get_revision() == 1
    
    # Empty add does not increment
    s.add_user_message("   ")
    assert s.get_revision() == 1
    
    # Setting same prompt does not increment
    s.set_system_prompt(None)
    assert s.get_revision() == 1
    
    # Setting new prompt increments
    s.set_system_prompt("new prompt")
    assert s.get_revision() == 2
    
    # Clear with no prompt change
    s.clear(keep_system_prompt=True)
    assert s.get_revision() == 3
    
    # Clear empty does not increment if nothing changed
    s.clear(keep_system_prompt=True)
    assert s.get_revision() == 3
