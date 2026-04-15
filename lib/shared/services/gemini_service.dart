import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/services/logging_service.dart';

/// Calls Google Gemini API to generate AI summaries about elderly patient care.
class GeminiService {
  GeminiService._() {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    logger.debug('GeminiService initialized - API key loaded: ${key.isNotEmpty ? "✅ (${key.length} chars)" : "❌ EMPTY"}');
  }
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

  /// Send a chat message as an elderly companion.
  /// [history] is a list of {role: 'user'|'model', text: '...'} maps.
  /// Returns Gemini's reply text.
  /// Implements exponential backoff retry for rate limits (429 errors).
  Future<String> sendChatMessage({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not configured in .env');
    }

    return _sendWithRetry(
      () => _sendChatMessageImpl(message: message, history: history),
      maxRetries: 3,
    );
  }

  /// Implementation of chat message sending (without retry logic).
  Future<String> _sendChatMessageImpl({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    if (_apiKey.isEmpty) {
      logger.error('Gemini API Key is empty!', null);
      throw Exception('GEMINI_API_KEY not configured in .env');
    }

    // Build conversation turns from history
    final contents = <Map<String, dynamic>>[];
    for (final turn in history) {
      contents.add({
        'role': turn['role'],
        'parts': [{'text': turn['text']}],
      });
    }
    // Append the new user message
    contents.add({
      'role': 'user',
      'parts': [{'text': message}],
    });

    logger.debug('Making Gemini API call to: $_baseUrl');
    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {
              'text':
                  'You are CareSync, a warm, patient, and friendly AI companion for elderly users. '
                  'Keep responses concise (2-3 sentences max), use simple language, '
                  'and be encouraging. Gently remind users about health habits when relevant. '
                  'Never give medical diagnoses. If the user seems distressed, suggest contacting their caregiver.',
            }
          ]
        },
        'contents': contents,
        'generationConfig': {
          'temperature': 0.75,
          'maxOutputTokens': 200,
          'topP': 0.9,
        },
      }),
    );

    logger.debug('Gemini API response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['candidates'][0]['content']['parts'][0]['text'] as String)
          .trim();
    } else {
      logger.error('Gemini API error response: ${response.body}', null);
      throw _ApiException(
        statusCode: response.statusCode,
        message: 'Gemini API error: ${response.statusCode}',
      );
    }
  }

  /// Generic retry wrapper with exponential backoff for rate limits (429).
  Future<T> _sendWithRetry<T>(
    Future<T> Function() request, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await request();
      } on _ApiException catch (e) {
        // Only retry on 429 (rate limit)
        if (e.statusCode != 429) {
          throw Exception('Failed to send message: ${e.message}');
        }

        if (attempt < maxRetries - 1) {
          // Exponential backoff: 1s, 2s, 4s
          final delaySeconds = 1 << attempt; // 2^attempt
          await Future.delayed(Duration(seconds: delaySeconds));
        } else {
          // All retries exhausted
          throw Exception('Gemini API rate limited. Please try again in a minute.');
        }
      } catch (e) {
        throw Exception('Failed to send message: $e');
      }
    }
    throw Exception('Unknown error in retry logic');
  }

  /// Generate a detailed weekly health narrative for a caregiver report.
  /// Accepts pre-formatted event strings containing stats and trends.
  Future<String> generateWeeklyNarrative({
    required String patientName,
    required List<String> events,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not configured in .env');
    }

    final eventsList = events.join('\n• ');
    final prompt =
        'You are a caring health assistant. Write a 2-3 sentence weekly summary for a caregiver '
        'about their elderly patient. Be warm and professional. Highlight key trends and any concerns. '
        'Use the actual numbers provided — do not invent data.\n\n'
        'Patient weekly data:\n• $eventsList\n\nWeekly summary:';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.65,
            'maxOutputTokens': 200,
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
      throw Exception('Failed to generate weekly narrative: $e');
    }
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

/// Custom exception for API errors to distinguish from other exceptions.
class _ApiException implements Exception {
  final int statusCode;
  final String message;
  _ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
