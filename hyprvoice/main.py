import sys
from hyprvoice.core.context import detect_environment, format_context_for_llm

def main():
    if "--context" in sys.argv:
        print(format_context_for_llm(detect_environment()))
    else:
        print("HyprVoice v2 launcher ready")

if __name__ == "__main__":
    main()
