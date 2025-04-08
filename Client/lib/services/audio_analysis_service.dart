import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AudioAnalysisService {
  static const String baseUrl = bool.fromEnvironment('dart.vm.product')
      ? 'https://project-vocallabs-production.up.railway.app' // Production backend
      : 'http://10.0.2.2:8000'; // Local development backend

  /// Uploads audio data and returns the analysis results
  static Future<Map<String, dynamic>> analyzeAudio({
    required Uint8List audioData,
    required String fileName,
    required String topic,
    required String speechType,
    required String expectedDuration,
    required String actualDuration,
    required String userId, // Add this parameter
  }) async {
    final uri = Uri.parse('$baseUrl/upload/');

    final request = http.MultipartRequest('POST', uri)
      ..fields['topic'] = topic
      ..fields['speech_type'] = speechType
      ..fields['expected_duration'] = expectedDuration
      ..fields['actual_duration'] = actualDuration
      ..fields['user_id'] = userId
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        audioData,
        filename: fileName,
        contentType: MediaType('audio', 'mp3'),
      ));

    final response = await http.Response.fromStream(await request.send());

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to analyze audio: ${response.statusCode}');
    }
  }
}
