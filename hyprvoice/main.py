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
    else:
        print("HyprVoice v2 launcher ready")

if __name__ == "__main__":
    main()
