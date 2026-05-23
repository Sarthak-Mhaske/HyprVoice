from __future__ import annotations

import shutil
import subprocess
import urllib.parse
from typing import Any

def _command_exists(name: str) -> bool:
    return shutil.which(name) is not None

def _success_result(tool: str, message: str, data: Any = None) -> dict[str, Any]:
    return {
        "ok": True,
        "tool": tool,
        "message": message,
        "error": None,
        "data": data,
    }

def _failure_result(tool: str, error: str, message: str = "") -> dict[str, Any]:
    return {
        "ok": False,
        "tool": tool,
        "message": message,
        "error": error,
        "data": None,
    }

def execute_notify(args: dict[str, Any]) -> dict[str, Any]:
    if not _command_exists("notify-send"):
        return _failure_result("notify", "Command 'notify-send' not found.")
        
    title = args.get("title", "")
    body = args.get("body", args.get("message", ""))
    
    if not title and body:
        title = "HyprVoice"
    elif title and not body:
        body = title
        title = "HyprVoice"
        
    if not title and not body:
        return _failure_result("notify", "No message provided for notification.")
        
    cmd = ["notify-send", str(title), str(body)]
    
    urgency = args.get("urgency")
    if urgency in ("low", "normal", "critical"):
        cmd.extend(["-u", urgency])
        
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return _success_result("notify", "Notification sent.", data={"title": title, "body": body})
    except Exception as e:
        return _failure_result("notify", f"Failed to send notification: {str(e)}")

def execute_open_url(args: dict[str, Any]) -> dict[str, Any]:
    url = args.get("url", "")
    
    if not url:
        return _failure_result("open_url", "No URL provided.")
        
    url_str = str(url).strip()
    if not url_str.startswith(("http://", "https://")):
        return _failure_result("open_url", "Invalid URL scheme. Must start with http:// or https://")
        
    if not _command_exists("xdg-open"):
        return _failure_result("open_url", "Command 'xdg-open' not found.")
        
    try:
        subprocess.run(["xdg-open", url_str], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return _success_result("open_url", f"Opened URL: {url_str}", data={"url": url_str})
    except Exception as e:
        return _failure_result("open_url", f"Failed to open URL: {str(e)}")

def execute_google_search(args: dict[str, Any]) -> dict[str, Any]:
    query = args.get("query", "")
    
    if not query:
        return _failure_result("google_search", "No search query provided.")
        
    encoded = urllib.parse.quote_plus(str(query))
    url = f"https://www.google.com/search?q={encoded}"
    
    res = execute_open_url({"url": url})
    if res["ok"]:
        res["tool"] = "google_search"
        res["message"] = f"Performed search for: {query}"
        res["data"]["query"] = query
    else:
        res["tool"] = "google_search"
        
    return res

def execute_tool(name: str, args: dict[str, Any], config: dict[str, Any] | None = None) -> dict[str, Any]:
    if name == "notify":
        return execute_notify(args)
    elif name == "open_url":
        return execute_open_url(args)
    elif name == "google_search":
        return execute_google_search(args)
    else:
        return _failure_result(name, f"Tool not implemented yet: {name}")
