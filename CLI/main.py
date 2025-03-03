import whisper
import re
import os
import torch
import nltk
import spacy
from nltk.tokenize import word_tokenize
from collections import Counter

try:
    nltk.download('punkt', quiet=True)
    nltk.download('averaged_perceptron_tagger', quiet=True)
except Exception as e:
    print(f"Error downloading NLTK data: {e}")

try:
    nlp = spacy.load('en_core_web_sm')
except:
    print("Installing spaCy model...")
    os.system("python -m spacy download en_core_web_sm")
    nlp = spacy.load('en_core_web_sm')

class SpeechAnalyzer:

    def _init_(self, model_name="medium", audio_path=r"D:\2 nd sem\VocalLabs\Project-VocalLabs\CLI\didula_audio01.wav"):
        self.model = whisper.load_model(model_name)

        self.audio_path = audio_path
        self.transcription_with_pauses = []
        self.number_of_pauses = 0
        self.device = 0 if torch.cuda.is_available() else -1
        print("SpeechAnalyzer initialized.")

    def transcribe_audio(self):
        print("Transcribing audio...")  # Debug statement
        result = self.model.transcribe(
            self.audio_path,
            fp16=False,
            word_timestamps=True,
            initial_prompt=(
                "Please transcribe exactly as spoken. Include every um, uh, ah, er, pause, repetition, "
                "and false start. Do not clean up or correct the speech. Transcribe with maximum verbatim accuracy."
            )
        )

        return result

    def process_transcription(self, result):
        self.transcription_with_pauses = []
        self.number_of_pauses = 0


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
                        self.number_of_pauses += 1

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

    def get_audio_duration(self):
        try:
            import soundfile as sf
            info = sf.info(self.audio_path)
            return info.duration
        except Exception as e:
            print(f"Error getting audio duration using soundfile: {e}")
            try:
                import wave
                with wave.open(self.audio_path, 'rb') as wf:
                    frames = wf.getnframes()
                    rate = wf.getframerate()
                    duration = frames / float(rate)
                    return duration
            except Exception as e:
                print(f"Error getting audio duration using wave: {e}")
                # As a last resort, get duration from the transcription
                return 60  # Default fallback value

    def neutralize_time_durations(self, transcription_result):
        # Get audio duration from the file directly
        total_time = self.get_audio_duration()

        # If that fails, try to get it from the transcription result
        if total_time <= 0 and isinstance(transcription_result, dict):
            total_time = transcription_result.get('duration', 0)
            if total_time <= 0 and 'segments' in transcription_result and transcription_result['segments']:
                total_time = transcription_result['segments'][-1].get('end', 0)

        # Ensure we have a valid total_time (minimum 1 second)
        total_time = max(total_time, 1.0)

        pauses_pattern = r'\[(\d+\.\d+) second pause\]'
        pause_matches = re.findall(pauses_pattern, self.transcription_with_pauses)

        total_pause_time = sum(float(duration) for duration in pause_matches)

        # Ensure neutralized duration is positive
        neutralized_duration = max(total_time - total_pause_time, 0.1)  # Minimum 0.1 seconds

        words_without_pauses = re.sub(pauses_pattern, '', self.transcription_with_pauses)
        word_count = len([w for w in words_without_pauses.split() if w.strip()])

        # Ensure word count is at least 1 to avoid division by zero
        word_count = max(word_count, 1)

        speaking_rate = word_count / neutralized_duration

        return {
            'original_duration': total_time,
            'pause_time': total_pause_time,
            'neutralized_duration': neutralized_duration,
            'word_count': word_count,
            'speaking_rate': round(speaking_rate, 2)
        }

    def filler_word_detection(self, transcription):
        if isinstance(transcription, dict):
            transcription = transcription.get('text', '')
        filler_count = 0
        filler_words = ["um", "uh", "ah", "ugh", "er", "hmm", "like", "you know", "so", "actually", "basically"]
        for word in filler_words:
            filler_count += len(re.findall(r'\b' + re.escape(word) + r'\b', transcription.lower()))
        return filler_count

    def analyze_speech_effectiveness(self, text):
        if isinstance(text, dict):
            text = text.get('text', '')
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
            if sentences:
                avg_sentence_length = sum(len(word_tokenize(sentence)) for sentence in sentences) / len(sentences)
            else:
                avg_sentence_length = 0

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

    def analyze_speech_structure(self, text):
        if isinstance(text, dict):
            text = text.get('text', '')
        try:
            doc = nlp(text)
            sentences = list(doc.sents)
            num_sentences = len(sentences)
            if num_sentences > 0:
                sentence_lengths = [len(sentence) for sentence in sentences]
                avg_sentence_length = sum(sentence_lengths) / num_sentences
            else:
                avg_sentence_length = 0

            paragraphs = [sent.text for sent in doc.sents if sent.text.strip()]

            transitions = ["however", "moreover", "thus", "therefore", "in addition"]
            transition_count = sum(1 for token in doc if token.text.lower() in transitions)

            introduction_keywords = ["introduction", "begin", "start"]
            conclusion_keywords = ["conclusion", "end", "summary"]
            introduction_present = any(keyword in text.lower() for keyword in introduction_keywords)
            conclusion_present = any(keyword in text.lower() for keyword in conclusion_keywords)

            structure_score = 0
            structure_feedback = []

            if introduction_present:
                structure_score += 30
                structure_feedback.append("Clear introduction detected.")
            else:
                structure_feedback.append("Consider adding a clear introduction.")

            if conclusion_present:
                structure_score += 30
                structure_feedback.append("Clear conclusion detected.")
            else:
                structure_feedback.append("Consider adding a clear conclusion.")

            if transition_count >= 3:
                structure_score += 20
                structure_feedback.append("Effective use of transitions detected.")
            else:
                structure_feedback.append("Consider adding more transitions for coherence.")

            return {
                'structure_score': structure_score,
                'avg_sentence_length': round(avg_sentence_length, 2),
                'num_paragraphs': len(paragraphs),
                'feedback': structure_feedback
            }

        except Exception as e:
            print(f"Error in speech structure analysis: {e}")
            return None

    def analyze_grammar_and_word_selection(self, text):
        if isinstance(text, dict):
            text = text.get('text', '')

        try:
            # Clean the text by removing pause indicators
            clean_text = re.sub(r'\[\d+\.\d+ second pause\]', '', text)

            # Process with spaCy
            doc = nlp(clean_text)

            # Grammar analysis
            # Count potential grammar issues
            grammar_issues = 0
            subject_verb_issues = 0
            preposition_issues = 0

            # Extract sentences for analysis
            sentences = list(doc.sents)
            total_sentences = len(sentences)

            for sent in sentences:
                # Check for basic subject-verb agreement
                subjects = [token for token in sent if "subj" in token.dep_]
                verbs = [token for token in sent if token.pos_ == "VERB"]

                # Simple heuristic for subject-verb agreement issues
                if subjects and verbs:
                    for subj in subjects:
                        for verb in verbs:
                            if subj.is_ancestor(verb) and abs(subj.i - verb.i) > 5:
                                subject_verb_issues += 1

                # Check for missing prepositions
                for token in sent:
                    if token.dep_ == "prep" and token.head.pos_ in ["VERB", "NOUN"]:
                        if len([child for child in token.children]) == 0:
                            preposition_issues += 1

            grammar_issues = subject_verb_issues + preposition_issues

            # Word selection analysis
            words = [token.text.lower() for token in doc if token.is_alpha and not token.is_stop]
            total_words = len(words)

            # Calculate lexical diversity (Type-Token Ratio)
            if total_words > 0:
                unique_words = len(set(words))
                lexical_diversity = unique_words / total_words
            else:
                lexical_diversity = 0

            # Check for repetitive word usage
            word_counter = Counter(words)
            repeated_words = [word for word, count in word_counter.items() if count > 3]

            # Advanced vocabulary usage
            advanced_vocab_count = 0
            basic_words = set(["good", "bad", "nice", "thing", "stuff", "big", "small", "very", "really",
                              "like", "said", "went", "got", "put", "took", "made", "did", "get", "know"])

            # Check for advanced vocabulary
            for word in set(words):
                if len(word) > 7 and word not in basic_words:
                    advanced_vocab_count += 1

            # Calculate scores
            grammar_score = 0
            word_selection_score = 0

            # Grammar scoring
            if total_sentences > 0:
                grammar_issue_ratio = grammar_issues / total_sentences
                if grammar_issue_ratio < 0.1:
                    grammar_score = 50
                elif grammar_issue_ratio < 0.2:
                    grammar_score = 40
                elif grammar_issue_ratio < 0.3:
                    grammar_score = 30
                elif grammar_issue_ratio < 0.5:
                    grammar_score = 20
                else:
                    grammar_score = 10

            # Word selection scoring
            if lexical_diversity > 0.7:
                word_selection_score += 20
            elif lexical_diversity > 0.5:
                word_selection_score += 15
            elif lexical_diversity > 0.3:
                word_selection_score += 10
            else:
                word_selection_score += 5

            # Advanced vocabulary bonus
            if total_words > 0:
                advanced_ratio = advanced_vocab_count / total_words
                if advanced_ratio > 0.2:
                    word_selection_score += 20
                elif advanced_ratio > 0.1:
                    word_selection_score += 15
                elif advanced_ratio > 0.05:
                    word_selection_score += 10
                else:
                    word_selection_score += 5

            # Repetition penalty
            if len(repeated_words) > 5:
                word_selection_score = max(0, word_selection_score - 10)
            elif len(repeated_words) > 3:
                word_selection_score = max(0, word_selection_score - 5)

            # Prepare feedback
            feedback = []

            if grammar_score >= 40:
                feedback.append("Grammar is generally correct and well structured.")
            elif grammar_score >= 20:
                feedback.append("Some grammatical issues detected. Pay attention to subject-verb agreement and preposition usage.")
            else:
                feedback.append("Several grammatical errors detected. Consider reviewing basic grammar rules.")

            if lexical_diversity > 0.5:
                feedback.append("Good vocabulary diversity and word choice.")
            else:
                feedback.append("Consider using a wider range of vocabulary to enhance your speech.")

            if len(repeated_words) > 3:
                feedback.append(f"Repetitive use of words detected: {', '.join(repeated_words[:3])}...")

            if advanced_vocab_count > 10:
                feedback.append("Excellent use of advanced vocabulary.")
            elif advanced_vocab_count > 5:
                feedback.append("Good use of complex words. Consider incorporating more advanced vocabulary.")
            else:
                feedback.append("Consider using more sophisticated vocabulary where appropriate.")

            # Calculate combined score
            combined_score = grammar_score + word_selection_score

            return {
                'grammar_score': grammar_score,
                'word_selection_score': word_selection_score,
                'combined_score': combined_score,
                'lexical_diversity': round(lexical_diversity, 2),
                'unique_words': len(set(words)) if words else 0,
                'repeated_words': repeated_words[:5],  # Show only top 5
                'advanced_vocab_count': advanced_vocab_count,
                'grammar_issues': grammar_issues,
                'feedback': feedback
            }

        except Exception as e:
            print(f"Error in grammar and word selection analysis: {e}")
            return None
            
    def analyze_pronunciation_quality(self, audio_data=None, transcription=None):
        """
        Analyzes the pronunciation quality of speech by comparing audio data with expected pronunciation.
        
        Args:
            audio_data: Audio data or path to evaluate (optional)
            transcription: Transcription data or expected text (optional)
            
        Returns:
            Dictionary containing pronunciation quality metrics or None if not implemented
        """
        # Method declaration only - not implemented
        return None

    def print_analysis(self, transcription_result):
        print("\nTranscription with pauses:\n")
        print(self.transcription_with_pauses)
        print("\nNumber of pauses detected:", self.number_of_pauses)
        filler_count = self.filler_word_detection(transcription_result)
        print("\nNumber of filler words detected:", filler_count)

        time_results = self.neutralize_time_durations(transcription_result)
        if time_results:
            print("\n=== Time Duration Analysis ===")
            print(f"Original audio duration: {time_results['original_duration']:.2f} seconds")
            print(f"Total pause time: {time_results['pause_time']:.2f} seconds")
            print(f"Neutralized speaking time: {time_results['neutralized_duration']:.2f} seconds")
            print(f"Word count: {time_results['word_count']} words")
            print(f"Speaking rate: {time_results['speaking_rate']} words per second")

        effectiveness_results = self.analyze_speech_effectiveness(transcription_result)
        if effectiveness_results:
            print("\n=== Speech Effectiveness Analysis ===")
            print(f"Overall effectiveness score: {effectiveness_results['effectiveness_score']}/100")
            print(f"Clear purpose identified: {'Yes' if effectiveness_results['purpose_clarity'] else 'No'}")
            print(f"Conclusion present: {'Yes' if effectiveness_results['has_conclusion'] else 'No'}")
            print(f"Average sentence length: {effectiveness_results['avg_sentence_length']} words")
            print("\nFeedback:")
            for feedback in effectiveness_results['feedback']:
                print(f"- {feedback}")

        structure_results = self.analyze_speech_structure(transcription_result)
        if structure_results:
            print("\n=== Speech Structure Analysis ===")
            print(f"Overall structure score: {structure_results['structure_score']}/100")
            print(f"Average sentence length: {structure_results['avg_sentence_length']} words")
            print(f"Number of paragraphs: {structure_results['num_paragraphs']}")
            print("\nFeedback:")
            for feedback in structure_results['feedback']:
                print(f"- {feedback}")

        grammar_results = self.analyze_grammar_and_word_selection(transcription_result)
        if grammar_results:
            print("\n=== Grammar and Word Selection Analysis ===")
            print(f"Grammar score: {grammar_results['grammar_score']}/50")
            print(f"Word selection score: {grammar_results['word_selection_score']}/50")
            print(f"Combined score: {grammar_results['combined_score']}/100")
            print(f"Lexical diversity: {grammar_results['lexical_diversity']}")
            print(f"Unique words used: {grammar_results['unique_words']}")
            print(f"Advanced vocabulary count: {grammar_results['advanced_vocab_count']}")
            if grammar_results['repeated_words']:
                print(f"Frequently repeated words: {', '.join(grammar_results['repeated_words'])}")
            print("\nFeedback:")
            for feedback in grammar_results['feedback']:
                print(f"- {feedback}")



def ensure_packages():
    try:
        import soundfile
    except ImportError:
        print("Installing soundfile package...")
        os.system("pip install soundfile")

    try:
        import wave
    except ImportError:
        print("Installing wave package...")
        os.system("pip install wave")


<<<<<<< HEAD

if __name__ == "__main__":
=======
# Execute the analysis when running the script
if _name_ == "_main_":
>>>>>>> 11caf85a6831059e3ccdb39091490bf1549d2aed
    try:
        ensure_packages()

        # Initialize the analyzer
        print("Initializing speech analyzer...")
        analyzer = SpeechAnalyzer()

        print("Transcribing audio (this may take a while)...")
        result = analyzer.transcribe_audio()

        print("Processing transcription...")
        analyzer.process_transcription(result)

        print("Analyzing speech...")
        analyzer.print_analysis(result)

    except Exception as e:
        import traceback
        print(f"An error occurred during analysis: {e}")
        traceback.print_exc()