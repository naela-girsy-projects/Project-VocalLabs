# filepath: f:\SDGP_GIT_CONNECT\SDGP_GIT_CONNECT\Project-VocalLabs\Server\firebase_config.py
import firebase_admin
from firebase_admin import credentials, firestore

# Path to your Firebase service account key JSON file
cred = credentials.Certificate(r"F:\SDGP_GIT_CONNECT\SDGP_GIT_CONNECT\Project-VocalLabs\Server\vocallabs-fc7d5-firebase-adminsdk-fbsvc-c9dfb67bfb.json")  # Replace with the actual path
firebase_admin.initialize_app(cred)

# Firestore database instance
db = firestore.client()