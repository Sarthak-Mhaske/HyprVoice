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

def run_voice_pipeline_from_audio(audio_path: str, config: dict[str, Any], speak_reply: bool = True) -> dict[str, Any]:
    """Execute the STT -> LLM/Tool -> TTS pipeline from an existing audio file."""
    
    # 1. Transcribe
    trans_res = transcribe_existing_audio(audio_path, config, translate_if_needed=True)
    if not trans_res["ok"]:
        return _build_unified_result(False, "", "", trans_res, None, None, trans_res.get("error", "Transcription failed"))
        
    # 2. Extract Text
    user_text = build_voice_user_text(trans_res)
    if not user_text:
        return _build_unified_result(False, "", "", trans_res, None, None, "No text transcribed")
        
    # 3. Agent Execution
    env = detect_environment()
    system_prompt = build_system_prompt(env)
    
    agent_res = run_single_tool_turn_with_followup([{"role": "user", "content": user_text}], config, system_prompt=system_prompt)
    if not agent_res["ok"]:
        return _build_unified_result(False, user_text, agent_res.get("assistant_content", ""), trans_res, agent_res, None, agent_res.get("error", "Agent execution failed"))
        
    assistant_text = agent_res.get("assistant_content", "").strip()
    
    # 4. TTS Execution
    tts_res = None
    if speak_reply and assistant_text:
        # Default to english for now if translation occurred or just implicitly english
        tts_res = speak_text(assistant_text, config, lang="english")
        
    return _build_unified_result(True, user_text, assistant_text, trans_res, agent_res, tts_res, None)

def run_voice_pipeline(config: dict[str, Any], duration: float | None = None, speak_reply: bool = True) -> dict[str, Any]:
    """Execute the Record -> STT -> LLM/Tool -> TTS pipeline."""
    
    # 1. Record and Transcribe
    trans_res = record_and_transcribe(config, duration=duration)
    if not trans_res["ok"]:
        return _build_unified_result(False, "", "", trans_res, None, None, trans_res.get("error", "Recording/Transcription failed"))
        
    # 2. Extract Text
    user_text = build_voice_user_text(trans_res)
    if not user_text:
        return _build_unified_result(False, "", "", trans_res, None, None, "No text transcribed")
        
    # 3. Agent Execution
    env = detect_environment()
    system_prompt = build_system_prompt(env)
    
    agent_res = run_single_tool_turn_with_followup([{"role": "user", "content": user_text}], config, system_prompt=system_prompt)
    if not agent_res["ok"]:
        return _build_unified_result(False, user_text, agent_res.get("assistant_content", ""), trans_res, agent_res, None, agent_res.get("error", "Agent execution failed"))
        
    assistant_text = agent_res.get("assistant_content", "").strip()
    
    # 4. TTS Execution
    tts_res = None
    if speak_reply and assistant_text:
        tts_res = speak_text(assistant_text, config, lang="english")
        
    return _build_unified_result(True, user_text, assistant_text, trans_res, agent_res, tts_res, None)
