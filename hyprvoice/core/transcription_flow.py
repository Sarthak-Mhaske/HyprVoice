from __future__ import annotations

import os
from typing import Any

from hyprvoice.core.record import record_audio
from hyprvoice.core.stt import (
    transcribe_with_retry_for_indic,
    translate_audio_file,
    needs_translation,
)

def _empty_flow_result(audio_path: str | None = None) -> dict[str, Any]:
    return {
        "ok": False,
        "audio_path": audio_path,
        "transcription_text": "",
        "english_text": "",
        "translated": False,
        "recording_backend": None,
        "language_hint_used": None,
        "transcription_error": None,
        "translation_error": None,
        "error": None,
        "raw": {
            "transcription": None,
            "translation": None,
        },
    }

def transcribe_existing_audio(audio_path: str, config: dict[str, Any], translate_if_needed: bool = True) -> dict[str, Any]:
    """Transcribes audio, handling indic retry, and optionally translating if needed."""
    res = _empty_flow_result(audio_path=audio_path)
    
    if not os.path.exists(audio_path):
        res["error"] = f"Audio file not found: {audio_path}"
        return res
        
    stt_res = transcribe_with_retry_for_indic(audio_path, config)
    res["raw"]["transcription"] = stt_res.get("raw")
    res["language_hint_used"] = stt_res.get("language_hint_used")
    
    if not stt_res["ok"]:
        res["transcription_error"] = stt_res.get("error")
        res["error"] = stt_res.get("error")
        return res
        
    text = stt_res["text"]
    res["transcription_text"] = text
    
    # Check if translation is needed
    if translate_if_needed and needs_translation(text):
        res["translated"] = True
        tl_res = translate_audio_file(audio_path, config)
        res["raw"]["translation"] = tl_res.get("raw")
        
        if not tl_res["ok"]:
            res["translation_error"] = tl_res.get("error")
            res["error"] = "Translation failed after successful transcription."
            res["ok"] = False
            return res
            
        res["english_text"] = tl_res["text"]
        res["ok"] = True
    else:
        res["translated"] = False
        res["english_text"] = text
        res["ok"] = True
        
    return res

def record_and_transcribe(config: dict[str, Any], duration: float | None = None, output_path: str | None = None, translate_if_needed: bool = True) -> dict[str, Any]:
    """Records audio and immediately pipes it through the transcription+translation flow."""
    rec_res = record_audio(config, output_path=output_path, duration=duration)
    
    if not rec_res["ok"]:
        res = _empty_flow_result(audio_path=rec_res.get("audio_path"))
        res["recording_backend"] = rec_res.get("backend")
        res["error"] = rec_res.get("error")
        return res
        
    audio_path = rec_res["audio_path"]
    backend = rec_res["backend"]
    
    flow_res = transcribe_existing_audio(audio_path, config, translate_if_needed=translate_if_needed)
    flow_res["recording_backend"] = backend
    
    # Note: we do not delete the recording file yet per constraints.
    return flow_res
