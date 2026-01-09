import pyaudio
import numpy as np
from openwakeword.model import Model
import os
import time

# --- CONFIG ---
WAKE_WORD = "alexa"
THRESHOLD = 0.5
TRIGGER_FILE = "/tmp/voice_active"
ASSISTANT_SCRIPT = "bash $HOME/.config/hypr/scripts/voice-assistant.sh"

print(f"🎤 Loading Model...")
owwModel = Model()

p = pyaudio.PyAudio()
stream = p.open(format=pyaudio.paInt16, channels=1, rate=16000, input=True, frames_per_buffer=1280)

print(f"👂 Listening for '{WAKE_WORD}'...")

cooldown = 0

try:
    while True:
        data = np.frombuffer(stream.read(1280, exception_on_overflow=False), dtype=np.int16)
        prediction = owwModel.predict(data)
        
        if prediction[WAKE_WORD] > THRESHOLD:
            if time.time() - cooldown > 2:
                print(f"⚡ DETECTED! Starting HyprVoice...")
                
                # Kill audio
                os.system("pkill -9 paplay 2>/dev/null")
                os.system("pkill -9 -f piper 2>/dev/null")
                
                # Trigger UI + Assistant
                os.system(f"touch {TRIGGER_FILE}")
                os.system(ASSISTANT_SCRIPT)
                os.system(f"rm -f {TRIGGER_FILE}")
                
                cooldown = time.time()

except KeyboardInterrupt:
    pass
finally:
    stream.stop_stream()
    stream.close()
    p.terminate()
