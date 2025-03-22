from fastapi import FastAPI, HTTPException, Depends, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
from models.transcript import transcribe_audio, process_transcription
from models.filler_word_detection import analyze_filler_words, analyze_mid_sentence_pauses
from models.proficiency_evaluation import calculate_proficiency_score
from models.voice_modulation import analyze_voice_modulation
from models.speech_development import evaluate_speech_development
from passlib.context import CryptContext
import whisper
import logging
from nltk_download import download_nltk_resources
from firebase_config import db
from firebase_admin import firestore
import json
from fastapi.encoders import jsonable_encoder

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
model = whisper.load_model("medium")

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

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
async def register_user(user: UserCreate):
    users_ref = db.collection("users")
    existing_user = users_ref.where("email", "==", user.email).get()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    new_user = {
        "name": user.name,
        "email": user.email,
        "createdAt": firestore.SERVER_TIMESTAMP,
    }
    users_ref.add(new_user)

    return {"message": "User registered successfully"}

# Login user endpoint
@app.post("/login/")
async def login_user(user: UserLogin):
    users_ref = db.collection("users")
    user_docs = users_ref.where("email", "==", user.email).get()
    if not user_docs:
        raise HTTPException(status_code=400, detail="Invalid credentials")

    user_data = user_docs[0].to_dict()
    return {"message": "Login successful", "name": user_data["name"]}

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
                      topic: str = Form(None), 
                      speech_type: str = Form(None), 
                      expected_duration: str = Form(None), 
                      actual_duration: str = Form(None), 
                      user_id: str = Form(...)):
    logging.info(f"Received file: {file.filename}")
    logging.info(f"Topic: {topic}, Speech Type: {speech_type}, Expected Duration: {expected_duration}, Actual Duration: {actual_duration}, User ID: {user_id}")
    
    if not topic or not speech_type or not expected_duration or not actual_duration or not user_id:
        raise HTTPException(status_code=422, detail="Missing required fields")
    
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
        topic,
        actual_duration_seconds,
        expected_duration
    )
    
    # Log transcription and evaluation information
    logging.info(f"Transcription: {transcription}")
    logging.info(f"Total pause duration: {pause_duration} seconds")
    logging.info("\nPause Analysis (Mid-sentence):")
    for category, count in pause_analysis.items():
        logging.info(f"{category}: {count}")
    logging.info("\nFiller Word Analysis:")
    for key, value in filler_analysis.items():
        logging.info(f"{key}: {value}")
    logging.info("\nProficiency Evaluation:")
    logging.info(f"Final Score: {proficiency_scores['final_score']}/20")
    logging.info(f"Filler Word Score: {proficiency_scores['filler_score']}/10")
    logging.info(f"Pause Score: {proficiency_scores['pause_score']}/10")
    
    # Add timing score to logs
    logging.info(f"Timing Score: {proficiency_scores.get('timing_score', 'N/A')}/10")
    
    # Log voice modulation scores
    logging.info("\nVoice Modulation Analysis:")
    logging.info(f"Total Voice Modulation Score: {modulation_analysis['scores']['total_score']}/20")
    logging.info(f"Pitch and Volume Score: {modulation_analysis['scores']['pitch_and_volume_score']}/10")
    logging.info(f"Emphasis Score: {modulation_analysis['scores']['emphasis_score']}/10")

    # Log speech development scores
    logging.info("\nSpeech Development Analysis:")
    logging.info(f"Overall Development Score: {speech_development['development_score']}/100")
    logging.info(f"Structure Score: {speech_development['structure']['score']}/100")
    logging.info(f"Time Utilization Score: {speech_development['time_utilization']['score']}/100")
    if 'time_distribution' in speech_development['time_utilization']['details']:
        time_dist = speech_development['time_utilization']['details']['time_distribution']
        logging.info(f"Time Distribution Quality: {time_dist['quality']}")
        if 'breakdown' in time_dist and time_dist['breakdown']:
            logging.info("Time Distribution Breakdown:")
            breakdown = time_dist['breakdown']
            logging.info(f"  Introduction: {breakdown.get('introduction_percentage', 0)}% ({breakdown.get('introduction_seconds', 0)} sec)")
            logging.info(f"  Body: {breakdown.get('body_percentage', 0)}% ({breakdown.get('body_seconds', 0)} sec)")
            logging.info(f"  Conclusion: {breakdown.get('conclusion_percentage', 0)}% ({breakdown.get('conclusion_seconds', 0)} sec)")

    # Generate timing feedback
    timing_feedback = generate_timing_feedback(actual_duration, expected_duration, speech_type)
    
    # Get speech type specific feedback
    speech_type_feedback = ""
    if (speech_type == "Prepared Speech"):
        speech_type_feedback = "Prepared speeches should be well-structured with clear introduction, body, and conclusion."
    elif (speech_type == "Impromptu Speech"):
        speech_type_feedback = "Impromptu speeches show your ability to think quickly and organize thoughts on the spot."
    elif (speech_type == "Table Topics"):
        speech_type_feedback = "Table Topics are meant to be short and concise responses to unexpected questions."
    else:
        speech_type_feedback = "Focus on clarity, structure, and engaging delivery in your speech."

    # Save speech data in Firestore
    try:
        speech_data = {
            "topic": topic,
            "speech_type": speech_type,
            "expected_duration": expected_duration,
            "actual_duration": actual_duration,
            "transcription": transcription,
            "proficiency_scores": jsonable_encoder(proficiency_scores),
            "modulation_analysis": jsonable_encoder(modulation_analysis),
            "speech_development": jsonable_encoder(speech_development),
            "recorded_at": str(firestore.SERVER_TIMESTAMP),  # Convert to string
        }

        # Save under the user's document in Firestore
        user_ref = db.collection("users").document(user_id)
        speeches_ref = user_ref.collection("speeches")
        speeches_ref.add(speech_data)

        logging.info(f"Speech data saved for user: {user_id}")
    except Exception as e:
        logging.error(f"Error saving speech data: {e}")
        raise HTTPException(status_code=500, detail="Failed to save speech data")

    response = {
        "message": "Speech uploaded and analyzed successfully",
        "speech_data": speech_data,
        "filename": file.filename,
        "transcription": transcription,
        "pause_duration": pause_duration,
        "pause_analysis": pause_analysis,
        "filler_word_analysis": filler_analysis,
        "proficiency_scores": proficiency_scores,
        "modulation_analysis": modulation_analysis,
        "speech_development": speech_development,
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
                "score": proficiency_scores.get('timing_score', 7) * 10,  # Scale to 0-100
                "feedback": f"Your speech on '{topic}' was analyzed for content and delivery quality."
            },
            "recommendations": [
                f"Practice keeping your {speech_type.lower()} within the {expected_duration} timeframe.",
                "Focus on reducing filler words to sound more confident.",
                "Use pauses strategically rather than mid-sentence."
            ] + speech_development.get("structure", {}).get("feedback", [])
        }
    }

    # Log each field to identify the problematic one
    for key, value in response.items():
        try:
            json.dumps({key: value})  # Attempt to serialize each field
        except Exception as e:
            logging.error(f"Serialization error in field '{key}': {e}")

    # Attempt to serialize the entire response
    try:
        json.dumps(response)
    except Exception as e:
        logging.error(f"Serialization error: {e}")
        raise HTTPException(status_code=500, detail="Response serialization failed")

    return response

if __name__ == "__main__":
    import uvicorn
    logging.basicConfig(level=logging.INFO)
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)