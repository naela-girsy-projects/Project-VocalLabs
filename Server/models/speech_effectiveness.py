from sentence_transformers import SentenceTransformer
import nltk
from nltk.tokenize import sent_tokenize, word_tokenize
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
from sklearn.feature_extraction.text import TfidfVectorizer
import numpy as np
from typing import List, Dict, Tuple
import spacy

# Initialize models
sbert_model = SentenceTransformer('all-MiniLM-L6-v2')
nlp = spacy.load('en_core_web_sm')

def preprocess_text(text: str) -> str:
    """Clean and preprocess text for analysis."""
    # Tokenize and lemmatize
    lemmatizer = WordNetLemmatizer()
    stop_words = set(stopwords.words('english'))
    
    # Basic cleaning
    text = text.lower()
    
    # Tokenize and lemmatize
    words = word_tokenize(text)
    words = [lemmatizer.lemmatize(word) for word in words 
             if word.isalnum() and word not in stop_words]
    
    return ' '.join(words)

def compute_semantic_similarity(speech_text: str, topic: str) -> float:
    """Compute semantic similarity between speech and topic using SBERT."""
    # Encode texts
    speech_embedding = sbert_model.encode(speech_text)
    topic_embedding = sbert_model.encode(topic)
    
    # Calculate cosine similarity
    similarity = np.dot(speech_embedding, topic_embedding) / \
                (np.linalg.norm(speech_embedding) * np.linalg.norm(topic_embedding))
    
    return float(similarity)

def extract_keywords(text: str, n: int = 10) -> List[str]:
    """Extract top n keywords from text using TF-IDF."""
    vectorizer = TfidfVectorizer(max_features=n)
    tfidf_matrix = vectorizer.fit_transform([text])
    
    # Get feature names and scores
    feature_names = vectorizer.get_feature_names_out()
    scores = tfidf_matrix.toarray()[0]
    
    # Sort keywords by score
    keyword_scores = list(zip(feature_names, scores))
    keyword_scores.sort(key=lambda x: x[1], reverse=True)
    
    return [word for word, _ in keyword_scores[:n]]

def analyze_speech_structure(speech_text: str) -> Dict:
    """Analyze the structure and coherence of the speech."""
    sentences = sent_tokenize(speech_text)
    num_sentences = len(sentences)
    
    # More lenient section detection for shorter speeches
    if num_sentences < 3:
        intro_end = 1
        body_end = max(1, num_sentences - 1)
    else:
        intro_end = max(1, int(num_sentences * 0.2))
        body_end = int(num_sentences * 0.8)
    
    intro = ' '.join(sentences[:intro_end])
    body = ' '.join(sentences[intro_end:body_end])
    conclusion = ' '.join(sentences[body_end:])
    
    # Analyze coherence using spaCy
    doc = nlp(speech_text)
    
    # Calculate topic consistency based on main subjects and verbs
    main_subjects = []
    main_verbs = []
    for token in doc:
        if token.dep_ == 'nsubj':
            main_subjects.append(token.text.lower())
        elif token.pos_ == 'VERB':
            main_verbs.append(token.text.lower())
    
    # Calculate topic consistency
    topic_consistency = 0
    if main_subjects and main_verbs:
        unique_subjects = set(main_subjects)
        unique_verbs = set(main_verbs)
        subject_consistency = len([s for s in main_subjects if s in unique_subjects]) / len(main_subjects)
        verb_variety = len(unique_verbs) / len(main_verbs)
        topic_consistency = (subject_consistency + verb_variety) / 2
    
    return {
        'has_intro': bool(intro and len(intro.split()) >= 3),
        'has_body': bool(body and len(body.split()) >= 5),
        'has_conclusion': bool(conclusion and len(conclusion.split()) >= 3),
        'has_discourse_markers': _check_discourse_markers(speech_text),
        'topic_consistency': topic_consistency,
        'num_sentences': num_sentences,
        'sections': {
            'intro': intro,
            'body': body,
            'conclusion': conclusion
        }
    }

def _check_discourse_markers(text: str) -> float:
    """Check for discourse markers and return a score based on their usage."""
    discourse_markers = {
        'introduction': ['first', 'to begin', 'introduction', 'topic', 'discuss'],
        'transition': ['however', 'moreover', 'furthermore', 'additionally', 'therefore', 'consequently'],
        'conclusion': ['finally', 'in conclusion', 'to summarize', 'thus', 'in summary']
    }
    
    text_lower = text.lower()
    total_markers = 0
    for category, markers in discourse_markers.items():
        for marker in markers:
            if marker in text_lower:
                total_markers += 1
    
    # Return a normalized score (0-1)
    return min(1.0, total_markers / 5)  # Expecting at least 5 markers for full score

def evaluate_speech_effectiveness(speech_text: str, topic: str, expected_duration: str = "5-7 minutes", actual_duration_seconds: int = 0) -> Dict:
    """
    Main function to evaluate speech effectiveness based on topic relevance
    and achievement of purpose.
    
    Parameters:
    speech_text (str): The transcribed speech text
    topic (str): The topic of the speech
    expected_duration (str): Expected duration string (e.g., "5–7 minutes")
    actual_duration_seconds (int): Actual speech duration in seconds
    """
    # Input validation and logging
    if not speech_text or not topic:
        print("Warning: Empty speech text or topic")
        return {
            "total_score": 0,
            "relevance_score": 0,
            "purpose_score": 0,
            "details": {},
            "feedback": ["Invalid input: Speech or topic is empty"]
        }
    
    print(f"\nAnalyzing speech effectiveness:")
    print(f"Topic: {topic}")
    print(f"Expected Duration: {expected_duration}")
    print(f"Speech length: {len(speech_text)} characters")

    # Preprocess texts
    processed_speech = preprocess_text(speech_text)
    processed_topic = preprocess_text(topic)
    
    # 1. Clear Purpose & Relevance (10 points)
    semantic_similarity = compute_semantic_similarity(processed_speech, processed_topic)
    print(f"Semantic similarity score: {semantic_similarity}")
    
    speech_keywords = set(extract_keywords(processed_speech))
    topic_keywords = set(extract_keywords(processed_topic))
    keyword_overlap = len(speech_keywords.intersection(topic_keywords)) / max(len(topic_keywords), 1)
    print(f"Keyword overlap score: {keyword_overlap}")
    
    # Calculate relevance score with more granular scaling
    # Semantic similarity (0-1) contributes 60% of score
    # Keyword overlap (0-1) contributes 40% of score
    raw_score = (semantic_similarity * 0.6) + (keyword_overlap * 0.4)
    
    # Improved relevance score scaling (0-10)
    if raw_score < 0.2:  # Very poor relevance
        relevance_score = raw_score * 25  # Scales 0-0.2 to 0-5
    elif raw_score < 0.4:  # Basic relevance (5-6.5 range)
        relevance_score = 5 + ((raw_score - 0.2) / 0.2) * 1.5
    elif raw_score < 0.6:  # Good relevance (6.5-8 range)
        relevance_score = 6.5 + ((raw_score - 0.4) / 0.2) * 1.5
    elif raw_score < 0.8:  # Very good relevance (8-9 range)
        relevance_score = 8 + ((raw_score - 0.6) / 0.2)
    else:  # Excellent relevance (9-10 range)
        relevance_score = 9 + ((raw_score - 0.8) / 0.2)

    # Ensure score is within bounds
    relevance_score = max(0, min(10, relevance_score))
    
    # 2. Achievement of Purpose (10 points)
    structure_analysis = analyze_speech_structure(speech_text)
    
    # Enhanced purpose evaluation (10 points)
    purpose_components = {
        'structure': 0,
        'coherence': 0,
        'topic_alignment': 0,
        'conclusion_strength': 0
    }

    # Structure analysis (4 points)
    if structure_analysis['has_intro']:
        intro_sentences = speech_text.split('.')[:2]
        purpose_components['structure'] += (
            2.0 if any(s.lower().strip().startswith(('what', 'why', 'how', 'learning', 'think')) 
            for s in intro_sentences) else 1.5  # Increased points
        )

    # Enhanced body evaluation (3 points)
    body_sentences = speech_text.split('.')[1:-2]
    if len(body_sentences) >= 3:
        # Check for argument development
        argument_markers = ['because', 'therefore', 'however', 'for example', 'consider']
        theme_development = ['not just', 'beyond', 'understand', 'teaches us']
        
        argument_strength = sum(
            any(marker in sentence.lower() for marker in argument_markers)
            for sentence in body_sentences
        ) / len(body_sentences)
        
        theme_strength = sum(
            any(marker in sentence.lower() for marker in theme_development)
            for sentence in body_sentences
        ) / len(body_sentences)
        
        purpose_components['structure'] += min(3.0, (argument_strength + theme_strength) * 2)

    # Enhanced conclusion evaluation (3 points)
    conclusion_sentences = speech_text.split('.')[-2:]
    conclusion_strength = 0
    
    # Topic synthesis (1 point)
    if any(marker in speech_text.lower() for marker in ['purpose', 'most valuable', 'prepare for life']):
        conclusion_strength += 1
    
    # Reflection quality (1 point)
    reflection_markers = ['understand', 'learn', 'grow', 'adapt', 'think critically']
    reflection_score = sum(marker in speech_text.lower() for marker in reflection_markers)
    if reflection_score >= 2:
        conclusion_strength += 1
    
    # Connection to main theme (1 point)
    if any(phrase in speech_text.lower() for phrase in [topic.lower(), 'true purpose', 'valuable skill']):
        conclusion_strength += 1

    purpose_components['conclusion_strength'] = conclusion_strength

    # Calculate final purpose score
    purpose_score = (
        purpose_components['structure'] +               # Up to 4 points
        conclusion_strength +                          # Up to 3 points
        (structure_analysis['topic_consistency'] * 3)  # Up to 3 points
    )
    
    # Bonus for exceptional thematic development
    if semantic_similarity > 0.7 and conclusion_strength >= 2:
        purpose_score = min(10, purpose_score + 1)

    # Calculate total score properly
    total_score = relevance_score + purpose_score  # Direct sum of both scores

    return {
        'total_score': round(total_score, 1),
        'relevance_score': round(relevance_score, 1),
        'purpose_score': round(purpose_score, 1),
        'details': {
            'semantic_similarity': round(semantic_similarity, 3),
            'keyword_overlap': round(keyword_overlap, 3),
            'speech_keywords': list(speech_keywords),
            'topic_keywords': list(topic_keywords),
            'structure_analysis': structure_analysis,
            'purpose_components': {k: round(v, 2) for k, v in purpose_components.items()}
        },
        'feedback': generate_feedback(relevance_score, purpose_score, structure_analysis)
    }

def generate_feedback(relevance_score: float, purpose_score: float, structure: Dict) -> List[str]:
    """Generate specific feedback based on the analysis results."""
    feedback = []
    
    # Relevance feedback
    if relevance_score < 5:
        feedback.append("The speech appears to deviate significantly from the main topic. Try to stay more focused on the subject matter.")
    elif relevance_score < 7:
        feedback.append("The speech somewhat relates to the topic but could be more focused. Consider tightening the connection to the main theme.")
    else:
        feedback.append("Good job maintaining relevance to the topic throughout the speech.")
    
    # Structure feedback
    if not structure['has_intro']:
        feedback.append("The speech lacks a clear introduction. Consider adding an opening that sets up your main points.")
    if not structure['has_conclusion']:
        feedback.append("The speech needs a stronger conclusion to reinforce your message.")
    if not structure['has_discourse_markers']:
        feedback.append("Try using transition phrases to improve flow between ideas.")
    
    # Purpose achievement feedback
    if purpose_score < 5:
        feedback.append("The speech structure needs significant improvement. Focus on organizing your thoughts more clearly.")
    elif purpose_score < 7:
        feedback.append("The speech structure is decent but could be more organized. Consider using a clearer beginning-middle-end format.")
    else:
        feedback.append("Well-structured speech with good organization of ideas.")
    
    return feedback
