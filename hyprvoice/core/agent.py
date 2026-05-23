from __future__ import annotations

import json
from typing import Any, Iterator

import requests

from hyprvoice.core.config import pick_groq_api_key, get_groq_api_keys
from hyprvoice.core.context import detect_environment, format_context_for_llm

def build_system_prompt(env: dict[str, Any] | None = None, extra_instructions: str | None = None) -> str:
    """Build the root system prompt for the HyprVoice assistant."""
    lines = [
        "You are HyprVoice, a highly efficient Linux desktop voice assistant.",
        "Your goal is to be concise, action-oriented, and immediately helpful.",
        "Do not use overly formal pleasantries or long conversational filler.",
    ]
    
    if env:
        lines.append("\n--- SYSTEM CONTEXT ---")
        lines.append(format_context_for_llm(env))
        lines.append("----------------------\n")
        
    if extra_instructions:
        lines.append(extra_instructions)
        
    return "\n".join(lines)

def normalize_messages(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Clean and normalize chat messages for the OpenAI-compatible endpoint."""
    clean = []
    valid_roles = {"system", "user", "assistant"}
    
    for m in messages:
        if not isinstance(m, dict):
            continue
            
        role = m.get("role", "").strip().lower()
        content = m.get("content", "")
        
        if not isinstance(content, str):
            content = str(content)
            
        content = content.strip()
        
        if role in valid_roles and content:
            clean.append({"role": role, "content": content})
            
    return clean

def get_llm_config(config: dict[str, Any]) -> dict[str, Any]:
    llm = config.get("llm", {})
    return {
        "provider": str(llm.get("provider", "groq")),
        "model": str(llm.get("model", "llama-3.3-70b-versatile")),
        "temperature": float(llm.get("temperature", 0.3)),
        "max_tokens": int(llm.get("max_tokens", 512)),
        "base_url": str(llm.get("base_url", "https://api.groq.com/openai/v1/chat/completions")),
        "fallback_models": list(llm.get("fallback_models", [
            "llama-3.3-70b-versatile",
            "meta-llama/llama-4-scout-17b-16e-instruct",
            "meta-llama/llama-4-maverick-17b-128e-instruct"
        ])),
        "retry_on_rate_limit": bool(llm.get("retry_on_rate_limit", True)),
        "max_attempts": int(llm.get("max_attempts", 3))
    }

def build_model_chain(config: dict[str, Any], preferred_model: str | None = None) -> list[str]:
    cfg = get_llm_config(config)
    chain = []
    
    if preferred_model:
        chain.append(preferred_model)
        
    chain.append(cfg["model"])
    chain.extend(cfg["fallback_models"])
    
    seen = set()
    result = []
    for m in chain:
        if m and m not in seen:
            seen.add(m)
            result.append(m)
            
    return result

def is_rate_limit_error(status_code: int, raw: dict[str, Any] | None) -> bool:
    if status_code == 429:
        return True
        
    if raw and isinstance(raw, dict):
        err = raw.get("error", {})
        if isinstance(err, dict):
            code = str(err.get("code", "")).lower()
            msg = str(err.get("message", "")).lower()
            if "rate_limit" in code or "rate limit" in msg:
                return True
            if "quota" in code or "quota" in msg:
                return True
            if "too_many_requests" in code or "too many requests" in msg:
                return True
                
    return False

def chat_completion_once(messages: list[dict[str, Any]], config: dict[str, Any], system_prompt: str | None = None, model_override: str | None = None, api_key: str | None = None) -> dict[str, Any]:
    llm_cfg = get_llm_config(config)
    model = model_override if model_override else llm_cfg["model"]
    base_url = llm_cfg["base_url"]
    
    key = api_key if api_key else pick_groq_api_key(config)
    if not key:
        return {
            "ok": False,
            "model": model,
            "content": "",
            "error": "No Groq API key configured.",
            "status_code": 401,
            "raw": None
        }

    if system_prompt is None:
        system_prompt = build_system_prompt()
        
    normalized = normalize_messages(messages)
    payload_messages = []
    if system_prompt.strip():
        payload_messages.append({"role": "system", "content": system_prompt.strip()})
    payload_messages.extend(normalized)
    
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": model,
        "messages": payload_messages,
        "temperature": llm_cfg["temperature"],
        "max_tokens": llm_cfg["max_tokens"],
        "stream": False
    }
    
    try:
        res = requests.post(base_url, headers=headers, json=payload, timeout=30.0)
        raw = res.json()
        
        if res.status_code == 200 and "choices" in raw and raw["choices"]:
            return {
                "ok": True,
                "model": raw.get("model", model),
                "content": raw["choices"][0].get("message", {}).get("content", "").strip(),
                "error": None,
                "status_code": 200,
                "raw": raw
            }
        else:
            err_msg = raw.get("error", {}).get("message", "Unknown API error")
            return {
                "ok": False,
                "model": model,
                "content": "",
                "error": f"Groq API Error {res.status_code}: {err_msg}",
                "status_code": res.status_code,
                "raw": raw
            }
    except Exception as e:
        return {
            "ok": False,
            "model": model,
            "content": "",
            "error": f"Request failed: {str(e)}",
            "status_code": 500,
            "raw": None
        }

def chat_completion_with_fallback(messages: list[dict[str, Any]], config: dict[str, Any], system_prompt: str | None = None, preferred_model: str | None = None) -> dict[str, Any]:
    llm_cfg = get_llm_config(config)
    models = build_model_chain(config, preferred_model)
    from hyprvoice.core.config import get_groq_api_keys
    keys = get_groq_api_keys(config)
    
    if not keys:
        return {
            "ok": False,
            "model": models[0] if models else "",
            "content": "",
            "error": "No Groq API key configured.",
            "status_code": 401,
            "attempts": [],
            "fallback_used": False,
            "raw": None
        }
        
    attempts = []
    
    for attempt_idx in range(llm_cfg["max_attempts"]):
        model = models[attempt_idx % len(models)]
        key_idx = attempt_idx % len(keys)
        key = keys[key_idx]
        
        res = chat_completion_once(messages, config, system_prompt=system_prompt, model_override=model, api_key=key)
        
        attempt_record = {
            "model": model,
            "key_index": key_idx,
            "ok": res["ok"],
            "status_code": res.get("status_code", 500),
            "error": res["error"]
        }
        attempts.append(attempt_record)
        
        if res["ok"]:
            return {
                "ok": True,
                "model": res["model"],
                "content": res["content"],
                "error": None,
                "status_code": 200,
                "attempts": attempts,
                "fallback_used": attempt_idx > 0,
                "raw": res["raw"]
            }
            
        if not llm_cfg["retry_on_rate_limit"]:
            break
            
        if not is_rate_limit_error(res.get("status_code", 500), res.get("raw")) and res.get("status_code", 500) not in (500, 502, 503, 504):
            break
            
    last_res = attempts[-1] if attempts else {}
    return {
        "ok": False,
        "model": last_res.get("model", ""),
        "content": "",
        "error": f"Failed after {len(attempts)} attempts. Last error: {last_res.get('error')}",
        "status_code": last_res.get("status_code", 500),
        "attempts": attempts,
        "fallback_used": len(attempts) > 1,
        "raw": None
    }
    
def chat_completion(messages: list[dict[str, Any]], config: dict[str, Any], system_prompt: str | None = None, stream: bool = False) -> dict[str, Any]:
    """Legacy wrapper for single-shot completion. Use chat_completion_with_fallback for production."""
    if stream:
        return {
            "ok": False,
            "model": "",
            "content": "",
            "error": "Use stream_chat_completion() for streaming requests.",
            "raw": None
        }
    res = chat_completion_once(messages, config, system_prompt=system_prompt)
    if "status_code" in res:
        del res["status_code"]
    return res

def stream_chat_completion(messages: list[dict[str, Any]], config: dict[str, Any], system_prompt: str | None = None) -> Iterator[dict[str, Any]]:
    """Generator that yields streaming chat completion events from Groq."""
    key = pick_groq_api_key(config)
    if not key:
        yield {"type": "error", "error": "No Groq API key configured."}
        return

    llm_cfg = config.get("llm", {})
    model = llm_cfg.get("model", "llama-3.3-70b-versatile")
    base_url = llm_cfg.get("base_url", "https://api.groq.com/openai/v1/chat/completions")
    temp = float(llm_cfg.get("temperature", 0.3))
    max_tokens = int(llm_cfg.get("max_tokens", 512))
    
    if system_prompt is None:
        system_prompt = build_system_prompt()
        
    normalized = normalize_messages(messages)
    
    payload_messages = []
    if system_prompt.strip():
        payload_messages.append({"role": "system", "content": system_prompt.strip()})
    payload_messages.extend(normalized)
    
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Accept": "text/event-stream"
    }
    
    payload = {
        "model": model,
        "messages": payload_messages,
        "temperature": temp,
        "max_tokens": max_tokens,
        "stream": True
    }
    
    try:
        with requests.post(base_url, headers=headers, json=payload, stream=True, timeout=15.0) as response:
            if response.status_code != 200:
                try:
                    err_raw = response.json()
                    err_msg = err_raw.get("error", {}).get("message", "Unknown error")
                except Exception:
                    err_msg = response.text
                yield {"type": "error", "error": f"Groq API Error {response.status_code}: {err_msg}"}
                return
                
            for line in response.iter_lines():
                if not line:
                    continue
                    
                decoded = line.decode("utf-8").strip()
                if not decoded.startswith("data: "):
                    continue
                    
                data_str = decoded[6:]
                if data_str == "[DONE]":
                    yield {"type": "done"}
                    break
                    
                try:
                    chunk = json.loads(data_str)
                    choices = chunk.get("choices", [])
                    if choices:
                        delta = choices[0].get("delta", {})
                        if "content" in delta and delta["content"]:
                            yield {"type": "delta", "content": delta["content"]}
                except json.JSONDecodeError:
                    continue
                    
    except Exception as e:
        yield {"type": "error", "error": f"Streaming request failed: {str(e)}"}

def chat_with_session(session: Any, user_text: str, config: dict[str, Any]) -> dict[str, Any]:
    """Helper to execute a chat completion using an active ConversationSession."""
    if not session.add_user_message(user_text):
        return {"ok": False, "model": "", "content": "", "error": "Invalid or empty user message.", "raw": None}
        
    res = chat_completion(session.build_api_messages(), config, system_prompt="")
    
    if res["ok"]:
        session.add_assistant_message(res["content"])
        
    return res
