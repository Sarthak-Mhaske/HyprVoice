import sys
import pprint
from hyprvoice.core.context import detect_environment, format_context_for_llm
from hyprvoice.core.doctor import collect_doctor_report, format_doctor_report
from hyprvoice.core.config import load_config
from hyprvoice.core.transcription_flow import transcribe_existing_audio
from hyprvoice.core.agent import chat_completion_with_fallback, build_system_prompt

def main():
    if "doctor" in sys.argv or "--doctor" in sys.argv:
        print(format_doctor_report(collect_doctor_report()))
    elif "--context" in sys.argv:
        print(format_context_for_llm(detect_environment()))
    elif "transcribe-file" in sys.argv:
        try:
            idx = sys.argv.index("transcribe-file")
            file_path = sys.argv[idx + 1]
            cfg = load_config()
            res = transcribe_existing_audio(file_path, cfg)
            pprint.pp(res)
        except IndexError:
            print("Usage: hyprvoice transcribe-file <path-to-wav>")
    elif "ask" in sys.argv:
        try:
            idx = sys.argv.index("ask")
            prompt = sys.argv[idx + 1]
            cfg = load_config()
            env = detect_environment()
            sys_prompt = build_system_prompt(env)
            res = chat_completion_with_fallback([{"role": "user", "content": prompt}], cfg, system_prompt=sys_prompt)
            if res["ok"]:
                print(res["content"])
            else:
                print(f"Error: {res['error']}")
        except IndexError:
            print("Usage: hyprvoice ask \"your prompt here\"")
    elif "tool" in sys.argv:
        import json
        from hyprvoice.core.tool_executor import execute_tool
        try:
            idx = sys.argv.index("tool")
            tool_name = sys.argv[idx + 1]
            tool_args_str = sys.argv[idx + 2]
            
            try:
                args = json.loads(tool_args_str)
            except json.JSONDecodeError:
                print("Error: Tool arguments must be valid JSON")
                sys.exit(1)
                
            res = execute_tool(tool_name, args)
            pprint.pp(res)
        except IndexError:
            print("Usage: hyprvoice tool <name> '<json_args>'")
    elif "ask-tools" in sys.argv:
        try:
            idx = sys.argv.index("ask-tools")
            prompt = sys.argv[idx + 1]
            cfg = load_config()
            env = detect_environment()
            sys_prompt = build_system_prompt(env)
            from hyprvoice.core.agent import run_single_tool_turn
            res = run_single_tool_turn([{"role": "user", "content": prompt}], cfg, system_prompt=sys_prompt)
            pprint.pp(res)
        except IndexError:
            print("Usage: hyprvoice ask-tools \"your prompt here\"")
    elif "ask-tools-final" in sys.argv:
        try:
            idx = sys.argv.index("ask-tools-final")
            prompt = sys.argv[idx + 1]
            cfg = load_config()
            env = detect_environment()
            sys_prompt = build_system_prompt(env)
            from hyprvoice.core.agent import run_single_tool_turn_with_followup
            res = run_single_tool_turn_with_followup([{"role": "user", "content": prompt}], cfg, system_prompt=sys_prompt)
            pprint.pp(res)
        except IndexError:
            print("Usage: hyprvoice ask-tools-final \"your prompt here\"")
    elif "voice-once" in sys.argv:
        from hyprvoice.core.voice_pipeline import run_voice_pipeline
        speak = "--no-speak" not in sys.argv
        cfg = load_config()
        res = run_voice_pipeline(cfg, speak_reply=speak)
        pprint.pp(res)
    elif "voice-file" in sys.argv:
        from hyprvoice.core.voice_pipeline import run_voice_pipeline_from_audio
        try:
            idx = sys.argv.index("voice-file")
            audio_path = sys.argv[idx + 1]
            cfg = load_config()
            res = run_voice_pipeline_from_audio(audio_path, cfg, speak_reply=True)
            pprint.pp(res)
        except IndexError:
            print("Usage: hyprvoice voice-file <path-to-wav>")
    elif "listen" in sys.argv or "run-assistant" in sys.argv:
        from hyprvoice.core.assistant_loop import run_assistant_loop
        cfg = load_config()
        run_assistant_loop(cfg)
    elif "state-demo" in sys.argv:
        from hyprvoice.core.state import AssistantStateStore
        import time
        s = AssistantStateStore()
        s.subscribe(lambda snap: print(f"[STATE CHANGED] {snap['state']}: {snap['message']}"))
        for st in ["listening", "transcribing", "thinking", "executing", "speaking", "idle"]:
            s.set_state(st, f"Entering {st}")
            time.sleep(0.5)
    elif "overlay-demo" in sys.argv:
        from hyprvoice.ui.overlay import launch_overlay_demo
        launch_overlay_demo()
    else:
        print("HyprVoice v2 launcher ready")

if __name__ == "__main__":
    main()
