import whisper
import re
from transformers import pipeline
import os
import torch
import nltk
from nltk.tokenize import word_tokenize

# Download required NLTK data
try:
    nltk.download('punkt', quiet=True)
    nltk.download('averaged_perceptron_tagger', quiet=True)
except Exception as e:
    print(f"Error downloading NLTK data: {e}")

class SpeechAnalyzer:
    def __init__(self, model_name="medium", audio_path="D:\\IntelijiProjects\\sampleCheck1\\didula_audio01.wav"):
        self.model = whisper.load_model(model_name)
        self.audio_path = audio_path
        self.transcription_with_pauses = []
        self.number_of_pauses = 0
        self.device = 0 if torch.cuda.is_available() else -1
        self.topic_analyzer = pipeline("zero-shot-classification", model="facebook/bart-large-mnli", device=self.device)
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
        return result  # Return full transcription result

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

    def filler_word_detection(self, transcription):
        filler_count = 0
        filler_words = ["um", "uh", "ah", "ugh", "you know"]
        for word in filler_words:
            filler_count += len(re.findall(r'\b' + re.escape(word) + r'\b', transcription.lower()))
        return filler_count

    def analyze_topic_relevance(self, transcription, topics):
        result = self.topic_analyzer(transcription, topics)
        return result

    def analyze_speech_effectiveness(self, text):
        """Analyze the effectiveness of the speech"""
        try:
            purpose_indicators = [
                "purpose", "goal", "aim", "objective", "today", "discuss",
                "explain", "demonstrate", "show", "present", "introduce"
            ]

            conclusion_indicators = [
                "conclusion", "finally", "in summary", "to sum up", "therefore",
                "thus", "consequently", "in closing", "lastly"
            ]

            words = word_tokenize(text.lower())
            first_50_words = ' '.join(words[:50])

            has_clear_purpose = any(indicator in first_50_words for indicator in purpose_indicators)

            last_50_words = ' '.join(words[-50:])
            has_conclusion = any(indicator in last_50_words for indicator in conclusion_indicators)

            sentences = nltk.sent_tokenize(text)
            avg_sentence_length = sum(len(word_tokenize(sentence)) for sentence in sentences) / len(sentences)

            effectiveness_score = 0
            feedback = []

            if has_clear_purpose:
                effectiveness_score += 30
                feedback.append("Clear purpose statement identified in the introduction.")
            else:
                feedback.append("Consider adding a clear purpose statement at the beginning.")

            if 10 <= avg_sentence_length <= 20:
                effectiveness_score += 20
                feedback.append("Good sentence length variation for clarity.")
            else:
                feedback.append("Consider varying sentence lengths for better flow.")

            if has_conclusion:
                effectiveness_score += 20
                feedback.append("Clear conclusion identified.")
            else:
                feedback.append("Consider adding a strong concluding statement.")

            transition_words = ["however", "moreover", "furthermore", "additionally", "therefore"]
            transition_count = sum(1 for word in words if word.lower() in transition_words)

            if transition_count >= 3:
                effectiveness_score += 30
                feedback.append("Good use of transition words for coherence.")
            else:
                feedback.append("Consider using more transition words to improve flow.")

            return {
                'effectiveness_score': effectiveness_score,
                'purpose_clarity': has_clear_purpose,
                'has_conclusion': has_conclusion,
                'avg_sentence_length': round(avg_sentence_length, 2),
                'feedback': feedback
            }

        except Exception as e:
            print(f"Error in speech effectiveness analysis: {e}")
            return None

    def analyze_purpose_achievement(text, target_keywords=None):
        """Analyze how well the speech achieved its purpose by evaluating content coverage"""
    try:
        # Set default target keywords if none are provided
        if target_keywords is None:
            target_keywords = {
                'main_topics': set(['purpose', 'goal', 'objective', 'discussion', 'demonstration']),
                'key_points': 5,  # Define the number of key points expected in the speech
                'target_length': 300  # Define an ideal length range (e.g., 300 words)
            }

        words = word_tokenize(text.lower())
        word_count = len(words)

        # Evaluate topic coverage based on target keywords
        covered_topics = set(words) & target_keywords['main_topics']
        coverage_ratio = len(covered_topics) / len(target_keywords['main_topics'])

        # Calculate achievement score based on topic coverage, length, and vocabulary
        achievement_score = 0
        feedback = []

        # Topic Coverage
        coverage_points = int(coverage_ratio * 40)
        achievement_score += coverage_points
        if coverage_points < 30:
            feedback.append("Consider covering more key topics thoroughly.")
        else:
            feedback.append("Good coverage of key topics.")

        # Length Appropriateness
        length_ratio = min(word_count / target_keywords['target_length'], 1.5)
        length_points = int(min(length_ratio * 30, 30))
        achievement_score += length_points
        if length_points < 20:
            feedback.append("Speech length could be adjusted for better impact.")
        else:
            feedback.append("Appropriate speech length.")

        # Coherence and Vocabulary Usage
        unique_words_ratio = len(set(words)) / word_count
        coherence_points = int(min(unique_words_ratio * 30, 30))
        achievement_score += coherence_points
        if coherence_points < 20:
            feedback.append("Consider improving focus and reducing repetition.")
        else:
            feedback.append("Good balance of vocabulary and focus.")

        return {
            'achievement_score': achievement_score,
            'coverage_ratio': round(coverage_ratio * 100, 2),
            'length_appropriateness': round(length_ratio * 100, 2),
            'coherence_score': round(unique_words_ratio * 100, 2),
            'feedback': feedback
        }

    except Exception as e:
        print(f"Error in purpose achievement analysis: {e}")
        return None


    def print_analysis(self, transcription, topics):
        print("\nTranscription with pauses:\n")
        print(self.transcription_with_pauses)
        print("\nNumber of pauses detected:", self.number_of_pauses)
        filler_count = self.filler_word_detection(transcription)
        print("\nNumber of filler words detected:", filler_count)
        topic_relevance = self.analyze_topic_relevance(transcription, topics)
        print("\nTopic Relevance Analysis:")
        for label, score in zip(topic_relevance['labels'], topic_relevance['scores']):
            print(f"{label}: {score * 100:.2f}%")

        effectiveness_results = self.analyze_speech_effectiveness(transcription)
        if effectiveness_results:
            print("\n=== Speech Effectiveness Analysis ===")
            print(f"Overall effectiveness score: {effectiveness_results['effectiveness_score']}/100")
            print(f"Clear purpose identified: {'Yes' if effectiveness_results['purpose_clarity'] else 'No'}")
            print(f"Conclusion present: {'Yes' if effectiveness_results['has_conclusion'] else 'No'}")
            print(f"Average sentence length: {effectiveness_results['avg_sentence_length']} words")
            print("\nFeedback:")
            for feedback in effectiveness_results['feedback']:
                print(f"- {feedback}")

if __name__ == "__main__":
    analyzer = SpeechAnalyzer()
    transcription_result = analyzer.transcribe_audio()
    analyzer.process_transcription(transcription_result)
    topics = [
        "technology", "health", "education", "finance", "politics", "environment", "sports", "entertainment",
        "science", "travel", "business", "culture", "history", "law", "religion"
    ]
    analyzer.print_analysis(transcription_result["text"], topics)
