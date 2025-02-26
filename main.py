import whisper
import torch
import re

class SpeechAnalyzer:
    def __init__(self, model_name="medium", audio_path="D:\\IntelijiProjects\\sampleCheck1\\didula_audio01.wav"):
        self.model = whisper.load_model("medium")
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
                "and false start. Do not clean up or correct the speech. Transcribe with maximum verbatim accuracy."
            )
        )
        return result["text"]  # Extract only the transcription text

    def process_transcription(self, result):
        for i in range(len(result['segments'])):
            segment = result['segments'][i]
            words_in_segment = segment.get('words', [])

            for j in range(len(words_in_segment)):
                word_info = words_in_segment[j]
                word = word_info['word']
                self.transcription_with_pauses.append(word)

                if j < len(words_in_segment) - 1:
                    current_word_end = word_info['end']
                    next_word_start = words_in_segment[j + 1]['start']
                    time_gap = next_word_start - current_word_end
                    if time_gap >= 1.0:
                        pause_duration = round(time_gap, 1)
                        pause_marker = f"[{pause_duration} second pause]"
                        self.transcription_with_pauses.append(pause_marker)

            if i < len(result['segments']) - 1:
                current_segment_end = segment['end']
                next_segment_start = result['segments'][i + 1]['start']
                time_gap = next_segment_start - current_segment_end
                if time_gap >= 2.0:
                    pause_duration = round(time_gap, 1)
                    pause_marker = f"[{pause_duration} second pause]"
                    self.transcription_with_pauses.append(pause_marker)
                    self.number_of_pauses += 1

        self.transcription_with_pauses = ' '.join(self.transcription_with_pauses)
        self.transcription_with_pauses = re.sub(r'\s+', ' ', self.transcription_with_pauses).strip()
        print(self.transcription_with_pauses)  # Print processed transcription with pauses

# Example usage
if __name__ == "__main__":
    analyzer = SpeechAnalyzer()
    result = analyzer.transcribe_audio()
    print(result)  # Print only the transcript text
    analyzer.process_transcription(result)
