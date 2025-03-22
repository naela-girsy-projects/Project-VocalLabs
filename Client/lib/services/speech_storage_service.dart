import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vocallabs_flutter_app/models/speech_model.dart';

class SpeechStorageService {
  static const String _storageKey = 'speech_history';
  
  // Save a speech to history
  static Future<bool> saveSpeech(SpeechModel speech) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Retrieve existing speeches
      final List<SpeechModel> speeches = await getSpeechesFromLocalStorage();
      
      // Add new speech
      speeches.add(speech);
      
      // Convert to JSON string and store
      final speechesJson = speeches.map((s) => s.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(speechesJson));
      
      return true;
    } catch (e) {
      print('Error saving speech: $e');
      return false;
    }
  }
  
  // Get all saved speeches from local storage
  static Future<List<SpeechModel>> getSpeechesFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final speechesString = prefs.getString(_storageKey);
      
      if (speechesString == null) {
        return [];
      }
      
      final speechesJson = jsonDecode(speechesString) as List;
      return speechesJson.map((json) => 
        SpeechModel.fromMap(json as Map<String, dynamic>)
      ).toList();
    } catch (e) {
      print('Error retrieving speeches: $e');
      return [];
    }
  }

  // Get all saved speeches from Firestore
  static Future<List<SpeechModel>> getSpeeches() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final speechesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('speeches');

    final querySnapshot = await speechesRef.orderBy('recorded_at', descending: true).get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      return SpeechModel(
        topic: data['topic'] ?? '',
        speechType: data['speech_type'] ?? '',
        expectedDuration: data['expected_duration'] ?? '',
        duration: double.tryParse(data['actual_duration'] ?? '0') ?? 0,
        score: data['proficiency_scores']?['final_score'] ?? 0,
        recordedAt: (data['recorded_at'] as Timestamp).toDate(),
      );
    }).toList();
  }
}
