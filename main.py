import whisper
import torch

class SpeechAnalyzer:
    def __init__(self, model_name="medium", audio_path="D:\\IntelijiProjects\\sampleCheck1\\didula_audio01.wav"):
        self.model = whisper.load_model(model_name)
        self.audio_path = audio_path
        self.transcription_with_pauses = []
        self.number_of_pauses = 0
        self.device = 0 if torch.cuda.is_available() else -1
        print("SpeechAnalyzer initialized.")

    def transcribe_audio(self):
        result = self.model.transcribe(
            self.audio_path,
            fp16=False,
            word_timestamps=True,
            initial_prompt=(
                "Please transcribe exactly as spoken. Include every um, uh, ah, er, pause, repetition, "
                "and false start. Do not clean up or correct the speech. Transcribe with maximum verbatim accuracy. This is a test."
            )
        )
        self.transcription_with_pauses = result["segments"]  # Store transcription data
        print(result)  # Print the full result

# Example usage
if __name__ == "__main__":
    analyzer = SpeechAnalyzer()
    analyzer.transcribe_audio()
    
