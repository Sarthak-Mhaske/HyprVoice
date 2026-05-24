from __future__ import annotations
from typing import Any

from hyprvoice.core.transcription_flow import (
    record_and_transcribe,
    transcribe_existing_audio,
)
from hyprvoice.core.context import detect_environment
from hyprvoice.core.agent import build_system_prompt, run_single_tool_turn_with_followup
from hyprvoice.core.tts import speak_text

def build_voice_user_text(flow_result: dict[str, Any]) -> str:
    """Extract the best text from a transcription flow result to send to the LLM."""
    if not flow_result or not flow_result.get("ok"):
        return ""
        
    en_text = flow_result.get("english_text", "").strip()
    if en_text:
        return en_text
        
    trans_text = flow_result.get("transcription_text", "").strip()
    if trans_text:
        return trans_text
        
    return ""

def should_append_voice_user_message(user_text: str) -> bool:
    return bool(user_text.strip())

def should_append_voice_assistant_message(assistant_text: str) -> bool:
    return bool(assistant_text.strip())

def _build_unified_result(ok: bool, user_text: str, assistant_text: str, trans_res: dict[str, Any] | None, agent_res: dict[str, Any] | None, tts_res: dict[str, Any] | None, error: str | None) -> dict[str, Any]:
    return {
        "ok": ok,
        "user_text": user_text,
        "assistant_text": assistant_text,
        "transcription": trans_res,
        "agent": agent_res,
        "tts": tts_res,
        "error": error
    }

def run_voice_pipeline_from_audio(audio_path: str, config: dict[str, Any], speak_reply: bool = True, state_store: Any | None = None, session: Any | None = None) -> dict[str, Any]:
    """Execute the STT -> LLM/Tool -> TTS pipeline from an existing audio file."""
    
    if state_store:
        state_store.set_state("transcribing", "Transcribing audio file...")
        
    # 1. Transcribe
    trans_res = transcribe_existing_audio(audio_path, config, translate_if_needed=True)
    if not trans_res["ok"]:
        return _build_unified_result(False, "", "", trans_res, None, None, trans_res.get("error", "Transcription failed"))
        
    # 2. Extract Text
    user_text = build_voice_user_text(trans_res)
    if not user_text:
        return _build_unified_result(False, "", "", trans_res, None, None, "No text transcribed")
        
    # 3. Agent Execution
    if state_store:
        state_store.set_state("thinking", "Generating response...")
        
    if session and should_append_voice_user_message(user_text):
        session.add_user_message(user_text)
        
    if session:
        if session._system_prompt is None:
            env = detect_environment()
            session.set_system_prompt(build_system_prompt(env))
        api_messages = session.build_api_messages()
        sys_prompt = ""
    else:
        env = detect_environment()
        sys_prompt = build_system_prompt(env)
        api_messages = [{"role": "user", "content": user_text}]
    
    agent_res = run_single_tool_turn_with_followup(api_messages, config, system_prompt=sys_prompt)
    
    if state_store and agent_res.get("mode") in ("tool_call", "tool_followup"):
        state_store.set_state("executing", "Running tool...")
        
    if not agent_res["ok"]:
        return _build_unified_result(False, user_text, agent_res.get("assistant_content", ""), trans_res, agent_res, None, agent_res.get("error", "Agent execution failed"))
        
    assistant_text = agent_res.get("assistant_content", "").strip()
    if session and agent_res["ok"] and should_append_voice_assistant_message(assistant_text):
        session.add_assistant_message(assistant_text)
    
    # 4. TTS Execution
    tts_res = None
    if speak_reply and assistant_text:
        if state_store:
            state_store.set_state("speaking", "Synthesizing speech...")
        tts_res = speak_text(assistant_text, config, lang="english")
        
    return _build_unified_result(True, user_text, assistant_text, trans_res, agent_res, tts_res, None)

def run_voice_pipeline(config: dict[str, Any], duration: float | None = None, speak_reply: bool = True, state_store: Any | None = None, session: Any | None = None) -> dict[str, Any]:
    """Execute the Record -> STT -> LLM/Tool -> TTS pipeline."""
    
    if state_store:
        state_store.set_state("transcribing", "Listening and transcribing...")
        
    # 1. Record and Transcribe
    trans_res = record_and_transcribe(config, duration=duration)
    if not trans_res["ok"]:
        return _build_unified_result(False, "", "", trans_res, None, None, trans_res.get("error", "Recording/Transcription failed"))
        
    # 2. Extract Text
    user_text = build_voice_user_text(trans_res)
    if not user_text:
        return _build_unified_result(False, "", "", trans_res, None, None, "No text transcribed")
        
    # 3. Agent Execution
    if state_store:
        state_store.set_state("thinking", "Generating response...")
        
    if session and should_append_voice_user_message(user_text):
        session.add_user_message(user_text)
        
    if session:
        if session._system_prompt is None:
            env = detect_environment()
            session.set_system_prompt(build_system_prompt(env))
        api_messages = session.build_api_messages()
        sys_prompt = ""
    else:
        env = detect_environment()
        sys_prompt = build_system_prompt(env)
        api_messages = [{"role": "user", "content": user_text}]
    
    agent_res = run_single_tool_turn_with_followup(api_messages, config, system_prompt=sys_prompt)
    
    if state_store and agent_res.get("mode") in ("tool_call", "tool_followup"):
        state_store.set_state("executing", "Running tool...")
        
    if not agent_res["ok"]:
        return _build_unified_result(False, user_text, agent_res.get("assistant_content", ""), trans_res, agent_res, None, agent_res.get("error", "Agent execution failed"))
        
    assistant_text = agent_res.get("assistant_content", "").strip()
    if session and agent_res["ok"] and should_append_voice_assistant_message(assistant_text):
        session.add_assistant_message(assistant_text)
    
    # 4. TTS Execution
    tts_res = None
    if speak_reply and assistant_text:
        if state_store:
            state_store.set_state("speaking", "Synthesizing speech...")
        tts_res = speak_text(assistant_text, config, lang="english")
        
    return _build_unified_result(True, user_text, assistant_text, trans_res, agent_res, tts_res, None)
