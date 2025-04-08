# filepath: f:\SDGP_GIT_CONNECT\SDGP_GIT_CONNECT\Project-VocalLabs\Server\firebase_config.py
import os
from firebase_admin import credentials, firestore, storage
import firebase_admin

# Load environment variables directly (no .env file in Railway)
private_key = os.getenv("FIREBASE_PRIVATE_KEY")
private_key_id = os.getenv("FIREBASE_PRIVATE_KEY_ID")

if not private_key or not private_key_id:
    raise RuntimeError("FIREBASE_PRIVATE_KEY or FIREBASE_PRIVATE_KEY_ID is not set in the environment variables")

# Replace escaped newlines with actual newlines in the private key
private_key = private_key.replace("\\n", "\n")

# Firebase service account key configuration
service_account_key = {
    "type": "service_account",
    "project_id": "vocallabs-fc7d5",
    "private_key_id": private_key_id,
    "private_key": private_key,
    "client_email": "firebase-adminsdk-fbsvc@vocallabs-fc7d5.iam.gserviceaccount.com",
    "client_id": "113550497977436500236",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40vocallabs-fc7d5.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com"
}

cred = credentials.Certificate(service_account_key)

# Initialize Firebase Admin SDK
firebase_admin.initialize_app(cred, {
    'storageBucket': 'vocallabs-fc7d5.firebasestorage.app'
})

# Firestore database instance
db = firestore.client()