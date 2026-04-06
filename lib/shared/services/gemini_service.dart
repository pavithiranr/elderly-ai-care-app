import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Calls Google Gemini API to generate AI summaries about elderly patient care.
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Generate a concise health summary for a caregiver dashboard.
  /// 
  /// Takes a list of recent activities/events and returns a brief, 
  /// AI-generated paragraph summarizing the elderly person's status.
  Future<String> generateHealthSummary(List<String> recentEvents) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not configured in .env');
    }

    final prompt = _buildHealthSummaryPrompt(recentEvents);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': prompt,
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 150,
            'topP': 0.9,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        return text.toString().trim();
      } else {
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate summary: $e');
    }
  }

  /// Build a focused prompt for health summaries.
  String _buildHealthSummaryPrompt(List<String> events) {
    final eventsList = events.join('\n• ');
    return '''Based on these recent events for an elderly person, write a brief 1-2 sentence health summary for a caregiver dashboard. Be concise, warm, and focus on key health indicators.

Recent events:
• $eventsList

Summary:''';
  }

  /// Generate medication reminder text.
  Future<String> generateMedicationReminder(String medicationName, String dosage) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not configured in .env');
    }

    final prompt =
        'Write a brief, friendly medication reminder (1 sentence) for $dosage of $medicationName.';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': prompt,
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.5,
            'maxOutputTokens': 50,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        return text.toString().trim();
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to generate reminder: $e');
    }
  }
}
