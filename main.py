import vosk
import pyaudio
import json
import noisereduce as nr
import numpy as np
import time

# Update the path to where you downloaded and extracted the model
model = vosk.Model("D:/IIT/SDGP/Project_VocalLabs/vosk_model")  # Correct model path
recognizer = vosk.KaldiRecognizer(model, 16000)

# Initialize list to store transcriptions
transcriptions = []

# Initialize pyaudio for microphone input
p = pyaudio.PyAudio()

# Open microphone stream
stream = p.open(format=pyaudio.paInt16, channels=1, rate=16000, input=True, frames_per_buffer=8000)
stream.start_stream()

print("Listening...")

last_transcription_time = time.time()  # Time of last transcription

while True:
    try:
        # Read audio data from the microphone
        data = stream.read(4000)
        audio_data = np.frombuffer(data, dtype=np.int16)
        
        # Apply noise reduction
        reduced_noise = nr.reduce_noise(y=audio_data, sr=16000)
        
        # Recognize the audio with Vosk
        if recognizer.AcceptWaveform(reduced_noise.tobytes()):
            result = json.loads(recognizer.Result())  # Parse the result
            transcription = result.get('text', '')
            
            if transcription:  # Only add non-empty transcriptions
                # Get the current time
                current_time = time.time()
                
                # Check if the time between this transcription and the last is significant (indicating pause)
                time_diff = current_time - last_transcription_time
                
                # If there's a significant pause (more than 2 seconds), consider it the end of a sentence
                if time_diff > 2:  # 2 seconds pause indicates a sentence break
                    # Add a full stop to the transcription if it's a complete sentence
                    transcription = transcription.strip() + '.'
                
                # Add the transcription to the list
                transcriptions.append(transcription)
                
                # Print the updated transcription list
                print(f"Transcription: {', '.join(transcriptions)}\n")
                
                # Update the time of the last transcription
                last_transcription_time = current_time
    
    except Exception as e:
        print(f"Error: {e}")
