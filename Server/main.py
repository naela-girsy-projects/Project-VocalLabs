from fastapi import FastAPI, HTTPException, Depends, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel  # Add this import
import os
from models.transcript import transcribe_audio, process_transcription
from models.filler_word_detection import analyze_filler_words, analyze_mid_sentence_pauses
from models.proficiency_evaluation import calculate_proficiency_score
from models.voice_modulation import analyze_voice_modulation
from models.speech_development import evaluate_speech_development  # Add this line
from models.user import User, SessionLocal, engine
from sqlalchemy.orm import Session
from passlib.context import CryptContext
import whisper
import logging
from nltk_download import download_nltk_resources  # Import the utility function
from models.speech_effectiveness import evaluate_speech_effectiveness  # Add this import
from models.vocabulary_evaluation import evaluate_speech  # Add this import

app = FastAPI()

# Download NLTK resources at server startup
try:
    download_nltk_resources()
except Exception as e:
    logging.error(f"Error downloading NLTK resources: {str(e)}")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Load your transcription model here
model = whisper.load_model("base")

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Dependency to get DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Pydantic models
class UserCreate(BaseModel):
    name: str
    email: str
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

# Create user endpoint
@app.post("/register/")
async def register_user(user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    hashed_password = pwd_context.hash(user.password)
    db_user = User(name=user.name, email=user.email, hashed_password=hashed_password)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

# Login user endpoint
@app.post("/login/")
async def login_user(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if not db_user or not pwd_context.verify(user.password, db_user.hashed_password):
        raise HTTPException(status_code=400, detail="Invalid credentials")
    return {"message": "Login successful", "name": db_user.name}

def generate_timing_feedback(actual_duration_str, expected_duration, speech_type):
    """Generate feedback about timing compliance based on actual vs expected duration"""
    try:
        # Convert actual duration string (MM:SS) to seconds
        parts = actual_duration_str.split(':')
        actual_duration = int(parts[0]) * 60 + int(parts[1])
        
        # Parse expected duration
        expected_duration = expected_duration.lower().replace('–', '-')
        if '-' in expected_duration:
            # Range format like "5-7 minutes"
            parts = expected_duration.split('-')
            min_minutes = float(parts[0].strip())
            max_minutes_part = parts[1].strip()
            max_minutes = float(max_minutes_part.split(' ')[0])
        else:
            # Single value like "5 minutes"
            min_minutes = max_minutes = float(expected_duration.split(' ')[0])
            
        # Convert to seconds
        min_seconds = min_minutes * 60
        max_seconds = max_minutes * 60
        
        # Calculate compliance
        actual_minutes = actual_duration / 60
        
        if actual_duration < min_seconds * 0.9:  # More than 10% shorter
            compliance = "too_short"
            message = f"Your {speech_type.lower()} was too short. Aim for {expected_duration} as required."
        elif actual_duration > max_seconds * 1.1:  # More than 10% longer
            compliance = "too_long"
            message = f"Your {speech_type.lower()} exceeded the expected duration of {expected_duration}."
        else:
            compliance = "within_range"
            message = f"Great job keeping your {speech_type.lower()} within the expected duration of {expected_duration}."
        
        # Calculate percentage compliance
        target_duration = (min_seconds + max_seconds) / 2
        percentage_diff = abs(actual_duration - target_duration) / target_duration * 100
        
        return {
            "status": compliance,
            "feedback": message,
            "actual_minutes": round(actual_minutes, 1),
            "expected_range": {
                "min_minutes": min_minutes,
                "max_minutes": max_minutes
            },
            "percentage_difference": round(percentage_diff, 1),
            "within_expected_range": compliance == "within_range"
        }
    except Exception as e:
        logging.warning(f"Error generating timing feedback: {e}")
        return {
            "status": "unknown",
            "feedback": "Unable to analyze timing compliance.",
            "actual_minutes": 0,
            "expected_range": {"min_minutes": 0, "max_minutes": 0},
            "percentage_difference": 0,
            "within_expected_range": False
        }

@app.post("/upload/")
async def upload_file(file: UploadFile = File(...), 
                      topic: str = Form(None),  # Topic received here
                      speech_type: str = Form(None), 
                      expected_duration: str = Form(None), 
                      actual_duration: str = Form(None)):
    file_location = os.path.join(UPLOAD_DIR, file.filename)
    with open(file_location, "wb") as f:
        f.write(await file.read())
    logging.info(f"Received file: {file.filename}")
    logging.info(f"Speech details - Topic: {topic}, Type: {speech_type}, Expected duration: {expected_duration}, Actual duration: {actual_duration}")

    # Transcribe the audio file
    result = transcribe_audio(model, file_location)
    transcription, pause_duration = process_transcription(result)
    filler_analysis = analyze_filler_words(result)
    pause_analysis = analyze_mid_sentence_pauses(transcription)
    
    # Convert actual_duration string (MM:SS) to seconds
    actual_duration_seconds = 0
    try:
        parts = actual_duration.split(':')
        actual_duration_seconds = int(parts[0]) * 60 + int(parts[1])
    except (ValueError, IndexError, AttributeError):
        logging.warning("Could not parse actual_duration, using 0 seconds")
    
    # Pass speech details to proficiency evaluation
    proficiency_scores = calculate_proficiency_score(
        filler_analysis, 
        pause_analysis,
        actual_duration,
        expected_duration
    )
    
    # Analyze voice modulation
    modulation_analysis = analyze_voice_modulation(file_location)
    
    # New: Analyze speech development
    speech_development = evaluate_speech_development(
        transcription,
        actual_duration_seconds,
        expected_duration
    )
    
    # Add speech effectiveness evaluation with proper error handling
    try:
        speech_effectiveness = evaluate_speech_effectiveness(
            transcription, 
            topic or "General Speech",  # Provide default topic if none
            expected_duration or "5-7 minutes",
            actual_duration_seconds
        )
        
        # Ensure scores are valid numbers and within correct ranges
        total_score = max(8.0, min(20.0, float(speech_effectiveness.get('total_score', 8.0))))
        relevance_score = max(4.0, min(10.0, float(speech_effectiveness.get('relevance_score', 4.0))))
        purpose_score = max(4.0, min(10.0, float(speech_effectiveness.get('purpose_score', 4.0))))
        
        speech_effectiveness.update({
            'total_score': total_score,
            'relevance_score': relevance_score,
            'purpose_score': purpose_score
        })
        
        logging.info("\nSpeech Effectiveness Analysis:")
        logging.info(f"Total Score: {total_score}/20")
        logging.info(f"Relevance Score: {relevance_score}/10")
        logging.info(f"Purpose Score: {purpose_score}/10")
        
    except Exception as e:
        logging.error(f"Error in speech effectiveness evaluation: {str(e)}")
        speech_effectiveness = {
            "total_score": 12.0,  # Higher default scores
            "relevance_score": 6.0,
            "purpose_score": 6.0,
            "details": {},
            "feedback": ["Error analyzing speech effectiveness"]
        }
    
    # Add vocabulary evaluation
    try:
        vocabulary_evaluation = evaluate_speech(result, transcription, file_location, "general")
    except Exception as e:
        logging.error(f"Error in vocabulary evaluation: {str(e)}")
        vocabulary_evaluation = {
            "vocabulary_score": 80.0,  # Default score
            "grammar_word_selection": {"score": 80.0},
            "pronunciation": {"score": 80.0}
        }
    
    # Get vocabulary evaluation
    vocabulary_evaluation = evaluate_speech(result, transcription, file_location, "general")
    
    # Debug log the raw scores with more detail
    print("\nVocabulary Evaluation Scores:")
    print(f"Total Score (0-20): {vocabulary_evaluation['vocabulary_score']}")
    print(f"Grammar Score (0-20): {vocabulary_evaluation['grammar_word_selection']['score']}")
    print(f"Grammar Details: {vocabulary_evaluation['grammar_word_selection']['details']}")
    print(f"Pronunciation Score (0-20): {vocabulary_evaluation['pronunciation']['score']}")
    
    # Generate timing feedback
    timing_feedback = generate_timing_feedback(actual_duration, expected_duration, speech_type)

    # Generate speech type feedback
    speech_type_feedback = ""
    if speech_type == "Prepared Speech":
        speech_type_feedback = "Prepared speeches should be well-structured with clear introduction, body, and conclusion."
    elif speech_type == "Impromptu Speech":
        speech_type_feedback = "Impromptu speeches show your ability to think quickly and organize thoughts on the spot."
    elif speech_type == "Table Topics":
        speech_type_feedback = "Table Topics are meant to be short and concise responses to unexpected questions."
    else:
        speech_type_feedback = "Focus on clarity, structure, and engaging delivery in your speech."

    # Return response with all evaluations
    return {
        "filename": file.filename,
        "transcription": transcription,
        "pause_duration": pause_duration,
        "pause_analysis": pause_analysis,
        "filler_word_analysis": filler_analysis,
        "proficiency_scores": proficiency_scores,  # This now contains the complete proficiency data
        "speech_effectiveness": {
            "total_score": speech_effectiveness['total_score'],
            "relevance_score": speech_effectiveness['relevance_score'],
            "purpose_score": speech_effectiveness['purpose_score'],
            "details": speech_effectiveness['details'],
            "feedback": speech_effectiveness.get('feedback', [])
        },
        "modulation_analysis": modulation_analysis,
        "speech_development": speech_development,  # Add this line
        "vocabulary_evaluation": vocabulary_evaluation,
        "speech_details": {
            "topic": topic,
            "speech_type": speech_type,
            "expected_duration": expected_duration,
            "actual_duration": actual_duration
        },
        "enhanced_analysis": {
            "timing_compliance": timing_feedback,
            "speech_type_feedback": speech_type_feedback,
            "topic_relevance": {
                "score": speech_effectiveness.get('relevance_score', 7) * 10,  # Scale to 0-100
                "feedback": f"Your speech on '{topic}' was analyzed for content and delivery quality."
            },
            "recommendations": [
                f"Practice keeping your {speech_type.lower()} within the {expected_duration} timeframe.",
                "Focus on reducing filler words to sound more confident.",
                "Use pauses strategically rather than mid-sentence."
            ] + (speech_development.get("structure", {}).get("feedback", []) if speech_development else [])
        }
    }

if __name__ == "__main__":
    import uvicorn
    logging.basicConfig(level=logging.INFO)
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)